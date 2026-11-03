import { HttpError } from './http.js';

const requiredText = (value, field) => {
  if (typeof value !== 'string' || !value.trim()) {
    throw new HttpError(400, `${field} là bắt buộc.`);
  }
  return value.trim();
};

export const appointmentInput = (body) => {
  const scheduledAt = requiredText(body.scheduledAt, 'Thời điểm khám');
  if (Number.isNaN(Date.parse(scheduledAt))) {
    throw new HttpError(400, 'Thời điểm khám không hợp lệ.');
  }
  return {
    patientName:
      typeof body.patientName === 'string' && body.patientName.trim()
        ? body.patientName.trim().slice(0, 120)
        : undefined,
    doctorId: requiredText(body.doctorId, 'Bác sĩ'),
    doctorName: requiredText(body.doctorName, 'Tên bác sĩ'),
    specialty: requiredText(body.specialty, 'Chuyên khoa'),
    department: requiredText(body.department, 'Khoa'),
    scheduledAt,
    time: requiredText(body.time, 'Khung giờ'),
    reason: requiredText(body.reason, 'Lý do khám').slice(0, 500),
    isFollowUp: Boolean(body.isFollowUp || body.is_follow_up),
    parentAppointmentId:
      body.parentAppointmentId || body.parent_appointment_id || undefined,
  };
};

export const VALID_STATUS_TRANSITIONS = {
  pending: ['confirmed', 'cancelled'],
  confirmed: ['checked_in', 'completed', 'cancelled'],
  checked_in: ['completed', 'cancelled'],
  completed: [],
  cancelled: [],
};

export const validateStatusTransition = (currentStatus, targetStatus) => {
  const allowed = VALID_STATUS_TRANSITIONS[currentStatus] || [];
  if (!allowed.includes(targetStatus)) {
    throw new HttpError(
      400,
      `Không thể chuyển trạng thái từ ${currentStatus} sang ${targetStatus}.`,
    );
  }
  return targetStatus;
};

export const statusInput = (body) => {
  const status = requiredText(body.status, 'Trạng thái').toLowerCase();
  const validStatuses = ['pending', 'confirmed', 'checked_in', 'completed', 'cancelled'];
  if (!validStatuses.includes(status)) {
    throw new HttpError(400, 'Trạng thái không hợp lệ.');
  }
  return {
    status,
    note: typeof body.note === 'string' ? body.note.trim().slice(0, 500) : '',
    diagnosis: typeof body.diagnosis === 'string' ? body.diagnosis.trim().slice(0, 1000) : undefined,
    prescription: typeof body.prescription === 'string' ? body.prescription.trim().slice(0, 2000) : undefined,
    followUpDate:
      typeof body.followUpDate === 'string'
        ? body.followUpDate
        : typeof body.follow_up_date === 'string'
          ? body.follow_up_date
          : undefined,
  };
};

export const ratingInput = (body) => {
  const rating = Number(body?.rating);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    throw new HttpError(400, 'Điểm đánh giá phải là số nguyên từ 1 đến 5 sao.');
  }
  return {
    rating,
    reviewNote: typeof body?.reviewNote === 'string' ? body.reviewNote.trim().slice(0, 500) : '',
  };
};

export const patientInput = (body) => {
  const dateOfBirth = requiredText(body.dateOfBirth, 'Ngày sinh').slice(0, 20);
  if (Number.isNaN(Date.parse(dateOfBirth)) || Date.parse(dateOfBirth) > Date.now()) {
    throw new HttpError(400, 'Ngày sinh không hợp lệ.');
  }
  return {
    name: requiredText(body.name, 'Họ tên').slice(0, 120),
    phone: requiredText(body.phone, 'Số điện thoại').slice(0, 30),
    dateOfBirth,
    gender: requiredText(body.gender, 'Giới tính').slice(0, 30),
    address: requiredText(body.address, 'Địa chỉ').slice(0, 300),
    emergencyContactName:
      typeof body.emergencyContactName === 'string'
        ? body.emergencyContactName.slice(0, 120)
        : '',
    emergencyContactPhone:
      typeof body.emergencyContactPhone === 'string'
        ? body.emergencyContactPhone.slice(0, 30)
        : '',
  };
};
