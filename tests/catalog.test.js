import test from 'node:test';
import assert from 'node:assert/strict';
import { list as listDepartments } from '../src/handlers/departments.js';
import { handler as doctorsHandler } from '../src/handlers/doctors.js';

test('Departments API: List all departments', async () => {
  const res = await listDepartments({});
  assert.equal(res.statusCode, 200);
  const data = JSON.parse(res.body);
  assert.ok(Array.isArray(data.items));
  assert.ok(data.items.length >= 1);
  assert.ok(data.items.some((d) => d.id === 'cardiology'));
});

test('Doctors API: List all doctors', async () => {
  const res = await doctorsHandler({ pathParameters: {} });
  assert.equal(res.statusCode, 200);
  const data = JSON.parse(res.body);
  assert.ok(Array.isArray(data.items));
  assert.ok(data.items.length >= 1);
  assert.ok(data.items.some((doc) => doc.id === 'dr-linh'));
});

test('Doctors API: Get single doctor by ID', async () => {
  const res = await doctorsHandler({ pathParameters: { id: 'dr-linh' } });
  assert.equal(res.statusCode, 200);
  const doctor = JSON.parse(res.body);
  assert.equal(doctor.id, 'dr-linh');
  assert.ok(doctor.name.includes('Linh'));
});

test('Doctors API: Return 404 for non-existent doctor', async () => {
  const res = await doctorsHandler({ pathParameters: { id: 'dr-non-existent' } });
  assert.equal(res.statusCode, 404);
});
