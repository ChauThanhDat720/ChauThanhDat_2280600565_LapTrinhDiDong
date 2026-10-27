import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, QueryCommand, TransactWriteCommand } from '@aws-sdk/lib-dynamodb';

export class WriteConflict extends Error {}

export class DynamoStore {
  constructor(tableName, client = DynamoDBDocumentClient.from(new DynamoDBClient({}), {
    marshallOptions: { removeUndefinedValues: true },
  })) {
    if (!tableName) throw new Error('HOSPITAL_TABLE is required');
    this.tableName = tableName;
    this.client = client;
  }
  async get(pk, sk) {
    return (await this.client.send(new GetCommand({
      TableName: this.tableName, Key: { pk, sk }, ConsistentRead: true,
    }))).Item ?? null;
  }
  async query(pk, prefix = '', index) {
    const pkField = index ? `${index}pk` : 'pk';
    const skField = index ? `${index}sk` : 'sk';
    const items = [];
    let cursor;
    do {
      const result = await this.client.send(new QueryCommand({
        TableName: this.tableName,
        ...(index ? { IndexName: index } : { ConsistentRead: true }),
        KeyConditionExpression: '#pk = :pk AND begins_with(#sk, :prefix)',
        ExpressionAttributeNames: { '#pk': pkField, '#sk': skField },
        ExpressionAttributeValues: { ':pk': pk, ':prefix': prefix },
        ...(cursor ? { ExclusiveStartKey: cursor } : {}),
      }));
      items.push(...(result.Items ?? []));
      cursor = result.LastEvaluatedKey;
    } while (cursor);
    return items;
  }
  async transact(operations) {
    const TransactItems = operations.map(({ put, remove, expected }) => {
      const conditional = expected == null
        ? { ConditionExpression: 'attribute_not_exists(pk)' }
        : { ConditionExpression: '#version = :version',
            ExpressionAttributeNames: { '#version': 'version' },
            ExpressionAttributeValues: { ':version': expected } };
      return put
        ? { Put: { TableName: this.tableName, Item: put, ...conditional } }
        : { Delete: { TableName: this.tableName, Key: remove, ...conditional } };
    });
    try {
      await this.client.send(new TransactWriteCommand({ TransactItems }));
    } catch (error) {
      if (error.name === 'TransactionCanceledException' &&
          error.CancellationReasons?.some((reason) => reason.Code === 'ConditionalCheckFailed')) {
        throw new WriteConflict('Data changed during this request');
      }
      throw error;
    }
  }
}
