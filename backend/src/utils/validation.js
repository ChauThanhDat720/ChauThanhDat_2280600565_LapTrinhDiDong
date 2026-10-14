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
    doctorId: requiredText(body.doctorId, 'Bác sĩ'),
    doctorName: requiredText(body.doctorName, 'Tên bác sĩ'),
    specialty: requiredText(body.specialty, 'Chuyên khoa'),
    department: requiredText(body.department, 'Khoa'),
    scheduledAt,
    time: requiredText(body.time, 'Khung giờ'),
    reason: requiredText(body.reason, 'Lý do khám').slice(0, 500),
  };
};

export const patientInput = (body) => { const dateOfBirth=requiredText(body.dateOfBirth, 'Ngày sinh').slice(0,20); if (Number.isNaN(Date.parse(dateOfBirth)) || Date.parse(dateOfBirth)>Date.now()) throw new HttpError(400,'Ngày sinh không hợp lệ.'); return { name:requiredText(body.name,'Họ tên').slice(0,120), phone:requiredText(body.phone,'Số điện thoại').slice(0,30), dateOfBirth, gender:requiredText(body.gender,'Giới tính').slice(0,30), address:requiredText(body.address,'Địa chỉ').slice(0,300), emergencyContactName:typeof body.emergencyContactName==='string'?body.emergencyContactName.slice(0,120):'', emergencyContactPhone:typeof body.emergencyContactPhone==='string'?body.emergencyContactPhone.slice(0,30):'' }; };
