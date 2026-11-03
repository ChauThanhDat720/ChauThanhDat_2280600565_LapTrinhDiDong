import { HttpError } from './http.js';

export const claimsFromEvent = (event) => {
  const claims = event.requestContext?.authorizer?.claims;
  if (!claims?.sub) throw new HttpError(401, 'Yêu cầu đăng nhập.');
  return claims;
};

export const patientIdFromEvent = (event) => {
  const claims = claimsFromEvent(event);
  return claims.sub;
};

export const doctorIdFromEvent = (event) => {
  const claims = claimsFromEvent(event);
  return claims.doctorId ?? claims.sub;
};

export const requirePatientRole = (event) => {
  const claims = claimsFromEvent(event);
  const groups = claims['cognito:groups'] ?? '';
  const roles = String(groups).split(',').map((role) => role.trim());
  if (!roles.includes('patients')) {
    throw new HttpError(403, 'Tài khoản không có quyền truy cập hồ sơ bệnh nhân.');
  }
};

export const requireDoctorRole = (event) => {
  const claims = claimsFromEvent(event);
  const groups = claims['cognito:groups'] ?? '';
  const roles = String(groups).split(',').map((role) => role.trim());
  if (!roles.includes('doctors')) {
    throw new HttpError(403, 'Tài khoản không có quyền truy cập dành cho bác sĩ.');
  }
};
