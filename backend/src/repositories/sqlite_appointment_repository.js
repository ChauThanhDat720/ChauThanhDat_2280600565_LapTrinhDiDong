import { createHash, randomUUID } from 'node:crypto';
import * as db from '../database/db.js';
import { HttpError } from '../utils/http.js';
import { validateStatusTransition } from '../utils/validation.js';

const getDoctorDefaultRoom = (doctorId, departmentId) => {
  const rooms = {
    'dr-linh': 'Phòng 204 - Tầng 2',
    'dr-duc': 'Phòng 105 - Tầng 1',
    'dr-lan': 'Phòng 302 - Tầng 3',
    'dr-tuan': 'Phòng 201 - Tầng 2',
    'dr-huong': 'Phòng 212 - Tầng 2',
    'dr-phong': 'Phòng 310 - Tầng 3',
    'dr-mai': 'Phòng 118 - Tầng 1',
    'dr-khanh': 'Phòng 308 - Tầng 3',
  };
  if (rooms[doctorId]) return rooms[doctorId];
  const dept = (departmentId || '').toLowerCase();
  if (dept.includes('nhi')) return 'Phòng 105 - Tầng 1';
  if (dept.includes('xương') || dept.includes('chấn thương')) return 'Phòng 118 - Tầng 1';
  if (dept.includes('da liễu') || dept.includes('thần kinh') || dept.includes('răng')) return 'Phòng 302 - Tầng 3';
  return 'Phòng 204 - Tầng 2';
};

// Convert SQL row to Appointment Domain Object
const toDomain = (row) => {
  if (!row) return undefined;
  return {
    id: row.id,
    appointmentId: row.id,
    patientId: row.patient_id,
    patientName: row.patient_name,
    doctorId: row.doctor_id,
    doctorName: row.doctor_name,
    department: row.department,
    specialty: row.specialty,
    scheduledAt: row.scheduled_at,
    time: row.time,
    reason: row.reason,
    status: row.status,
    statusNote: row.status_note || undefined,
    diagnosis: row.diagnosis || undefined,
    prescription: row.prescription || undefined,
    rating: row.rating ?? undefined,
    reviewNote: row.review_note || undefined,
    reviewedAt: row.reviewed_at || undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    cancelledAt: row.cancelled_at || undefined,
    cancellationReason: row.cancellation_reason || undefined,
    queueNumber: row.queue_number ?? undefined,
    checkedInAt: row.checked_in_at || undefined,
    roomNumber: row.room_number || getDoctorDefaultRoom(row.doctor_id, row.department),
    followUpDate: row.follow_up_date || undefined,
    isFollowUp: Boolean(row.is_follow_up),
    parentAppointmentId: row.parent_appointment_id || undefined,
    hasIntake: Boolean(row.has_intake),
  };
};

export const listByPatient = async (patientId) => {
  const rows = await db.all(
    'SELECT * FROM appointments WHERE patient_id = ? ORDER BY scheduled_at ASC',
    [patientId],
  );
  return rows.map(toDomain);
};

export const listByDoctor = async (doctorId, date) => {
  let sql = 'SELECT * FROM appointments WHERE doctor_id = ?';
  const params = [doctorId];
  if (date) {
    sql += ' AND scheduled_at LIKE ? || "%"';
    params.push(date);
  }
  sql += ' ORDER BY scheduled_at ASC';
  const rows = await db.all(sql, params);
  return rows.map(toDomain);
};

export const getForPatient = async (patientId, appointmentId) => {
  const row = await db.get(
    'SELECT * FROM appointments WHERE id = ? AND patient_id = ?',
    [appointmentId, patientId],
  );
  return toDomain(row);
};

const STANDARD_SLOTS = [
  '08:00',
  '08:30',
  '09:00',
  '09:30',
  '10:00',
  '10:30',
  '11:00',
  '13:30',
  '14:00',
  '14:30',
  '15:00',
  '15:30',
  '16:00',
  '16:30',
];

export const getDoctorAvailability = async (doctorId, dateString) => {
  const rows = await db.all(
    `SELECT time FROM appointments 
     WHERE doctor_id = ? AND scheduled_at LIKE ? || "%" AND status IN ('pending', 'confirmed')`,
    [doctorId, dateString],
  );
  const booked = new Set(rows.map((r) => r.time));

  const parsedDate = new Date(`${dateString}T00:00:00.000Z`);
  const isPastDate =
    Number.isNaN(parsedDate.getTime()) ||
    Date.now() > parsedDate.getTime() + 86400000;

  const slots = STANDARD_SLOTS.map((slotTime) => {
    const isBooked = booked.has(slotTime);
    return {
      time: slotTime,
      isAvailable: !isBooked && !isPastDate,
      reason: isPastDate
        ? 'Ngày trong quá khứ'
        : isBooked
          ? 'Đã có lịch hẹn'
          : undefined,
    };
  });

  return {
    doctorId,
    date: dateString,
    slots,
  };
};

export const create = async (patientId, appointmentInput, idempotencyKey) => {
  // Idempotency check
  if (idempotencyKey) {
    const existing = await db.get(
      'SELECT appointment_id FROM idempotency_keys WHERE key = ?',
      [idempotencyKey],
    );
    if (existing) {
      const existingAppt = await db.get(
        'SELECT * FROM appointments WHERE id = ?',
        [existing.appointment_id],
      );
      return toDomain(existingAppt);
    }
  }

  // Conflict detection: Doctor cannot have 2 appointments in the same slot
  const conflict = await db.get(
    `SELECT id FROM appointments 
     WHERE doctor_id = ? AND scheduled_at = ? AND time = ? AND status IN ('pending', 'confirmed')`,
    [
      appointmentInput.doctorId,
      appointmentInput.scheduledAt,
      appointmentInput.time,
    ],
  );

  if (conflict) {
    throw new HttpError(
      409,
      'Khung giờ này đã được đặt trước bởi bệnh nhân khác. Vui lòng chọn giờ khác.',
    );
  }

  const id = `APT-${randomUUID().slice(0, 8).toUpperCase()}`;
  const now = new Date().toISOString();

  // Ensure doctor exists in doctors table (auto-create if needed)
  const doctorExists = await db.get('SELECT id FROM doctors WHERE id = ?', [
    appointmentInput.doctorId,
  ]);
  if (!doctorExists) {
    await db.run(
      'INSERT INTO doctors (id, name, specialty, department) VALUES (?, ?, ?, ?)',
      [
        appointmentInput.doctorId,
        appointmentInput.doctorName,
        appointmentInput.specialty,
        appointmentInput.department,
      ],
    );
  }

  await db.run(
    `INSERT INTO appointments (
      id, patient_id, patient_name, doctor_id, doctor_name, department, specialty,
      scheduled_at, time, reason, status, is_follow_up, parent_appointment_id, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?)`,
    [
      id,
      patientId,
      appointmentInput.patientName || 'Bệnh nhân',
      appointmentInput.doctorId,
      appointmentInput.doctorName,
      appointmentInput.department,
      appointmentInput.specialty,
      appointmentInput.scheduledAt,
      appointmentInput.time,
      appointmentInput.reason,
      appointmentInput.isFollowUp ? 1 : 0,
      appointmentInput.parentAppointmentId || null,
      now,
      now,
    ],
  );

  if (idempotencyKey) {
    await db.run(
      'INSERT INTO idempotency_keys (key, appointment_id, created_at) VALUES (?, ?, ?)',
      [idempotencyKey, id, now],
    );
  }

  const createdRow = await db.get('SELECT * FROM appointments WHERE id = ?', [id]);
  return toDomain(createdRow);
};

export const cancelForPatient = async (patientId, appointmentId, reason = '') => {
  const row = await db.get(
    'SELECT * FROM appointments WHERE id = ? AND patient_id = ?',
    [appointmentId, patientId],
  );
  if (!row) return undefined;

  if (row.status !== 'pending' && row.status !== 'confirmed') {
    throw new HttpError(
      400,
      `Không thể hủy lịch khám đang ở trạng thái ${row.status}.`,
    );
  }

  const now = new Date().toISOString();
  await db.run(
    `UPDATE appointments 
     SET status = 'cancelled', cancelled_at = ?, cancellation_reason = ?, updated_at = ?
     WHERE id = ?`,
    [now, reason, now, appointmentId],
  );

  const updatedRow = await db.get('SELECT * FROM appointments WHERE id = ?', [
    appointmentId,
  ]);
  return toDomain(updatedRow);
};

export const updateStatusByDoctor = async (
  doctorId,
  appointmentId,
  targetStatus,
  note = '',
  diagnosis,
  prescription,
  followUpDate,
) => {
  const row = await db.get(
    'SELECT * FROM appointments WHERE id = ? AND doctor_id = ?',
    [appointmentId, doctorId],
  );
  if (!row) return undefined;

  validateStatusTransition(row.status, targetStatus);

  const now = new Date().toISOString();
  await db.run(
    `UPDATE appointments 
     SET status = ?, status_note = ?, 
         diagnosis = COALESCE(?, diagnosis), 
         prescription = COALESCE(?, prescription), 
         follow_up_date = COALESCE(?, follow_up_date), 
         updated_at = ?
     WHERE id = ?`,
    [targetStatus, note, diagnosis, prescription, followUpDate || null, now, appointmentId],
  );

  const updatedRow = await db.get('SELECT * FROM appointments WHERE id = ?', [
    appointmentId,
  ]);
  return toDomain(updatedRow);
};

export const rateAppointmentByPatient = async (
  patientId,
  appointmentId,
  rating,
  reviewNote = '',
) => {
  const row = await db.get(
    'SELECT * FROM appointments WHERE id = ? AND patient_id = ?',
    [appointmentId, patientId],
  );
  if (!row) return undefined;

  if (row.status !== 'completed') {
    throw new HttpError(400, 'Chỉ có thể đánh giá ca khám đã hoàn thành.');
  }

  const now = new Date().toISOString();
  await db.run(
    `UPDATE appointments 
     SET rating = ?, review_note = ?, reviewed_at = ?, updated_at = ?
     WHERE id = ?`,
    [rating, reviewNote, now, now, appointmentId],
  );

  const updatedRow = await db.get('SELECT * FROM appointments WHERE id = ?', [
    appointmentId,
  ]);
  return toDomain(updatedRow);
};

export const getById = async (appointmentId) => {
  const row = await db.get('SELECT * FROM appointments WHERE id = ?', [appointmentId]);
  return toDomain(row);
};

export const getMedicalRecord = async (appointmentId) => {
  const row = await db.get('SELECT * FROM appointments WHERE id = ?', [appointmentId]);
  if (!row) return undefined;

  if (row.status !== 'completed') {
    throw new HttpError(400, 'Ca khám này chưa hoàn tất để xuất hồ sơ bệnh án và đơn thuốc.');
  }

  const domain = toDomain(row);
  const signaturePayload = `${row.id}|${row.patient_id}|${row.doctor_id}|${row.diagnosis || ''}|${row.prescription || ''}|${row.updated_at}`;
  const digitalSignature = createHash('sha256').update(signaturePayload).digest('hex').toUpperCase();

  return {
    verified: true,
    hospital: 'Bệnh viện Đa khoa Quốc tế Smart Hospital',
    licenseNumber: 'BYT-SYT-HCM-2026/8899',
    recordId: domain.id,
    appointmentId: domain.id,
    patientId: domain.patientId,
    patientName: domain.patientName,
    doctorId: domain.doctorId,
    doctorName: domain.doctorName,
    department: domain.department,
    specialty: domain.specialty,
    examinationDate: domain.scheduledAt,
    time: domain.time,
    reason: domain.reason,
    diagnosis: domain.diagnosis || 'Đang theo dõi lâm sàng',
    prescription: domain.prescription || 'Chưa có đơn thuốc',
    doctorNote: domain.statusNote || undefined,
    digitalSignature,
    issuedAt: domain.updatedAt,
  };
};

export const checkinAppointment = async (appointmentId, { roomNumber } = {}) => {
  const row = await db.get('SELECT * FROM appointments WHERE id = ?', [appointmentId]);
  if (!row) return undefined;

  // Idempotent: already checked in
  if (row.status === 'checked_in') {
    return toDomain(row);
  }

  if (row.status !== 'confirmed') {
    throw new HttpError(
      400,
      `Không thể tiếp đón ca khám đang ở trạng thái "${row.status}". Chỉ ca khám đã được bác sĩ xác nhận (confirmed) mới có thể làm thủ tục tiếp đón.`,
    );
  }

  const scheduledDate = row.scheduled_at.slice(0, 10);
  const maxRow = await db.get(
    `SELECT MAX(queue_number) as maxQueue FROM appointments 
     WHERE doctor_id = ? AND scheduled_at LIKE ? || '%' AND queue_number IS NOT NULL`,
    [row.doctor_id, scheduledDate],
  );

  const nextQueue = (maxRow?.maxQueue || 0) + 1;
  const now = new Date().toISOString();
  const assignedRoom =
    roomNumber ||
    row.room_number ||
    getDoctorDefaultRoom(row.doctor_id, row.department);

  await db.run(
    `UPDATE appointments 
     SET status = 'checked_in', queue_number = ?, checked_in_at = ?, room_number = ?, updated_at = ?
     WHERE id = ?`,
    [nextQueue, now, assignedRoom, now, appointmentId],
  );

  const updatedRow = await db.get('SELECT * FROM appointments WHERE id = ?', [appointmentId]);
  return toDomain(updatedRow);
};

export const getDoctorQueue = async (doctorId, dateString) => {
  const date = dateString || new Date().toISOString().slice(0, 10);
  const rows = await db.all(
    `SELECT * FROM appointments 
     WHERE doctor_id = ? AND scheduled_at LIKE ? || '%' AND status IN ('confirmed', 'checked_in', 'completed')
     ORDER BY queue_number ASC, scheduled_at ASC`,
    [doctorId, date],
  );

  const items = rows.map(toDomain);
  const checkedInList = items.filter((a) => a.status === 'checked_in');
  const completedList = items.filter((a) => a.status === 'completed');
  const currentServing = checkedInList.length > 0 ? checkedInList[0] : null;

  return {
    doctorId,
    date,
    totalScheduled: items.length,
    totalCheckedIn: checkedInList.length,
    totalCompleted: completedList.length,
    currentServingQueueNumber: currentServing?.queueNumber || null,
    currentServingPatient: currentServing ? currentServing.patientName : null,
    queue: items,
  };
};

export const getIntake = async (appointmentId) => {
  const row = await db.get('SELECT * FROM clinical_intakes WHERE appointment_id = ?', [appointmentId]);
  if (!row) return null;
  let symptomsList = [];
  try {
    symptomsList = JSON.parse(row.symptoms || '[]');
  } catch (_) {
    symptomsList = row.symptoms ? row.symptoms.split(', ') : [];
  }
  return {
    id: row.id,
    appointmentId: row.appointment_id,
    patientId: row.patient_id,
    chiefComplaint: row.chief_complaint,
    painLocation: row.pain_location,
    onsetDuration: row.onset_duration,
    painLevel: row.pain_level,
    symptoms: symptomsList,
    currentMedications: row.current_medications,
    medicalHistory: row.medical_history,
    knownAllergies: row.known_allergies,
    notes: row.notes,
    submittedAt: row.submitted_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};

export const saveIntake = async (appointmentId, patientId, data) => {
  const appt = await db.get('SELECT * FROM appointments WHERE id = ?', [appointmentId]);
  if (!appt) {
    throw new HttpError(404, 'Không tìm thấy lịch khám.');
  }

  const existing = await db.get('SELECT * FROM clinical_intakes WHERE appointment_id = ?', [appointmentId]);
  const now = new Date().toISOString();
  const id = existing ? existing.id : `intake-${appointmentId}`;
  const symptomsStr = Array.isArray(data.symptoms) ? JSON.stringify(data.symptoms) : (data.symptoms || '[]');

  if (existing) {
    await db.run(
      `UPDATE clinical_intakes SET
        chief_complaint = ?, pain_location = ?, onset_duration = ?, pain_level = ?,
        symptoms = ?, current_medications = ?, medical_history = ?, known_allergies = ?,
        notes = ?, updated_at = ?
      WHERE id = ?`,
      [
        data.chiefComplaint || data.chief_complaint || appt.reason,
        data.painLocation || data.pain_location || '',
        data.onsetDuration || data.onset_duration || '1-3 ngày trước',
        data.painLevel ?? data.pain_level ?? 5,
        symptomsStr,
        data.currentMedications || data.current_medications || '',
        data.medicalHistory || data.medical_history || '',
        data.knownAllergies || data.known_allergies || '',
        data.notes || '',
        now,
        id,
      ],
    );
  } else {
    await db.run(
      `INSERT INTO clinical_intakes (
        id, appointment_id, patient_id, chief_complaint, pain_location, onset_duration,
        pain_level, symptoms, current_medications, medical_history, known_allergies,
        notes, submitted_at, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        appointmentId,
        patientId || appt.patient_id,
        data.chiefComplaint || data.chief_complaint || appt.reason,
        data.painLocation || data.pain_location || '',
        data.onsetDuration || data.onset_duration || '1-3 ngày trước',
        data.painLevel ?? data.pain_level ?? 5,
        symptomsStr,
        data.currentMedications || data.current_medications || '',
        data.medicalHistory || data.medical_history || '',
        data.knownAllergies || data.known_allergies || '',
        data.notes || '',
        now,
        now,
        now,
      ],
    );
  }

  await db.run('UPDATE appointments SET has_intake = 1, updated_at = ? WHERE id = ?', [now, appointmentId]);
  return getIntake(appointmentId);
};

export const resetForTest = async () => {
  await db.run('DELETE FROM appointments');
  await db.run('DELETE FROM idempotency_keys');
  try {
    await db.run('DELETE FROM clinical_intakes');
  } catch (_) {}
};
