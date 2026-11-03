import assert from 'node:assert/strict';
import test from 'node:test';
import { run } from '../src/database/db.js';
import { handler as appointmentHandler } from '../src/handlers/appointments.js';
import { handler as teleconHandler } from '../src/handlers/teleconsultations.js';

test('Post-Care Teleconsultation: Full Lifecycle Test Suite', async () => {
  const patientSub = 'test-patient-sub-123';
  const doctorId = 'dr-linh';
  const appointmentId = `APT-TEST-TC-${Date.now()}`;
  const now = new Date();
  const scheduledAt = now.toISOString();

  // Seed test appointment
  await run(
    `INSERT INTO appointments (
      id, patient_id, patient_name, doctor_id, doctor_name, department, specialty,
      scheduled_at, time, reason, status, created_at, updated_at
    ) VALUES (?, ?, 'Nguyễn Văn An', ?, 'BS. Trần Thảo Linh', 'Tim mạch', 'Tim mạch', ?, '09:00', 'Đau ngực nhẹ', 'confirmed', ?, ?)`,
    [appointmentId, patientSub, doctorId, scheduledAt, scheduledAt, scheduledAt],
  );

  // 1. Cannot open teleconsultation for confirmed (not yet completed) appointment
  const pendingEvent = {
    httpMethod: 'GET',
    path: `/teleconsultations/appointment/${appointmentId}`,
    pathParameters: { appointmentId },
    requestContext: { authorizer: { claims: { sub: patientSub } } },
  };
  const pendingRes = await teleconHandler(pendingEvent);
  assert.equal(pendingRes.statusCode, 400);
  const pendingErr = JSON.parse(pendingRes.body);
  assert.match(pendingErr.message, /Chỉ ca khám đã hoàn tất/);

  // 2. Doctor completes the appointment with diagnosis & prescription
  const completeEvent = {
    httpMethod: 'PATCH',
    path: `/appointments/${appointmentId}/status`,
    pathParameters: { id: appointmentId, action: 'status' },
    body: JSON.stringify({
      status: 'completed',
      diagnosis: 'Tăng huyết áp vô căn giai đoạn 1',
      prescription: 'Amlodipine 5mg x 1 viên/ngày buổi sáng',
    }),
    requestContext: { authorizer: { claims: { sub: doctorId, doctorId, 'cognito:groups': 'doctors' } } },
  };
  const completeRes = await appointmentHandler(completeEvent);
  assert.equal(completeRes.statusCode, 200);

  // 3. Open teleconsultation session after completion
  const openEvent = {
    httpMethod: 'GET',
    path: `/teleconsultations/appointment/${appointmentId}`,
    pathParameters: { appointmentId },
    requestContext: { authorizer: { claims: { sub: patientSub } } },
  };
  const openRes = await teleconHandler(openEvent);
  assert.equal(openRes.statusCode, 200);
  const session = JSON.parse(openRes.body);
  assert.equal(session.appointment_id, appointmentId);
  assert.equal(session.doctor_name, 'BS. Trần Thảo Linh');
  assert.equal(session.status, 'active');
  assert.equal(session.canChat, true);
  assert.ok(session.daysRemaining >= 6 && session.daysRemaining <= 7);
  assert.ok(session.messages.length >= 1);
  assert.equal(session.messages[0].sender_type, 'system');
  assert.match(session.messages[0].message, /BS\. Trần Thảo Linh/);

  const sessionId = session.id;

  // 4. Patient sends message asking about dizziness & attaching photo
  const sendMsgEvent = {
    httpMethod: 'POST',
    path: `/teleconsultations/sessions/${sessionId}/messages`,
    pathParameters: { id: sessionId, action: 'messages' },
    body: JSON.stringify({
      message: 'Bác sĩ cho em hỏi sau khi uống thuốc em thấy hơi choáng váng nhẹ khi đứng dậy, có sao không ạ?',
      imageUrl: 'https://cdn.hospital.vn/photos/symptom_sample_1.jpg',
      senderName: 'Nguyễn Văn An',
    }),
    requestContext: { authorizer: { claims: { sub: patientSub } } },
  };
  const sendRes = await teleconHandler(sendMsgEvent);
  assert.equal(sendRes.statusCode, 201);
  const sentMsg = JSON.parse(sendRes.body);
  assert.equal(sentMsg.sender_type, 'patient');
  assert.match(sentMsg.message, /choáng váng nhẹ/);
  assert.equal(sentMsg.image_url, 'https://cdn.hospital.vn/photos/symptom_sample_1.jpg');

  // 5. Doctor lists teleconsultation sessions and checks unread messages
  const docListEvent = {
    httpMethod: 'GET',
    path: `/teleconsultations/doctor/${doctorId}`,
    pathParameters: { doctorId },
    requestContext: { authorizer: { claims: { sub: doctorId, doctorId, 'cognito:groups': 'doctors' } } },
  };
  const docListRes = await teleconHandler(docListEvent);
  assert.equal(docListRes.statusCode, 200);
  const docList = JSON.parse(docListRes.body);
  const currentDocSession = docList.items.find((s) => s.id === sessionId);
  assert.ok(currentDocSession);
  assert.equal(currentDocSession.unreadCount, 1);
  assert.match(currentDocSession.lastMessage, /choáng váng/);

  // 6. Doctor marks messages as read
  const readEvent = {
    httpMethod: 'POST',
    path: `/teleconsultations/sessions/${sessionId}/read`,
    pathParameters: { id: sessionId, action: 'read' },
    requestContext: { authorizer: { claims: { sub: doctorId, doctorId, 'cognito:groups': 'doctors' } } },
  };
  const readRes = await teleconHandler(readEvent);
  assert.equal(readRes.statusCode, 200);

  // 7. Doctor replies with clinical advice
  const docReplyEvent = {
    httpMethod: 'POST',
    path: `/teleconsultations/sessions/${sessionId}/messages`,
    pathParameters: { id: sessionId, action: 'messages' },
    body: JSON.stringify({
      senderType: 'doctor',
      senderName: 'BS. Trần Thảo Linh',
      message: 'Chào bạn, đây là hiện tượng hạ huyết áp tư thế nhẹ khi mới bắt đầu dùng Amlodipine. Bạn nên thay đổi tư thế từ từ và uống đủ 2 lít nước mỗi ngày nhé.',
    }),
    requestContext: { authorizer: { claims: { sub: doctorId, doctorId, 'cognito:groups': 'doctors' } } },
  };
  const docReplyRes = await teleconHandler(docReplyEvent);
  assert.equal(docReplyRes.statusCode, 201);
  const docMsg = JSON.parse(docReplyRes.body);
  assert.equal(docMsg.sender_type, 'doctor');

  // 8. Doctor closes the consultation session
  const closeEvent = {
    httpMethod: 'PATCH',
    path: `/teleconsultations/sessions/${sessionId}/close`,
    pathParameters: { id: sessionId, action: 'close' },
    body: JSON.stringify({ closedByName: 'BS. Trần Thảo Linh' }),
    requestContext: { authorizer: { claims: { sub: doctorId, doctorId, 'cognito:groups': 'doctors' } } },
  };
  const closeRes = await teleconHandler(closeEvent);
  assert.equal(closeRes.statusCode, 200);
  const closedSession = JSON.parse(closeRes.body);
  assert.equal(closedSession.status, 'closed');
  assert.equal(closedSession.canChat, false);

  // 9. Rejects message when session is closed
  const rejectEvent = {
    httpMethod: 'POST',
    path: `/teleconsultations/sessions/${sessionId}/messages`,
    pathParameters: { id: sessionId, action: 'messages' },
    body: JSON.stringify({ message: 'Thuốc này uống thêm được không bác sĩ?' }),
    requestContext: { authorizer: { claims: { sub: patientSub } } },
  };
  const rejectRes = await teleconHandler(rejectEvent);
  assert.equal(rejectRes.statusCode, 400);
  const rejectErr = JSON.parse(rejectRes.body);
  assert.match(rejectErr.message, /kết thúc/);
});
