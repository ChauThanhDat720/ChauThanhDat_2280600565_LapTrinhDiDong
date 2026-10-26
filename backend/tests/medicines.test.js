import test from 'node:test';
import assert from 'node:assert/strict';

import { handler } from '../src/handlers/medicines.js';

const eventFor = ({
  method = 'GET',
  path = '/medicines',
  pathParameters = {},
  queryStringParameters = {},
  headers = {},
  body = null,
} = {}) => ({
  httpMethod: method,
  path,
  pathParameters,
  queryStringParameters,
  headers,
  body: body ? JSON.stringify(body) : null,
  requestContext: {
    http: { method },
  },
});

test('Medicines API: List all medicines', async () => {
  const res = await handler(eventFor({ path: '/medicines' }));
  assert.equal(res.statusCode, 200);
  const data = JSON.parse(res.body);
  assert.ok(Array.isArray(data.items));
  assert.ok(data.items.length >= 10);

  const para = data.items.find((m) => m.name === 'Paracetamol');
  assert.ok(para);
  assert.equal(para.category, 'Giảm đau - Hạ sốt');
});

test('Medicines API: Filter by Category', async () => {
  const res = await handler(
    eventFor({
      path: '/medicines',
      queryStringParameters: { category: 'Tim mạch - Huyết áp' },
    }),
  );
  assert.equal(res.statusCode, 200);
  const data = JSON.parse(res.body);
  assert.ok(data.items.length >= 1);
  assert.ok(data.items.every((m) => m.category === 'Tim mạch - Huyết áp'));
});

test('Medicines API: Search by Keyword', async () => {
  // Search by brand name "Panadol"
  const res = await handler(
    eventFor({
      path: '/medicines',
      queryStringParameters: { search: 'Panadol' },
    }),
  );
  assert.equal(res.statusCode, 200);
  const data = JSON.parse(res.body);
  assert.ok(data.items.some((m) => m.name === 'Paracetamol'));

  // Search by active ingredient "Salbutamol"
  const res2 = await handler(
    eventFor({
      path: '/medicines',
      queryStringParameters: { search: 'Salbutamol' },
    }),
  );
  assert.equal(res2.statusCode, 200);
  const data2 = JSON.parse(res2.body);
  assert.ok(data2.items.some((m) => m.name === 'Salbutamol'));
});

test('Medicines API: Get Medicine Details by ID', async () => {
  const res = await handler(
    eventFor({
      path: '/medicines/med-amlodipine',
      pathParameters: { id: 'med-amlodipine' },
    }),
  );
  assert.equal(res.statusCode, 200);
  const data = JSON.parse(res.body);
  assert.equal(data.name, 'Amlodipine');
  assert.ok(data.indications.includes('tăng huyết áp'));
  assert.ok(data.sideEffects.includes('Phù cổ chân'));
});

test('Medicines API: Lookup by Raw Prescription String', async () => {
  // Doctor prescribed "Aspirin 81mg - 1 viên/ngày"
  const res = await handler(
    eventFor({
      path: '/medicines/lookup',
      queryStringParameters: { name: 'Aspirin 81mg' },
    }),
  );
  assert.equal(res.statusCode, 200);
  const data = JSON.parse(res.body);
  assert.equal(data.name, 'Aspirin 81mg');
  assert.equal(data.category, 'Tim mạch - Chống đông máu');

  // Lookup non-existent returns 404
  const res404 = await handler(
    eventFor({
      path: '/medicines/lookup',
      queryStringParameters: { name: 'ThuocKhongTonTaiXYZ123' },
    }),
  );
  assert.equal(res404.statusCode, 404);
});

test('Medicines API: Get distinct categories', async () => {
  const res = await handler(
    eventFor({
      path: '/medicines/categories',
    }),
  );
  assert.equal(res.statusCode, 200);
  const data = JSON.parse(res.body);
  assert.ok(Array.isArray(data.items));
  assert.ok(data.items.includes('Kháng sinh'));
  assert.ok(data.items.includes('Tiểu đường'));
});
