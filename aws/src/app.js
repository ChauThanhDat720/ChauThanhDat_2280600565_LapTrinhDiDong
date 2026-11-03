import { actorOf, bodyOf, HttpError, response } from './http.js';
import { departments, doctors } from './catalog.js';

export const createHandler = (service) => async (event) => {
  const method = event.httpMethod ?? event.requestContext?.http?.method;
  const path = event.path ?? event.rawPath ?? '/';
  try {
    if (method === 'OPTIONS') return response(204, {});
    if (method === 'GET' && path === '/health') return response(200, { status: 'ok', service: 'smart-hospital-api', storage: 'dynamodb' });
    if (method === 'GET' && path === '/departments') return response(200, { items: departments });
    if (method === 'GET' && path === '/doctors') return response(200, { items: doctors });
    const parts = path.split('/').filter(Boolean).map(decodeURIComponent);
    if (method === 'GET' && parts[0] === 'doctors' && parts.length === 2 && parts[1] !== 'me') {
      const doctor = doctors.find((d) => d.id === parts[1]);
      return doctor ? response(200, doctor) : response(404, { message: 'Không tìm thấy bác sĩ.' });
    }
    const actor = actorOf(event);
    const body = ['POST', 'PATCH'].includes(method) ? bodyOf(event) : {};
    const query = event.queryStringParameters ?? {};
    if (path === '/patients/me' && ['GET', 'POST', 'PATCH'].includes(method)) return response(200, await service.profile(actor, method, body));
    if (parts[0] === 'doctors' && parts[2] === 'availability' && parts.length === 3 && method === 'GET') return response(200, await service.availability(parts[1], query.date));
    if (path === '/doctors/me/appointments' && method === 'GET') return response(200, { items: await service.listAppointments(actor, true, query.date) });
    if (parts[0] === 'doctors' && parts[2] === 'queue' && parts.length === 3 && method === 'GET') {
      const slots = await service.store.query(`QUEUE#${parts[1]}#${query.date}`, 'COUNTER');
      // No names, diagnoses, or identifiers from other patients are exposed.
      return response(200, { doctorId: parts[1], date: query.date, totalCheckedIn: slots[0]?.data.value ?? 0 });
    }
    if (path === '/appointments') {
      if (method === 'GET') return response(200, { items: await service.listAppointments(actor, false) });
      if (method === 'POST') return response(201, await service.createAppointment(actor, body, event.headers?.['Idempotency-Key'] ?? event.headers?.['idempotency-key']));
    }
    if (parts[0] === 'appointments' && parts[1] && parts.length <= 3) {
      const [_, id, action] = parts;
      if (method === 'GET') {
        const appointment = await service.appointment(actor, id);
        if (!action) { const { intake, ...publicAppointment } = appointment; return response(200, publicAppointment); }
        if (action === 'intake') return appointment.intake ? response(200, appointment.intake) : response(404, { message: 'Chưa có phiếu tiền khám.' });
        if (action === 'medical-record' && appointment.status === 'completed') return response(200, {
          appointmentId: id, patientName: appointment.patientName, doctorName: appointment.doctorName,
          diagnosis: appointment.diagnosis, prescription: appointment.prescription, completedAt: appointment.completedAt,
        });
      } else if ((method === 'PATCH' && ['status', 'cancel', 'rating', 'checkin'].includes(action)) ||
          (method === 'POST' && ['checkin', 'intake'].includes(action))) {
        const updated = await service.changeAppointment(actor, id, action, body, method);
        if (action === 'intake') return response(200, updated.intake);
        const { intake, ...appointment } = updated;
        return response(200, appointment);
      }
    }
    if (parts[0] === 'family' && parts[1] === 'members' && parts.length <= 4 && ['GET', 'POST', 'PATCH', 'DELETE'].includes(method)) {
      if ((method === 'POST' && parts.length !== 2) || (parts[3] && parts[3] !== 'default')) throw new HttpError(405, 'Thao tác không được hỗ trợ.');
      return response(method === 'POST' ? 201 : 200, await service.family(actor, method, parts[2], parts[3], body));
    }
    if (parts[0] === 'teleconsultations' && parts.length >= 3) {
      const [_, category, id, action] = parts;
      if (method === 'GET' && category === 'appointment' && parts.length === 3) return response(200, await service.sessionForAppointment(actor, id));
      if (method === 'GET' && ['patient', 'doctor'].includes(category) && parts.length === 3) return response(200, { items: await service.listSessions(actor, category === 'doctor', id) });
      if (category === 'sessions') {
        if (method === 'GET' && parts.length === 3) return response(200, await service.getSession(actor, id));
        if (method === 'PATCH' && !action) return response(200, await service.sessionAction(actor, id, 'settings', body));
        if (method === 'POST' && action === 'attachments') return response(200, await service.upload(actor, id, body));
        if ((method === 'POST' && ['messages', 'read'].includes(action)) || (method === 'PATCH' && action === 'close')) return response(action === 'messages' ? 201 : 200, await service.sessionAction(actor, id, action, body));
      }
    }
    return response(404, { message: 'API này chưa được hỗ trợ trên AWS.' });
  } catch (error) {
    if (error instanceof HttpError) return response(error.status, { message: error.message });
    // Do not log request bodies, JWTs, medical data, or signed URLs.
    console.error('Request failed', { name: error.name });
    return response(500, { message: 'Không thể xử lý yêu cầu. Vui lòng thử lại.' });
  }
};
