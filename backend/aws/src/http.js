export class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
export const bodyOf = (event) => {
  try {
    const raw = event.isBase64Encoded ? Buffer.from(event.body ?? '', 'base64').toString('utf8') : event.body;
    if (Buffer.byteLength(raw ?? '') > 32768) throw new HttpError(413, 'Nội dung quá lớn. Dùng API tải ảnh để đính kèm.');
    const body = raw ? JSON.parse(raw) : {};
    if (!body || Array.isArray(body) || typeof body !== 'object') throw new Error();
    return body;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(400, 'Nội dung JSON không hợp lệ.');
  }
};
export const text = (value, label, max = 500, required = true) => {
  if (typeof value !== 'string' || (required && !value.trim()) || value.length > max) {
    throw new HttpError(400, `${label} không hợp lệ.`);
  }
  return value.trim();
};
export const actorOf = (event) => {
  // Only API Gateway's trusted authorizer context is accepted. Never decode a raw token here.
  const claims = event.requestContext?.authorizer?.claims;
  if (!claims?.sub) throw new HttpError(401, 'Yêu cầu đăng nhập.');
  if (process.env.COGNITO_APP_CLIENT_ID && claims.aud !== process.env.COGNITO_APP_CLIENT_ID) throw new HttpError(401, 'Token không thuộc ứng dụng này.');
  const raw = claims['cognito:groups'];
  const roles = Array.isArray(raw) ? raw : String(raw ?? '').replace(/[\[\]"]/g, '').split(',').map((v) => v.trim());
  if (!roles.some((r) => ['patients', 'doctors', 'admins'].includes(r))) throw new HttpError(403, 'Tài khoản chưa được cấp quyền.');
  return { sub: claims.sub, name: claims.name ?? '', email: claims.email ?? '', roles,
    doctorId: claims['custom:doctorId'] || claims.sub };
};
export const requireRole = (actor, role) => {
  if (!actor.roles.includes(role)) throw new HttpError(403, 'Tài khoản không có quyền thực hiện thao tác này.');
};
export const response = (statusCode, body) => ({ statusCode, headers: {
  'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store',
  'access-control-allow-origin': process.env.ALLOWED_ORIGIN || 'http://localhost:5173',
  'access-control-allow-headers': 'Content-Type,Authorization,Idempotency-Key',
  'access-control-allow-methods': 'GET,POST,PATCH,DELETE,OPTIONS',
}, body: JSON.stringify(body) });
