import { HttpError } from './http.js';

export const patientIdFromEvent = (event) => {
  const claims = event.requestContext?.authorizer?.claims;
  const subject = claims?.sub;
  if (!subject) throw new HttpError(401, 'Yêu cầu đăng nhập.');
  return subject;
};

export const requirePatientRole = (event) => {
  const groups = event.requestContext?.authorizer?.claims?.['cognito:groups'] ?? '';
  const roles = String(groups).split(',').map((role) => role.trim());
  if (!roles.includes('patients')) {
    throw new HttpError(403, 'Tài khoản không có quyền truy cập hồ sơ bệnh nhân.');
  }
};
