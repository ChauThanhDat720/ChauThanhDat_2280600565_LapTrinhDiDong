import { all, get, run } from '../database/db.js';

export function calculateDaysRemaining(expiresAt) {
  const diffMs = new Date(expiresAt).getTime() - Date.now();
  if (diffMs <= 0) return 0;
  return Math.ceil(diffMs / (1000 * 60 * 60 * 24));
}

export function isSessionExpired(session) {
  if (session.status === 'expired') return true;
  return new Date(session.expires_at).getTime() < Date.now();
}

export async function getOrCreateSessionForAppointment(appointmentId, caller = {}) {
  let session = await get(
    'SELECT * FROM teleconsultation_sessions WHERE appointment_id = ?',
    [appointmentId],
  );

  if (!session) {
    const appt = await get('SELECT * FROM appointments WHERE id = ?', [appointmentId]);
    if (!appt) {
      throw new Error(`Không tìm thấy ca khám ${appointmentId}.`);
    }
    if (appt.status !== 'completed') {
      throw new Error('Chỉ ca khám đã hoàn tất mới được mở kênh tư vấn y tế hậu khám 7 ngày.');
    }

    const now = new Date();
    // Default 7 days from completion or appointment scheduled date
    const baseDate = appt.updated_at ? new Date(appt.updated_at) : now;
    const expiresAt = new Date(baseDate.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString();
    const sessionId = `tc-${appointmentId}`;
    const createdAt = now.toISOString();

    await run(
      `INSERT INTO teleconsultation_sessions (
        id, appointment_id, patient_id, patient_name, doctor_id, doctor_name,
        department, diagnosis, prescription, status, expires_at, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?)`,
      [
        sessionId,
        appt.id,
        appt.patient_id,
        appt.patient_name,
        appt.doctor_id,
        appt.doctor_name,
        appt.department || appt.specialty,
        appt.diagnosis || 'Theo dõi sau khám',
        appt.prescription || '',
        expiresAt,
        createdAt,
        createdAt,
      ],
    );

    // Seed welcome system message
    const welcomeMsgId = `msg-sys-${Date.now()}`;
    const examDateStr = (appt.scheduled_at || '').substring(0, 10);
    const welcomeText = `Chào bạn! Kênh tư vấn y tế hậu khám 7 ngày với ${appt.doctor_name} cho ca khám ngày ${examDateStr} đã được kích hoạt. Bạn có thể gửi câu hỏi về phản ứng thuốc, thắc mắc liều dùng hoặc gửi hình ảnh triệu chứng (nốt phát ban, vỉ thuốc) để bác sĩ tư vấn.`;

    await run(
      `INSERT INTO teleconsultation_messages (
        id, session_id, sender_type, sender_id, sender_name, message, image_url, is_read, created_at
      ) VALUES (?, ?, 'system', 'system', 'Hệ thống Bệnh viện', ?, NULL, 1, ?)`,
      [welcomeMsgId, sessionId, welcomeText, createdAt],
    );

    session = await get('SELECT * FROM teleconsultation_sessions WHERE id = ?', [sessionId]);
  }

  return attachSessionDetails(session, caller);
}

export async function getSessionById(sessionId, caller = {}) {
  const session = await get('SELECT * FROM teleconsultation_sessions WHERE id = ?', [sessionId]);
  if (!session) return null;
  return attachSessionDetails(session, caller);
}

async function attachSessionDetails(session, caller = {}) {
  const expired = isSessionExpired(session);
  const status = session.status === 'closed' ? 'closed' : (expired ? 'expired' : session.status);
  const daysRemaining = calculateDaysRemaining(session.expires_at);

  const messages = await all(
    'SELECT * FROM teleconsultation_messages WHERE session_id = ? ORDER BY created_at ASC',
    [session.id],
  );

  const isDoctor = caller.isDoctor || caller.role === 'doctors';
  const unreadTarget = isDoctor ? 'patient' : 'doctor';
  const unreadCount = messages.filter((m) => m.sender_type === unreadTarget && m.is_read === 0).length;

  return {
    ...session,
    status,
    isExpired: expired,
    canChat: status === 'active',
    daysRemaining,
    unreadCount,
    messages: messages.map((m) => ({
      ...m,
      is_read: Boolean(m.is_read),
    })),
  };
}

export async function listSessionsForDoctor(doctorId) {
  let sql = 'SELECT * FROM teleconsultation_sessions';
  const params = [];
  if (doctorId && doctorId !== 'all') {
    sql += ' WHERE doctor_id = ?';
    params.push(doctorId);
  }
  sql += ' ORDER BY updated_at DESC';

  const rows = await all(sql, params);
  const results = [];
  for (const row of rows) {
    const expired = isSessionExpired(row);
    const status = row.status === 'closed' ? 'closed' : (expired ? 'expired' : row.status);
    const daysRemaining = calculateDaysRemaining(row.expires_at);

    const lastMsg = await get(
      'SELECT message, created_at, sender_name, sender_type FROM teleconsultation_messages WHERE session_id = ? ORDER BY created_at DESC LIMIT 1',
      [row.id],
    );
    const unread = await get(
      "SELECT COUNT(*) as count FROM teleconsultation_messages WHERE session_id = ? AND sender_type = 'patient' AND is_read = 0",
      [row.id],
    );

    results.push({
      ...row,
      status,
      isExpired: expired,
      canChat: status === 'active',
      daysRemaining,
      unreadCount: unread?.count || 0,
      lastMessage: lastMsg?.message || null,
      lastMessageSender: lastMsg?.sender_name || null,
      lastMessageAt: lastMsg?.created_at || row.updated_at,
    });
  }
  return results;
}

export async function listSessionsForPatient(patientId) {
  const rows = await all(
    'SELECT * FROM teleconsultation_sessions WHERE patient_id = ? ORDER BY updated_at DESC',
    [patientId],
  );
  const results = [];
  for (const row of rows) {
    const expired = isSessionExpired(row);
    const status = row.status === 'closed' ? 'closed' : (expired ? 'expired' : row.status);
    const daysRemaining = calculateDaysRemaining(row.expires_at);

    const lastMsg = await get(
      'SELECT message, created_at, sender_name, sender_type FROM teleconsultation_messages WHERE session_id = ? ORDER BY created_at DESC LIMIT 1',
      [row.id],
    );
    const unread = await get(
      "SELECT COUNT(*) as count FROM teleconsultation_messages WHERE session_id = ? AND sender_type = 'doctor' AND is_read = 0",
      [row.id],
    );

    results.push({
      ...row,
      status,
      isExpired: expired,
      canChat: status === 'active',
      daysRemaining,
      unreadCount: unread?.count || 0,
      lastMessage: lastMsg?.message || null,
      lastMessageSender: lastMsg?.sender_name || null,
      lastMessageAt: lastMsg?.created_at || row.updated_at,
    });
  }
  return results;
}

export async function addMessage(sessionId, { senderType, senderId, senderName, message, imageUrl }) {
  const session = await get('SELECT * FROM teleconsultation_sessions WHERE id = ?', [sessionId]);
  if (!session) {
    throw new Error('Không tìm thấy phiên tư vấn.');
  }

  if (session.status === 'closed') {
    throw new Error('Phiên tư vấn này đã được bác sĩ kết thúc.');
  }

  if (isSessionExpired(session)) {
    throw new Error('Phiên tư vấn hậu khám 7 ngày đã kết thúc. Vui lòng đặt lịch tái khám nếu triệu chứng vẫn tiếp diễn.');
  }

  if (!message || message.trim().length === 0) {
    throw new Error('Nội dung tin nhắn không được để trống.');
  }

  const id = `msg-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`;
  const now = new Date().toISOString();

  await run(
    `INSERT INTO teleconsultation_messages (
      id, session_id, sender_type, sender_id, sender_name, message, image_url, is_read, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)`,
    [id, sessionId, senderType, senderId, senderName, message.trim(), imageUrl || null, now],
  );

  await run(
    'UPDATE teleconsultation_sessions SET updated_at = ? WHERE id = ?',
    [now, sessionId],
  );

  return {
    id,
    session_id: sessionId,
    sender_type: senderType,
    sender_id: senderId,
    sender_name: senderName,
    message: message.trim(),
    image_url: imageUrl || null,
    is_read: false,
    created_at: now,
  };
}

export async function closeSession(sessionId, closedByName = 'Bác sĩ điều trị') {
  const session = await get('SELECT * FROM teleconsultation_sessions WHERE id = ?', [sessionId]);
  if (!session) {
    throw new Error('Không tìm thấy phiên tư vấn.');
  }

  const now = new Date().toISOString();
  await run(
    "UPDATE teleconsultation_sessions SET status = 'closed', updated_at = ? WHERE id = ?",
    [now, sessionId],
  );

  const sysMsgId = `msg-sys-${Date.now()}`;
  const closeText = `${closedByName} đã đóng phiên tư vấn này. Chúc bạn sức khỏe mau hồi phục!`;
  await run(
    `INSERT INTO teleconsultation_messages (
      id, session_id, sender_type, sender_id, sender_name, message, image_url, is_read, created_at
    ) VALUES (?, ?, 'system', 'system', 'Hệ thống Bệnh viện', ?, NULL, 1, ?)`,
    [sysMsgId, sessionId, closeText, now],
  );

  return getSessionById(sessionId);
}

export async function markMessagesAsRead(sessionId, readerType) {
  // If reader is doctor, mark patient messages as read. If reader is patient, mark doctor messages as read.
  const targetSenderType = readerType === 'doctor' ? 'patient' : 'doctor';
  await run(
    'UPDATE teleconsultation_messages SET is_read = 1 WHERE session_id = ? AND sender_type = ?',
    [sessionId, targetSenderType],
  );
  return { success: true };
}
