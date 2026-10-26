import test from 'node:test';
import assert from 'node:assert/strict';

import { handler } from '../src/handlers/appointments.js';
import { handler as medicalRecordsHandler } from '../src/handlers/medical_records.js';
import { resetForTest as resetAppointments } from '../src/repositories/sqlite_appointment_repository.js';

const eventFor = ({
  patientId,
  doctorId,
  role = 'patients',
  method = 'GET',
  path = '/appointments',
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
    authorizer: patientId || doctorId
      ? {
          claims: {
            sub: patientId || doctorId,
            doctorId: doctorId || (role === 'doctors' ? patientId : undefined),
            'cognito:groups': role,
            email: `${patientId || doctorId}@hospital.local`,
          },
        }
      : undefined,
  },
});

const sampleAppointment = (override = {}) => ({
  doctorId: 'dr-linh',
  doctorName: 'BS. Trần Thảo Linh',
  specialty: 'Tim mạch',
  department: 'Tim mạch',
  scheduledAt: '2026-11-20T09:00:00.000Z',
  time: '09:00',
  reason: 'Tái khám định kỳ',
  ...override,
});

test('Appointment API: Authentication & Authorization', async () => {
  await resetAppointments();

  // TC01: Unauthenticated request is rejected with 401
  const unauth = await handler(eventFor({ method: 'GET' }));
  assert.equal(unauth.statusCode, 401);

  // TC02: Wrong role cannot access patient endpoints
  const wrongRole = await handler(
    eventFor({ doctorId: 'dr-linh', role: 'doctors', method: 'GET' }),
  );
  assert.equal(wrongRole.statusCode, 403);

  // TC03: Create appointment as patient-a
  const createdRes = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'POST',
      body: sampleAppointment(),
    }),
  );
  assert.equal(createdRes.statusCode, 201);
  const created = JSON.parse(createdRes.body);

  // TC04: patient-b cannot read patient-a's appointment (returns 404 for security)
  const readOther = await handler(
    eventFor({
      patientId: 'patient-b',
      method: 'GET',
      pathParameters: { id: created.id },
    }),
  );
  assert.equal(readOther.statusCode, 404);

  // TC05: patient-b cannot cancel patient-a's appointment
  const cancelOther = await handler(
    eventFor({
      patientId: 'patient-b',
      method: 'PATCH',
      path: `/appointments/${created.id}/cancel`,
      pathParameters: { id: created.id, action: 'cancel' },
    }),
  );
  assert.equal(cancelOther.statusCode, 404);
});

test('Appointment API: Availability Calculation', async () => {
  await resetAppointments();

  const targetDate = '2026-11-20';
  // Book slot 09:00
  await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'POST',
      body: sampleAppointment({ scheduledAt: `${targetDate}T09:00:00.000Z`, time: '09:00' }),
    }),
  );

  // Query availability
  const availRes = await handler(
    eventFor({
      method: 'GET',
      path: `/doctors/dr-linh/availability`,
      pathParameters: { doctorId: 'dr-linh' },
      queryStringParameters: { date: targetDate },
    }),
  );
  assert.equal(availRes.statusCode, 200);
  const data = JSON.parse(availRes.body);
  assert.equal(data.doctorId, 'dr-linh');

  const slot0900 = data.slots.find((s) => s.time === '09:00');
  const slot0830 = data.slots.find((s) => s.time === '08:30');
  assert.equal(slot0900.isAvailable, false);
  assert.equal(slot0830.isAvailable, true);
});

test('Appointment API: Conflict Detection (DynamoDB Transaction simulation)', async () => {
  await resetAppointments();

  // Booking 1 succeeds
  const res1 = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'POST',
      body: sampleAppointment({ scheduledAt: '2026-11-20T09:00:00.000Z', time: '09:00' }),
    }),
  );
  assert.equal(res1.statusCode, 201);

  // Booking 2 for same doctor and same slot gets 409 Conflict
  const res2 = await handler(
    eventFor({
      patientId: 'patient-b',
      method: 'POST',
      body: sampleAppointment({ scheduledAt: '2026-11-20T09:00:00.000Z', time: '09:00' }),
    }),
  );
  assert.equal(res2.statusCode, 409);
  const errorData = JSON.parse(res2.body);
  assert.match(errorData.message, /Khung giờ này đã được đặt/);

  // Booking 3 for DIFFERENT doctor at same time succeeds
  const res3 = await handler(
    eventFor({
      patientId: 'patient-b',
      method: 'POST',
      body: sampleAppointment({
        doctorId: 'dr-tuan',
        doctorName: 'BS. Tuấn',
        scheduledAt: '2026-11-20T09:00:00.000Z',
        time: '09:00',
      }),
    }),
  );
  assert.equal(res3.statusCode, 201);
});

test('Appointment API: Idempotency Key', async () => {
  await resetAppointments();

  const idempotencyKey = 'idem-req-999';

  // Request 1
  const res1 = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'POST',
      headers: { 'idempotency-key': idempotencyKey },
      body: sampleAppointment(),
    }),
  );
  assert.equal(res1.statusCode, 201);
  const created1 = JSON.parse(res1.body);

  // Request 2 with same idempotency key returns exact same appointment
  const res2 = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'POST',
      headers: { 'idempotency-key': idempotencyKey },
      body: sampleAppointment(),
    }),
  );
  assert.equal(res2.statusCode, 201);
  const created2 = JSON.parse(res2.body);
  assert.equal(created1.id, created2.id);
});

test('Appointment API: Doctor Workflow & Status Transitions', async () => {
  await resetAppointments();

  // Patient creates appointment
  const res = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'POST',
      body: sampleAppointment(),
    }),
  );
  const apt = JSON.parse(res.body);
  assert.equal(apt.status, 'pending');

  // Doctor views their appointments
  const doctorList = await handler(
    eventFor({
      doctorId: 'dr-linh',
      role: 'doctors',
      method: 'GET',
      path: '/doctors/me/appointments',
    }),
  );
  assert.equal(doctorList.statusCode, 200);
  const items = JSON.parse(doctorList.body).items;
  assert.equal(items.length, 1);
  assert.equal(items[0].id, apt.id);

  // Another doctor cannot view this appointment in doctor list
  const otherDoctorList = await handler(
    eventFor({
      doctorId: 'dr-other',
      role: 'doctors',
      method: 'GET',
      path: '/doctors/me/appointments',
    }),
  );
  assert.equal(JSON.parse(otherDoctorList.body).items.length, 0);

  // Doctor confirms appointment (PENDING -> CONFIRMED)
  const confirmRes = await handler(
    eventFor({
      doctorId: 'dr-linh',
      role: 'doctors',
      method: 'PATCH',
      path: `/appointments/${apt.id}/status`,
      pathParameters: { id: apt.id, action: 'status' },
      body: { status: 'confirmed', note: 'Đã xác nhận tiếp nhận' },
    }),
  );
  assert.equal(confirmRes.statusCode, 200);
  const confirmedApt = JSON.parse(confirmRes.body);
  assert.equal(confirmedApt.status, 'confirmed');

  // Doctor completes appointment (CONFIRMED -> COMPLETED) with diagnosis & prescription
  const completeRes = await handler(
    eventFor({
      doctorId: 'dr-linh',
      role: 'doctors',
      method: 'PATCH',
      path: `/appointments/${apt.id}/status`,
      pathParameters: { id: apt.id, action: 'status' },
      body: {
        status: 'completed',
        note: 'Bệnh nhân hồi phục tốt',
        diagnosis: 'Rối loạn nhịp xoang nhẹ',
        prescription: 'Magnesium B6 - 2 viên/ngày',
      },
    }),
  );
  assert.equal(completeRes.statusCode, 200);
  const completedApt = JSON.parse(completeRes.body);
  assert.equal(completedApt.status, 'completed');
  assert.equal(completedApt.diagnosis, 'Rối loạn nhịp xoang nhẹ');
  assert.equal(completedApt.prescription, 'Magnesium B6 - 2 viên/ngày');

  // Patient rates completed appointment (1-5 stars)
  const rateRes = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'PATCH',
      path: `/appointments/${apt.id}/rating`,
      pathParameters: { id: apt.id, action: 'rating' },
      body: { rating: 5, reviewNote: 'Bác sĩ rất nhiệt tình' },
    }),
  );
  assert.equal(rateRes.statusCode, 200);
  const ratedApt = JSON.parse(rateRes.body);
  assert.equal(ratedApt.rating, 5);
  assert.equal(ratedApt.reviewNote, 'Bác sĩ rất nhiệt tình');
  assert.ok(ratedApt.reviewedAt);

  // Invalid rating (e.g. 6 stars or 0 stars) must return 400
  const invalidRateRes = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'PATCH',
      path: `/appointments/${apt.id}/rating`,
      pathParameters: { id: apt.id, action: 'rating' },
      body: { rating: 6 },
    }),
  );
  assert.equal(invalidRateRes.statusCode, 400);

  // Invalid transition: COMPLETED -> CANCELLED must fail with 400
  const invalidCancel = await handler(
    eventFor({
      doctorId: 'dr-linh',
      role: 'doctors',
      method: 'PATCH',
      path: `/appointments/${apt.id}/status`,
      pathParameters: { id: apt.id, action: 'status' },
      body: { status: 'cancelled' },
    }),
  );
  assert.equal(invalidCancel.statusCode, 400);

  // Patient also cannot cancel a completed appointment
  const patientCancel = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'PATCH',
      path: `/appointments/${apt.id}/cancel`,
      pathParameters: { id: apt.id, action: 'cancel' },
    }),
  );
  assert.equal(patientCancel.statusCode, 400);
});

test('Appointment API: Cancellation frees up slot', async () => {
  await resetAppointments();

  const targetDate = '2026-11-20';
  // Book slot 09:00
  const res = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'POST',
      body: sampleAppointment({ scheduledAt: `${targetDate}T09:00:00.000Z`, time: '09:00' }),
    }),
  );
  const apt = JSON.parse(res.body);

  // Cancel appointment
  const cancelRes = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'PATCH',
      path: `/appointments/${apt.id}/cancel`,
      pathParameters: { id: apt.id, action: 'cancel' },
      body: { reason: 'Có việc đột xuất' },
    }),
  );
  assert.equal(cancelRes.statusCode, 200);
  assert.equal(JSON.parse(cancelRes.body).status, 'cancelled');

  // Slot 09:00 is available again!
  const availRes = await handler(
    eventFor({
      method: 'GET',
      path: `/doctors/dr-linh/availability`,
      pathParameters: { doctorId: 'dr-linh' },
      queryStringParameters: { date: targetDate },
    }),
  );
  const data = JSON.parse(availRes.body);
  const slot0900 = data.slots.find((s) => s.time === '09:00');
  assert.equal(slot0900.isAvailable, true);

  // Now patient-b can book slot 09:00
  const res2 = await handler(
    eventFor({
      patientId: 'patient-b',
      method: 'POST',
      body: sampleAppointment({ scheduledAt: `${targetDate}T09:00:00.000Z`, time: '09:00' }),
    }),
  );
  assert.equal(res2.statusCode, 201);
});

test('Appointment API: Patient can rate completed appointment', async () => {
  await resetAppointments();

  // Create appointment
  const createRes = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'POST',
      body: sampleAppointment(),
    }),
  );
  const apt = JSON.parse(createRes.body);

  // Doctor confirms then completes appointment
  await handler(
    eventFor({
      doctorId: 'dr-linh',
      role: 'doctors',
      method: 'PATCH',
      path: `/appointments/${apt.id}/status`,
      pathParameters: { id: apt.id, action: 'status' },
      body: { status: 'confirmed' },
    }),
  );

  await handler(
    eventFor({
      doctorId: 'dr-linh',
      role: 'doctors',
      method: 'PATCH',
      path: `/appointments/${apt.id}/status`,
      pathParameters: { id: apt.id, action: 'status' },
      body: {
        status: 'completed',
        diagnosis: 'Rối loạn nhịp tim nhẹ',
        prescription: 'Panadol 500mg x 10 viên',
        followUpDate: '2026-11-09T08:30:00.000Z',
      },
    }),
  );

  // Patient books follow-up appointment linked to previous completed appointment
  const followUpBookingRes = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'POST',
      body: {
        ...sampleAppointment(),
        scheduledAt: '2026-11-09T08:30:00.000Z',
        reason: 'Tái khám theo chỉ định của BS. Linh',
        isFollowUp: true,
        parentAppointmentId: apt.id,
      },
    }),
  );
  assert.equal(followUpBookingRes.statusCode, 201);
  const followUpApt = JSON.parse(followUpBookingRes.body);
  assert.equal(followUpApt.isFollowUp, true);
  assert.equal(followUpApt.parentAppointmentId, apt.id);

  // Patient rates 5 stars
  const rateRes = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'PATCH',
      path: `/appointments/${apt.id}/rating`,
      pathParameters: { id: apt.id, action: 'rating' },
      body: { rating: 5, reviewNote: 'Bác sĩ Linh khám rất tận tâm!' },
    }),
  );

  assert.equal(rateRes.statusCode, 200);
  const rated = JSON.parse(rateRes.body);
  assert.equal(rated.rating, 5);
  assert.equal(rated.reviewNote, 'Bác sĩ Linh khám rất tận tâm!');
  assert.ok(rated.reviewedAt);
  assert.equal(rated.followUpDate, '2026-11-09T08:30:00.000Z');
});

test('Appointment API: Medical Record and Digital Signature for Completed Appointment', async () => {
  await resetAppointments();

  // Create appointment
  const createRes = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'POST',
      body: sampleAppointment(),
    }),
  );
  const apt = JSON.parse(createRes.body);

  // Attempting to get medical record before completion should fail with 400
  const earlyRecordRes = await handler(
    eventFor({
      method: 'GET',
      path: `/appointments/${apt.id}/medical-record`,
      pathParameters: { id: apt.id, action: 'medical-record' },
    }),
  );
  assert.equal(earlyRecordRes.statusCode, 400);

  // Doctor confirms appointment first
  await handler(
    eventFor({
      doctorId: 'dr-linh',
      role: 'doctors',
      method: 'PATCH',
      path: `/appointments/${apt.id}/status`,
      pathParameters: { id: apt.id, action: 'status' },
      body: { status: 'confirmed' },
    }),
  );

  // Doctor completes appointment with diagnosis and prescription
  await handler(
    eventFor({
      doctorId: 'dr-linh',
      role: 'doctors',
      method: 'PATCH',
      path: `/appointments/${apt.id}/status`,
      pathParameters: { id: apt.id, action: 'status' },
      body: {
        status: 'completed',
        diagnosis: 'Tăng huyết áp vô căn giai đoạn 1',
        prescription: 'Amlodipine 5mg x 30 viên (uống 1 viên vào buổi sáng)',
      },
    }),
  );

  // Authenticated endpoint: GET /appointments/:id/medical-record
  const recordRes = await handler(
    eventFor({
      method: 'GET',
      path: `/appointments/${apt.id}/medical-record`,
      pathParameters: { id: apt.id, action: 'medical-record' },
    }),
  );
  assert.equal(recordRes.statusCode, 200);
  const record = JSON.parse(recordRes.body);
  assert.equal(record.verified, true);
  assert.equal(record.diagnosis, 'Tăng huyết áp vô căn giai đoạn 1');
  assert.ok(record.digitalSignature);
  assert.equal(record.digitalSignature.length, 64); // SHA-256 hex string

  // Public QR verification endpoint: GET /records/:id (JSON)
  const qrVerifyRes = await medicalRecordsHandler({
    httpMethod: 'GET',
    path: `/records/${apt.id}`,
    pathParameters: { id: apt.id },
  });
  assert.equal(qrVerifyRes.statusCode, 200);
  const qrData = JSON.parse(qrVerifyRes.body);
  assert.equal(qrData.verified, true);
  assert.equal(qrData.doctorName, 'BS. Trần Thảo Linh');

  // Public QR web view endpoint: GET /records/:id/view (HTML)
  const qrHtmlRes = await medicalRecordsHandler({
    httpMethod: 'GET',
    path: `/records/${apt.id}/view`,
    pathParameters: { id: apt.id },
  });
  assert.equal(qrHtmlRes.statusCode, 200);
  assert.ok(qrHtmlRes.body.includes('<!DOCTYPE html>'));
  assert.ok(qrHtmlRes.body.includes('CHỨNG TỪ ĐÃ XÁC THỰC HỢP LỆ'));
  assert.ok(qrHtmlRes.body.includes(record.digitalSignature));

  // Lab and Imaging Results endpoint: GET /records/:id/lab-results
  const labRes = await medicalRecordsHandler({
    httpMethod: 'GET',
    path: `/records/${apt.id}/lab-results`,
    pathParameters: { id: apt.id, action: 'lab-results' },
  });
  assert.equal(labRes.statusCode, 200);
  const labData = JSON.parse(labRes.body);
  assert.ok(labData.metrics.length >= 7);
  assert.ok(labData.imagingList.length >= 3);

  // Exact metrics verification
  const glucose = labData.metrics.find((m) => m.name.includes('Glucose'));
  assert.ok(glucose);
  assert.equal(glucose.value, 7.2);
  assert.equal(glucose.status, 'high');

  const alt = labData.metrics.find((m) => m.name.includes('ALT'));
  assert.ok(alt);
  assert.equal(alt.value, 65.0);
  assert.equal(alt.status, 'high');

  const creat = labData.metrics.find((m) => m.name.includes('Creatinine'));
  assert.ok(creat);
  assert.equal(creat.value, 76.0);
  assert.equal(creat.status, 'normal');

  const wbc = labData.metrics.find((m) => m.name.includes('Bạch cầu'));
  assert.ok(wbc);
  assert.equal(wbc.value, 6.8);
  assert.equal(wbc.status, 'normal');

  const hb = labData.metrics.find((m) => m.name.includes('Hemoglobin'));
  assert.ok(hb);
  assert.equal(hb.value, 105.0);
  assert.equal(hb.status, 'low');
});

test('Appointment API: Reception QR Check-in and Queue Number Assignment', async () => {
  await resetAppointments();

  const targetDate = '2026-11-20';

  // 1. Create 2 appointments for dr-linh
  const res1 = await handler(
    eventFor({
      patientId: 'patient-a',
      method: 'POST',
      body: sampleAppointment({ scheduledAt: `${targetDate}T08:30:00.000Z`, time: '08:30' }),
    }),
  );
  const apt1 = JSON.parse(res1.body);

  const res2 = await handler(
    eventFor({
      patientId: 'patient-b',
      method: 'POST',
      body: sampleAppointment({ scheduledAt: `${targetDate}T09:00:00.000Z`, time: '09:00' }),
    }),
  );
  const apt2 = JSON.parse(res2.body);

  // 2. Cannot check-in when appointment is still pending
  const earlyCheckin = await handler(
    eventFor({
      method: 'POST',
      path: `/appointments/${apt1.id}/checkin`,
      pathParameters: { id: apt1.id, action: 'checkin' },
    }),
  );
  assert.equal(earlyCheckin.statusCode, 400);

  // 3. Doctor confirms both appointments
  await handler(
    eventFor({
      doctorId: 'dr-linh',
      role: 'doctors',
      method: 'PATCH',
      path: `/appointments/${apt1.id}/status`,
      pathParameters: { id: apt1.id, action: 'status' },
      body: { status: 'confirmed' },
    }),
  );
  await handler(
    eventFor({
      doctorId: 'dr-linh',
      role: 'doctors',
      method: 'PATCH',
      path: `/appointments/${apt2.id}/status`,
      pathParameters: { id: apt2.id, action: 'status' },
      body: { status: 'confirmed' },
    }),
  );

  // 4. Patient 1 arrives at reception and checks in -> gets STT 1
  const checkinRes1 = await handler(
    eventFor({
      method: 'POST',
      path: `/appointments/${apt1.id}/checkin`,
      pathParameters: { id: apt1.id, action: 'checkin' },
      body: { roomNumber: 'Phòng 201 - Tim mạch (Tầng 2)' },
    }),
  );
  assert.equal(checkinRes1.statusCode, 200);
  const checkedIn1 = JSON.parse(checkinRes1.body);
  assert.equal(checkedIn1.status, 'checked_in');
  assert.equal(checkedIn1.queueNumber, 1);
  assert.equal(checkedIn1.roomNumber, 'Phòng 201 - Tim mạch (Tầng 2)');
  assert.ok(checkedIn1.checkedInAt);

  // 5. Patient 2 arrives at reception and checks in -> gets STT 2
  const checkinRes2 = await handler(
    eventFor({
      method: 'POST',
      path: `/appointments/${apt2.id}/checkin`,
      pathParameters: { id: apt2.id, action: 'checkin' },
    }),
  );
  assert.equal(checkinRes2.statusCode, 200);
  const checkedIn2 = JSON.parse(checkinRes2.body);
  assert.equal(checkedIn2.status, 'checked_in');
  assert.equal(checkedIn2.queueNumber, 2);

  // 6. Check-in is idempotent: calling check-in again returns same STT 1
  const reCheckin1 = await handler(
    eventFor({
      method: 'POST',
      path: `/appointments/${apt1.id}/checkin`,
      pathParameters: { id: apt1.id, action: 'checkin' },
    }),
  );
  assert.equal(reCheckin1.statusCode, 200);
  assert.equal(JSON.parse(reCheckin1.body).queueNumber, 1);

  // 7. Waiting room monitor queries queue: GET /doctors/dr-linh/queue
  const queueRes = await handler(
    eventFor({
      method: 'GET',
      path: `/doctors/dr-linh/queue`,
      pathParameters: { doctorId: 'dr-linh' },
      queryStringParameters: { date: targetDate },
    }),
  );
  assert.equal(queueRes.statusCode, 200);
  const queueData = JSON.parse(queueRes.body);
  assert.equal(queueData.totalCheckedIn, 2);
  assert.equal(queueData.currentServingQueueNumber, 1);
  assert.ok(queueData.queue.length >= 2);

  // 8. Doctor conducts examination and completes patient 1 from checked_in
  const completeRes = await handler(
    eventFor({
      doctorId: 'dr-linh',
      role: 'doctors',
      method: 'PATCH',
      path: `/appointments/${apt1.id}/status`,
      pathParameters: { id: apt1.id, action: 'status' },
      body: {
        status: 'completed',
        diagnosis: 'Nhịp xoang nhanh',
        prescription: 'Concor 2.5mg',
      },
    }),
  );
  assert.equal(completeRes.statusCode, 200);
  assert.equal(JSON.parse(completeRes.body).status, 'completed');
});

test('Appointment API: Pre-visit Clinical Intake Survey', async () => {
  await resetAppointments();

  // 1. Patient creates appointment
  const createRes = await handler(
    eventFor({
      patientId: 'patient-intake-test',
      method: 'POST',
      body: sampleAppointment(),
    }),
  );
  assert.equal(createRes.statusCode, 201);
  const apt = JSON.parse(createRes.body);
  assert.equal(apt.hasIntake, false);

  // 2. Patient submits pre-visit intake survey
  const intakeBody = {
    chiefComplaint: 'Đau tức ngực trái khi gắng sức, lan ra cánh tay trái',
    painLocation: 'Ngực / Tim mạch',
    onsetDuration: '3 ngày trước',
    painLevel: 7,
    symptoms: ['Đau thắt', 'Khó thở khi gắng sức', 'Hồi hộp đánh trống ngực'],
    currentMedications: 'Aspirin 81mg (1 viên/ngày), Panadol khi đau đầu',
    medicalHistory: 'Tăng huyết áp 2 năm, chưa từng phẫu thuật',
    knownAllergies: 'Dị ứng kháng sinh Penicillin (nổi mề đay)',
    notes: 'Bác sĩ kiểm tra kỹ giúp em vì gia đình có tiền sử bệnh tim mạch.',
  };

  const submitRes = await handler(
    eventFor({
      patientId: 'patient-intake-test',
      method: 'POST',
      path: `/appointments/${apt.id}/intake`,
      pathParameters: { id: apt.id, action: 'intake' },
      body: intakeBody,
    }),
  );
  assert.equal(submitRes.statusCode, 200);
  const savedIntake = JSON.parse(submitRes.body);
  assert.equal(savedIntake.appointmentId, apt.id);
  assert.equal(savedIntake.painLevel, 7);
  assert.equal(savedIntake.onsetDuration, '3 ngày trước');
  assert.ok(savedIntake.symptoms.includes('Đau thắt'));
  assert.match(savedIntake.knownAllergies, /Penicillin/);

  // 3. GET /appointments/:id/intake retrieves the survey
  const getRes = await handler(
    eventFor({
      patientId: 'patient-intake-test',
      method: 'GET',
      path: `/appointments/${apt.id}/intake`,
      pathParameters: { id: apt.id, action: 'intake' },
    }),
  );
  assert.equal(getRes.statusCode, 200);
  const fetchedIntake = JSON.parse(getRes.body);
  assert.equal(fetchedIntake.painLevel, 7);

  // 4. Appointment detail now reflects hasIntake = true
  const aptRes = await handler(
    eventFor({
      patientId: 'patient-intake-test',
      method: 'GET',
      path: `/appointments/${apt.id}`,
      pathParameters: { id: apt.id },
    }),
  );
  assert.equal(aptRes.statusCode, 200);
  assert.equal(JSON.parse(aptRes.body).hasIntake, true);
});



