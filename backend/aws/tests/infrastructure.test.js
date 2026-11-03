import test from 'node:test';
import assert from 'node:assert/strict';
import { DynamoStore, WriteConflict } from '../src/store.js';
import { createPostConfirmation } from '../src/post_confirmation.js';
import { Attachments } from '../src/attachments.js';
import { S3Client } from '@aws-sdk/client-s3';

// These tests inspect SDK requests with injected clients. No AWS account is used.
test('DynamoDB writes include expected-version conditions and only conditional conflicts are retried', async () => {
  let input;
  const store = new DynamoStore('test-table', { async send(command) { input = command.input; } });
  await store.transact([{ put: { pk: 'p', sk: 's', version: 1 }, expected: null }]);
  assert.equal(input.TransactItems[0].Put.ConditionExpression, 'attribute_not_exists(pk)');
  await store.transact([{ remove: { pk: 'p', sk: 's' }, expected: 7 }]);
  assert.equal(input.TransactItems[0].Delete.ExpressionAttributeValues[':version'], 7);
  const error = Object.assign(new Error('conflict'), { name: 'TransactionCanceledException', CancellationReasons: [{ Code: 'ConditionalCheckFailed' }] });
  const bad = new DynamoStore('table', { async send() { throw error; } });
  await assert.rejects(() => bad.transact([]), WriteConflict);
});

test('DynamoDB queries consume all pages and indexes do not ask for unsupported strong consistency', async () => {
  const inputs = [];
  const store = new DynamoStore('table', { async send(command) {
    inputs.push(command.input);
    return inputs.length === 1 ? { Items: [{ id: 1 }], LastEvaluatedKey: { pk: 'p', sk: 'last' } } : { Items: [{ id: 2 }] };
  } });
  assert.equal((await store.query('owner', 'SESSION#', 'gsi1')).length, 2);
  assert.equal(inputs[0].IndexName, 'gsi1');
  assert.equal(inputs[0].ConsistentRead, undefined);
  assert.deepEqual(inputs[1].ExclusiveStartKey, { pk: 'p', sk: 'last' });
});

test('signup only grants patients; password reset does not change groups', async () => {
  const calls = [];
  const handler = createPostConfirmation({ async send(command) { calls.push(command.input); } });
  const event = { triggerSource: 'PostConfirmation_ConfirmSignUp', userPoolId: 'pool', userName: 'user', group: 'admins' };
  assert.equal(await handler(event), event);
  assert.equal(calls[0].GroupName, 'patients');
  await handler({ ...event, triggerSource: 'PostConfirmation_ConfirmForgotPassword' });
  assert.equal(calls.length, 1);
});

test('S3 presigned upload signs MIME and size without a checksum for the not-yet-uploaded body', async () => {
  const client = new S3Client({ region: 'ap-southeast-1',
    credentials: { accessKeyId: 'LOCAL_TEST_ONLY', secretAccessKey: 'LOCAL_TEST_ONLY' },
    requestChecksumCalculation: 'WHEN_REQUIRED' });
  const attachments = new Attachments('test-bucket', client);
  const upload = await attachments.upload('consultations/test/user/photo', 'image/png', 1234);
  const url = new URL(upload.uploadUrl);
  assert.ok(url.searchParams.get('X-Amz-SignedHeaders').includes('content-length'));
  assert.ok(url.searchParams.get('X-Amz-SignedHeaders').includes('content-type'));
  assert.equal(url.searchParams.has('x-amz-checksum-crc32'), false);
  assert.equal(url.searchParams.get('X-Amz-Expires'), '300');
});
