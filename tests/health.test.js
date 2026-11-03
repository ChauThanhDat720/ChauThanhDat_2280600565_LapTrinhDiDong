import test from 'node:test';
import assert from 'node:assert/strict';

import { handler } from '../src/handlers/health.js';

test('GET /health returns the public service status', async () => {
  const response = await handler({});
  assert.equal(response.statusCode, 200);
  assert.deepEqual(JSON.parse(response.body), {
    status: 'ok',
    service: 'smart-hospital-api',
  });
});
