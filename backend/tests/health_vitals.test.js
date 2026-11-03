import test from 'node:test';
import assert from 'node:assert/strict';
import { handler } from '../src/handlers/health_vitals.js';

const mockEvent = ({ method = 'GET', path = '/patients/pat-001/vitals', body, pathParameters = {}, query = {}, sub = 'pat-001' }) => ({
  httpMethod: method,
  path,
  body: body ? JSON.stringify(body) : undefined,
  pathParameters,
  queryStringParameters: query,
  requestContext: {
    http: { method },
    authorizer: {
      claims: {
        sub,
        email: `${sub}@hospital.local`,
      },
    },
  },
});

test('Health Vitals: Record Optimal Blood Pressure and Calculate BMI', async () => {
  const patientId = 'test-patient-vitals-1';

  const res = await handler(
    mockEvent({
      method: 'POST',
      path: `/patients/${patientId}/vitals`,
      pathParameters: { patientId },
      body: {
        systolic: 118,
        diastolic: 78,
        heartRate: 72,
        bloodSugar: 5.4,
        bloodSugarCondition: 'fasting',
        weight: 65,
        height: 170,
        note: 'Đo sau khi ngủ dậy',
      },
      sub: patientId,
    })
  );

  assert.equal(res.statusCode, 201);
  const body = JSON.parse(res.body);
  assert.ok(body.vital);
  assert.equal(body.vital.systolic, 118);
  assert.equal(body.vital.diastolic, 78);
  assert.equal(body.vital.bmi, 22.5); // 65 / (1.7 * 1.7) = 22.491 -> 22.5
  assert.equal(body.vital.healthStatus, 'optimal');
});

test('Health Vitals: Detect Hypertension Stage 1 Risk', async () => {
  const patientId = 'test-patient-vitals-2';

  const res = await handler(
    mockEvent({
      method: 'POST',
      path: `/patients/${patientId}/vitals`,
      pathParameters: { patientId },
      body: {
        systolic: 145,
        diastolic: 92,
        heartRate: 88,
        weight: 75,
        height: 165,
        note: 'Cảm thấy hơi đau đầu nhẹ',
      },
      sub: patientId,
    })
  );

  assert.equal(res.statusCode, 201);
  const body = JSON.parse(res.body);
  assert.equal(body.vital.healthStatus, 'danger');
  assert.ok(body.vital.healthNote.includes('Tăng huyết áp'));
});

test('Health Vitals: Get History and Summary Analytics', async () => {
  const patientId = 'test-patient-vitals-analytics';

  // Seed default history & get summary
  const res = await handler(
    mockEvent({
      method: 'GET',
      path: `/patients/${patientId}/vitals`,
      pathParameters: { patientId },
      sub: patientId,
    })
  );

  assert.equal(res.statusCode, 200);
  const body = JSON.parse(res.body);
  assert.ok(Array.isArray(body.history));
  assert.ok(body.history.length >= 7);

  assert.ok(body.summary);
  assert.ok(body.summary.totalRecords >= 7);
  assert.ok(body.summary.avgSystolic > 0);
  assert.ok(body.summary.avgDiastolic > 0);
  assert.ok(body.summary.latest);
});

test('Health Vitals: Get Latest Vital Record', async () => {
  const patientId = 'test-patient-vitals-latest';

  const res = await handler(
    mockEvent({
      method: 'GET',
      path: `/patients/${patientId}/vitals/latest`,
      pathParameters: { patientId },
      sub: patientId,
    })
  );

  assert.equal(res.statusCode, 200);
  const body = JSON.parse(res.body);
  assert.ok(body.latest);
  assert.ok(body.latest.systolic);
});

test('Health Vitals: Delete Record', async () => {
  const patientId = 'test-patient-vitals-del';

  const createRes = await handler(
    mockEvent({
      method: 'POST',
      path: `/patients/${patientId}/vitals`,
      pathParameters: { patientId },
      body: { systolic: 120, diastolic: 80 },
      sub: patientId,
    })
  );
  const id = JSON.parse(createRes.body).vital.id;

  const delRes = await handler(
    mockEvent({
      method: 'DELETE',
      path: `/vitals/${id}`,
      pathParameters: { id },
      sub: patientId,
    })
  );

  assert.equal(delRes.statusCode, 200);
  assert.equal(JSON.parse(delRes.body).success, true);
});
