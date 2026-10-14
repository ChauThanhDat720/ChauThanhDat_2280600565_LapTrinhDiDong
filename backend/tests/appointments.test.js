import test from 'node:test';
import assert from 'node:assert/strict';

import { handler } from '../src/handlers/appointments.js';
import { resetAppointments } from '../src/repositories/in_memory_appointment_repository.js';

const eventFor = (patientId, method, body, id) => ({
  httpMethod: method,
  pathParameters: id ? { id } : {},
  body: body ? JSON.stringify(body) : null,
  requestContext: { authorizer: { claims: { sub: patientId, 'cognito:groups': 'patients' } } },
});

test('a patient cannot read another patient appointment', async () => {
  resetAppointments();
  const created = await handler(eventFor('patient-a', 'POST', {
    doctorId: 'dr-linh', doctorName: 'BS. Linh', specialty: 'Tim mạch',
    department: 'Tim mạch', scheduledAt: '2026-10-20T09:00:00.000Z',
    time: '09:00', reason: 'Tái khám',
  }));
  const id = JSON.parse(created.body).id;
  const response = await handler(eventFor('patient-b', 'GET', null, id));
  assert.equal(response.statusCode, 404);
});
