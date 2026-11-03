import test from 'node:test';
import assert from 'node:assert/strict';
import { handler } from '../src/handlers/medication_reminders.js';

const mockEvent = ({ method = 'GET', path = '/medication-reminders', body, pathParameters = {}, query = {}, sub = 'patient-test-reminder' }) => ({
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
        email: `${sub}@test.com`,
      },
    },
  },
});

test('Medication Reminders: Create Manual Reminder & Fetch List', async () => {
  const patientId = 'patient-rem-01';

  // 1. Create reminder
  const createRes = await handler(
    mockEvent({
      method: 'POST',
      path: '/medication-reminders',
      body: {
        medicineName: 'Paracetamol 500mg',
        dosage: '1 viên',
        instructions: 'Uống sau bữa ăn sáng và tối',
        timesPerDay: 2,
        reminderTimes: ['08:00', '20:00'],
        daysCount: 3,
      },
      sub: patientId,
    })
  );

  assert.equal(createRes.statusCode, 201);
  const createBody = JSON.parse(createRes.body);
  assert.ok(createBody.reminder);
  assert.equal(createBody.reminder.medicineName, 'Paracetamol 500mg');
  assert.equal(createBody.reminder.timesPerDay, 2);
  assert.deepEqual(createBody.reminder.reminderTimes, ['08:00', '20:00']);

  // 2. Fetch list
  const listRes = await handler(
    mockEvent({
      method: 'GET',
      path: '/medication-reminders',
      query: { patientId },
      sub: patientId,
    })
  );

  assert.equal(listRes.statusCode, 200);
  const listBody = JSON.parse(listRes.body);
  assert.ok(Array.isArray(listBody.reminders));
  assert.ok(listBody.reminders.some((r) => r.medicineName === 'Paracetamol 500mg'));
});

test('Medication Reminders: 1-Click Parse from Prescription Text', async () => {
  const patientId = 'patient-pres-02';
  const prescription = `
    1. Paracetamol 500mg: 1 viên x 2 lần/ngày sau ăn
    2. Amoxicillin 500mg: 1 viên x 3 lần/ngày sáng, trưa, tối
    3. Vitamin C 500mg: 1 viên x 1 lần/ngày vào buổi sáng
  `;

  const res = await handler(
    mockEvent({
      method: 'POST',
      path: '/medication-reminders/from-prescription',
      body: {
        prescription,
        appointmentId: 'APT-TEST-RX',
        daysCount: 5,
      },
      sub: patientId,
    })
  );

  assert.equal(res.statusCode, 201);
  const body = JSON.parse(res.body);
  assert.equal(body.reminders.length, 3);

  const para = body.reminders.find((r) => r.medicineName.includes('Paracetamol'));
  assert.ok(para);
  assert.equal(para.timesPerDay, 2);
  assert.deepEqual(para.reminderTimes, ['08:00', '20:00']);

  const amox = body.reminders.find((r) => r.medicineName.includes('Amoxicillin'));
  assert.ok(amox);
  assert.equal(amox.timesPerDay, 3);
  assert.deepEqual(amox.reminderTimes, ['08:00', '13:00', '20:00']);

  const vitC = body.reminders.find((r) => r.medicineName.includes('Vitamin C'));
  assert.ok(vitC);
  assert.equal(vitC.timesPerDay, 1);
  assert.deepEqual(vitC.reminderTimes, ['08:00']);
});

test('Medication Reminders: Today Doses and Mark Dose as Taken', async () => {
  const patientId = 'patient-today-03';
  const today = new Date().toISOString().slice(0, 10);

  // 1. Create reminder starting today
  await handler(
    mockEvent({
      method: 'POST',
      path: '/medication-reminders',
      body: {
        medicineName: 'Amlodipine 5mg',
        dosage: '1 viên',
        instructions: 'Uống vào buổi sáng',
        timesPerDay: 1,
        reminderTimes: ['08:00'],
        startDate: today,
        daysCount: 3,
      },
      sub: patientId,
    })
  );

  // 2. Get today's doses
  const todayRes = await handler(
    mockEvent({
      method: 'GET',
      path: '/medication-reminders/today',
      query: { patientId, date: today },
      sub: patientId,
    })
  );

  assert.equal(todayRes.statusCode, 200);
  const todayBody = JSON.parse(todayRes.body);
  assert.ok(Array.isArray(todayBody.doses));
  const dose = todayBody.doses.find((d) => d.medicineName === 'Amlodipine 5mg');
  assert.ok(dose);
  assert.equal(dose.status, 'pending');

  // 3. Mark dose as taken
  const takeRes = await handler(
    mockEvent({
      method: 'POST',
      path: `/medication-reminders/doses/${dose.id}`,
      pathParameters: { id: dose.id, action: 'dose' },
      body: { status: 'taken', note: 'Đã uống với 1 cốc nước' },
      sub: patientId,
    })
  );

  assert.equal(takeRes.statusCode, 200);
  const takeBody = JSON.parse(takeRes.body);
  assert.equal(takeBody.dose.status, 'taken');
  assert.ok(takeBody.dose.takenAt);

  // 4. Verify compliance stats updated
  const statsRes = await handler(
    mockEvent({
      method: 'GET',
      path: '/medication-reminders/today',
      query: { patientId, date: today },
      sub: patientId,
    })
  );
  const statsBody = JSON.parse(statsRes.body);
  assert.ok(statsBody.stats.taken >= 1);
  assert.ok(statsBody.stats.complianceRate >= 50);
});

test('Medication Reminders: Toggle Active & Delete Reminder', async () => {
  const patientId = 'patient-del-04';

  const createRes = await handler(
    mockEvent({
      method: 'POST',
      path: '/medication-reminders',
      body: {
        medicineName: 'Gaviscon Dual Action',
        dosage: '1 gói',
        instructions: 'Uống khi ợ nóng',
        timesPerDay: 1,
        reminderTimes: ['21:00'],
        daysCount: 2,
      },
      sub: patientId,
    })
  );
  const reminderId = JSON.parse(createRes.body).reminder.id;

  // 1. Toggle inactive
  const toggleRes = await handler(
    mockEvent({
      method: 'PATCH',
      path: `/medication-reminders/${reminderId}/toggle`,
      pathParameters: { id: reminderId, action: 'toggle' },
      body: { isActive: false },
      sub: patientId,
    })
  );
  assert.equal(toggleRes.statusCode, 200);
  assert.equal(JSON.parse(toggleRes.body).reminder.isActive, false);

  // 2. Delete
  const delRes = await handler(
    mockEvent({
      method: 'DELETE',
      path: `/medication-reminders/${reminderId}`,
      pathParameters: { id: reminderId },
      sub: patientId,
    })
  );
  assert.equal(delRes.statusCode, 200);
  assert.equal(JSON.parse(delRes.body).success, true);
});
