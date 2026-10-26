import { randomUUID } from 'node:crypto';
import { HttpError } from '../utils/http.js';
import { validateStatusTransition } from '../utils/validation.js';

const appointments = new Map();
const idempotencyStore = new Map();

export const listByPatient = (patientId) =>
  [...appointments.values()]
    .filter((item) => item.patientId === patientId)
    .sort((left, right) => left.scheduledAt.localeCompare(right.scheduledAt));

export const listByDoctor = (doctorId, date) =>
  [...appointments.values()]
    .filter(
      (item) =>
        item.doctorId === doctorId &&
        (!date || item.scheduledAt.startsWith(date)),
    )
    .sort((left, right) => left.scheduledAt.localeCompare(right.scheduledAt));

export const getForPatient = (patientId, appointmentId) => {
  const item = appointments.get(appointmentId);
  return item?.patientId === patientId ? item : undefined;
};

export const getForDoctor = (doctorId, appointmentId) => {
  const item = appointments.get(appointmentId);
  return item?.doctorId === doctorId ? item : undefined;
};

export const create = (patientId, input, idempotencyKey) => {
  if (idempotencyKey) {
    const existingKey = `${patientId}#${idempotencyKey}`;
    const cached = idempotencyStore.get(existingKey);
    if (cached) return cached;
  }

  // DynamoDB TransactWriteItems simulation:
  // ConditionCheck on DoctorSlotItem: attribute_not_exists(PK)
  const conflict = [...appointments.values()].find(
    (item) =>
      item.doctorId === input.doctorId &&
      item.scheduledAt === input.scheduledAt &&
      (item.status === 'pending' || item.status === 'confirmed'),
  );

  if (conflict) {
    const error = new HttpError(409, 'Khung giờ này đã được đặt.');
    error.code = 'TransactionCanceledException';
    throw error;
  }

  const now = new Date().toISOString();
  const appointment = {
    id: randomUUID(),
    patientId,
    ...input,
    status: 'pending',
    createdAt: now,
    updatedAt: now,
  };

  appointments.set(appointment.id, appointment);

  if (idempotencyKey) {
    idempotencyStore.set(`${patientId}#${idempotencyKey}`, appointment);
  }

  return appointment;
};

export const cancelForPatient = (patientId, appointmentId, reason = '') => {
  const item = getForPatient(patientId, appointmentId);
  if (!item) return undefined;

  validateStatusTransition(item.status, 'cancelled');

  const updated = {
    ...item,
    status: 'cancelled',
    cancellationReason: reason || 'Bệnh nhân tự hủy qua ứng dụng',
    updatedAt: new Date().toISOString(),
  };
  appointments.set(appointmentId, updated);
  return updated;
};

export const updateStatusByDoctor = (
  doctorId,
  appointmentId,
  targetStatus,
  note = '',
  diagnosis,
  prescription,
) => {
  const item = appointments.get(appointmentId);
  if (!item || item.doctorId !== doctorId) return undefined;

  validateStatusTransition(item.status, targetStatus);

  const updated = {
    ...item,
    status: targetStatus,
    statusNote: note,
    diagnosis: diagnosis ?? item.diagnosis,
    prescription: prescription ?? item.prescription,
    updatedAt: new Date().toISOString(),
  };
  appointments.set(appointmentId, updated);
  return updated;
};

export const rateAppointmentByPatient = (
  patientId,
  appointmentId,
  rating,
  reviewNote = '',
) => {
  const item = appointments.get(appointmentId);
  if (!item || item.patientId !== patientId) return undefined;

  if (item.status !== 'completed') {
    throw new HttpError(400, 'Chỉ có thể đánh giá ca khám đã hoàn thành.');
  }

  const updated = {
    ...item,
    rating,
    reviewNote,
    reviewedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  appointments.set(appointmentId, updated);
  return updated;
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

export const getDoctorAvailability = (doctorId, dateString) => {
  const booked = new Set(
    [...appointments.values()]
      .filter(
        (item) =>
          item.doctorId === doctorId &&
          item.scheduledAt.startsWith(dateString) &&
          (item.status === 'pending' || item.status === 'confirmed'),
      )
      .map((item) => item.time),
  );

  const parsedDate = new Date(`${dateString}T00:00:00.000Z`);
  const isPastDate = Number.isNaN(parsedDate.getTime()) || Date.now() > parsedDate.getTime() + 86400000;

  const slots = STANDARD_SLOTS.map((slotTime) => {
    const isBooked = booked.has(slotTime);
    return {
      time: slotTime,
      isAvailable: !isBooked && !isPastDate,
      reason: isBooked ? 'Đã có lịch hẹn' : isPastDate ? 'Ngày trong quá khứ' : null,
    };
  });

  return {
    doctorId,
    date: dateString,
    slots,
  };
};

export const resetAppointments = () => {
  appointments.clear();
  idempotencyStore.clear();
};
