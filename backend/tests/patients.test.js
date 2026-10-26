import test from 'node:test';
import assert from 'node:assert/strict';
import { handler } from '../src/handlers/patients.js';
import {
  failPatientStore,
  getPatient,
  resetPatients,
} from '../src/repositories/sqlite_patient_repository.js';

const body = {
  name: 'Test Patient',
  phone: '0900000000',
  dateOfBirth: '2000-01-01',
  gender: 'Khác',
  address: 'Test address',
  emergencyContactName: 'Emergency',
  emergencyContactPhone: '0911111111',
};

const event = (
  method,
  data = body,
  claims = { sub: 'user-a', 'cognito:groups': 'patients', email: 'test@example.com' },
) => ({
  httpMethod: method,
  body: data === null ? null : JSON.stringify(data),
  requestContext: { authorizer: { claims } },
});

const call = async (...args) => {
  const r = await handler(event(...args));
  return [r.statusCode, JSON.parse(r.body)];
};

const create = async () => call('POST');

test('TC01 POST creates profile', async () => {
  await resetPatients();
  const [s, b] = await create();
  assert.equal(s, 200);
  assert.match(b.patientId, /^BN-/);
  const patient = await getPatient('user-a');
  assert.equal(patient.cognitoUserId, 'user-a');
});

test('TC02 POST conflict does not overwrite', async () => {
  await resetPatients();
  await create();
  const [s] = await create();
  assert.equal(s, 409);
});

test('TC03 POST validates missing name', async () => {
  await resetPatients();
  const [s] = await call('POST', { ...body, name: '' });
  assert.equal(s, 400);
  assert.equal(await getPatient('user-a'), undefined);
});

test('TC04 POST validates date', async () => {
  await resetPatients();
  assert.equal((await call('POST', { ...body, dateOfBirth: 'bad' }))[0], 400);
});

test('TC05 POST ignores forged cognito id', async () => {
  await resetPatients();
  await call('POST', { ...body, cognitoUserId: 'victim' });
  const patient = await getPatient('user-a');
  assert.equal(patient.cognitoUserId, 'user-a');
});

test('TC06 POST handles Dynamo error', async () => {
  await resetPatients();
  failPatientStore();
  assert.equal((await call('POST'))[0], 500);
});

test('TC07 POST rejects unauthenticated', async () => {
  await resetPatients();
  assert.equal((await call('POST', body, {}))[0], 401);
});

test('TC08 PATCH updates name', async () => {
  await resetPatients();
  await create();
  const [s, b] = await call('PATCH', { ...body, name: 'New name' });
  assert.equal(s, 200);
  assert.equal(b.name, 'New name');
});

test('TC09 PATCH updates phone', async () => {
  await resetPatients();
  await create();
  const [, b] = await call('PATCH', { ...body, phone: '0999999999' });
  assert.equal(b.phone, '0999999999');
});

test('TC10 PATCH updates emergency contact', async () => {
  await resetPatients();
  await create();
  const [, b] = await call('PATCH', { ...body, emergencyContactName: 'New contact' });
  assert.equal(b.emergencyContactName, 'New contact');
});

test('TC11 PATCH preserves patientId', async () => {
  await resetPatients();
  const [, p] = await create();
  const [, b] = await call('PATCH', { ...body, patientId: 'BN-HACK' });
  assert.equal(b.patientId, p.patientId);
});

test('TC12 PATCH preserves cognito id', async () => {
  await resetPatients();
  await create();
  const [, b] = await call('PATCH', { ...body, cognitoUserId: 'victim' });
  assert.equal(b.cognitoUserId, 'user-a');
});

test('TC13 PATCH preserves createdAt', async () => {
  await resetPatients();
  const [, p] = await create();
  const [, b] = await call('PATCH', { ...body, createdAt: 'hack' });
  assert.equal(b.createdAt, p.createdAt);
});

test('TC14 PATCH missing profile is 404', async () => {
  await resetPatients();
  assert.equal((await call('PATCH'))[0], 404);
});

test('TC15 PATCH validates data', async () => {
  await resetPatients();
  await create();
  assert.equal((await call('PATCH', { ...body, name: '' }))[0], 400);
});

test('TC16 PATCH handles Dynamo error', async () => {
  await resetPatients();
  await create();
  failPatientStore();
  assert.equal((await call('PATCH'))[0], 500);
});

test('TC17 PATCH rejects unauthenticated', async () => {
  await resetPatients();
  assert.equal((await call('PATCH', body, {}))[0], 401);
});
