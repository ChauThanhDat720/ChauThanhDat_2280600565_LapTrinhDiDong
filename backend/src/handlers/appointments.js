import * as repository from '../repositories/in_memory_appointment_repository.js';
import { patientIdFromEvent, requirePatientRole } from '../utils/auth.js';
import { error, handle, json, parseJsonBody } from '../utils/http.js';
import { appointmentInput } from '../utils/validation.js';

export const handler = async (event) => handle(async () => {
  requirePatientRole(event);
  const patientId = patientIdFromEvent(event);
  const method = event.requestContext?.http?.method ?? event.httpMethod;
  const appointmentId = event.pathParameters?.id;

  if (method === 'GET' && !appointmentId) {
    return json(200, { items: repository.listByPatient(patientId) });
  }
  if (method === 'POST') {
    return json(201, repository.create(patientId, appointmentInput(parseJsonBody(event))));
  }
  if (method === 'GET' && appointmentId) {
    const appointment = repository.getForPatient(patientId, appointmentId);
    return appointment ? json(200, appointment) : error(404, 'Không tìm thấy lịch khám.');
  }
  if (method === 'PATCH' && appointmentId) {
    const appointment = repository.cancelForPatient(patientId, appointmentId);
    return appointment ? json(200, appointment) : error(404, 'Không tìm thấy lịch khám.');
  }
  return error(405, 'Phương thức không được hỗ trợ.');
});
