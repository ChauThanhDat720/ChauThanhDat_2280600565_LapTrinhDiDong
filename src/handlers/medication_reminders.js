import { SqliteMedicationReminderRepository } from '../repositories/sqlite_medication_reminder_repository.js';

const repo = new SqliteMedicationReminderRepository();

const jsonResponse = (statusCode, body) => ({
  statusCode,
  headers: {
    'content-type': 'application/json',
    'access-control-allow-origin': '*',
  },
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  const method = event.httpMethod || event.requestContext?.http?.method;
  const path = event.path || '';
  const claims = event.requestContext?.authorizer?.claims || {};
  const query = event.queryStringParameters || {};
  const patientId = query.patientId || claims.sub || 'test-patient-sub-123';

  let body = {};
  if (event.body) {
    try {
      body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    } catch (_) {
      return jsonResponse(400, { message: 'Dữ liệu JSON không hợp lệ' });
    }
  }

  try {
    // 1. GET Today's doses & stats
    if (path.endsWith('/today') && method === 'GET') {
      const date = query.date || new Date().toISOString().slice(0, 10);
      const doses = await repo.getTodayDoses(patientId, date);
      const stats = await repo.getComplianceStats(patientId, { days: 7 });
      return jsonResponse(200, { date, doses, stats });
    }

    // 2. POST from prescription (1-click generation)
    if (path.endsWith('/from-prescription') && method === 'POST') {
      const prescription = body.prescription;
      if (!prescription) {
        return jsonResponse(400, { message: 'Đơn thuốc không được để trống' });
      }
      const reminders = await repo.createFromPrescription({
        patientId,
        appointmentId: body.appointmentId,
        prescription,
        daysCount: body.daysCount || 7,
      });
      return jsonResponse(201, {
        message: `Đã tạo thành công ${reminders.length} lời nhắc uống thuốc từ đơn`,
        reminders,
      });
    }

    // 3. POST dose status (mark as taken / skipped)
    if (event.pathParameters?.action === 'dose' && method === 'POST') {
      const logId = event.pathParameters.id;
      const status = body.status;
      if (!status || !['taken', 'skipped', 'pending'].includes(status)) {
        return jsonResponse(400, { message: 'Trạng thái liều thuốc không hợp lệ' });
      }
      const updated = await repo.updateDoseStatus(logId, {
        status,
        takenAt: body.takenAt,
        note: body.note,
      });
      if (!updated) {
        return jsonResponse(404, { message: 'Không tìm thấy liều thuốc cần cập nhật' });
      }
      return jsonResponse(200, { message: 'Cập nhật trạng thái liều uống thành công', dose: updated });
    }

    // 4. PATCH toggle active/inactive
    if (event.pathParameters?.action === 'toggle' && method === 'PATCH') {
      const reminderId = event.pathParameters.id;
      const isActive = body.isActive !== undefined ? Boolean(body.isActive) : true;
      const updated = await repo.toggleReminder(reminderId, isActive);
      return jsonResponse(200, { reminder: updated });
    }

    // 5. DELETE reminder
    if (event.pathParameters?.id && method === 'DELETE') {
      const reminderId = event.pathParameters.id;
      await repo.deleteReminder(reminderId);
      return jsonResponse(200, { message: 'Đã xóa lời nhắc uống thuốc', success: true });
    }

    // 6. GET list of reminders
    if (method === 'GET') {
      const isActive = query.isActive !== undefined ? query.isActive === 'true' : undefined;
      const reminders = await repo.getReminders(patientId, { isActive });
      return jsonResponse(200, { reminders });
    }

    // 7. POST create manual reminder
    if (method === 'POST') {
      if (!body.medicineName || !body.medicineName.trim()) {
        return jsonResponse(400, { message: 'Tên thuốc không được để trống' });
      }
      const reminder = await repo.createReminder({
        ...body,
        patientId,
      });
      return jsonResponse(201, { reminder });
    }

    return jsonResponse(405, { message: 'Phương thức không được hỗ trợ' });
  } catch (err) {
    console.error('Lỗi Medication Reminder Handler:', err);
    return jsonResponse(500, { message: 'Lỗi máy chủ nội bộ', error: err.message });
  }
};
