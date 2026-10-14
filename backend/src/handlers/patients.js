import { getPatient, putPatient } from '../repositories/in_memory_patient_repository.js';
import { randomUUID } from 'node:crypto';
import { patientIdFromEvent, requirePatientRole } from '../utils/auth.js';
import { handle, json, parseJsonBody } from '../utils/http.js';
import { patientInput } from '../utils/validation.js';

export const handler = async (event) => handle(async () => {
  const patientId = patientIdFromEvent(event);
  requirePatientRole(event);
  const method = event.requestContext?.http?.method ?? event.httpMethod;
  if (method === 'GET') {
    const patient = getPatient(patientId);
    return patient ? json(200, patient) : json(404, { message: 'Bạn chưa hoàn thiện hồ sơ bệnh nhân.' });
  }
  if (method === 'POST' || method === 'PATCH') {
    const current = getPatient(patientId);
    if (method === 'POST' && current) return json(409, { message: 'Hồ sơ bệnh nhân đã tồn tại.' });
    if (method === 'PATCH' && !current) return json(404, { message: 'Bạn chưa hoàn thiện hồ sơ bệnh nhân.' });
    const now = new Date().toISOString();
    const profile = putPatient(patientId, { ...current, ...patientInput(parseJsonBody(event)), patientId: current?.patientId ?? `BN-${randomUUID().replaceAll('-', '').slice(0, 12).toUpperCase()}`, cognitoUserId: patientId, email: current?.email ?? event.requestContext.authorizer.claims.email ?? '', createdAt: current?.createdAt ?? now, updatedAt: now });
    return json(200, profile);
  }
  return json(405, { message: 'Phương thức không được hỗ trợ.' });
});
