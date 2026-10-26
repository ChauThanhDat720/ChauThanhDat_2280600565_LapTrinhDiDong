import * as repository from '../repositories/sqlite_teleconsultation_repository.js';
import { patientIdFromEvent } from '../utils/auth.js';
import { error, handle, json, parseJsonBody } from '../utils/http.js';

export const handler = async (event) =>
  handle(async () => {
    const method = event.requestContext?.http?.method ?? event.httpMethod;
    const path = event.path || '';
    const params = event.pathParameters || {};
    const claims = event.requestContext?.authorizer?.claims || {};
    const isDoctor = claims['cognito:groups'] === 'doctors' || Boolean(claims.doctorId);
    const callerInfo = {
      isDoctor,
      role: isDoctor ? 'doctors' : 'patients',
      userId: claims.sub || claims.doctorId || patientIdFromEvent(event) || 'anonymous',
    };

    // 1. GET /teleconsultations/appointment/:appointmentId
    if (method === 'GET' && params.appointmentId) {
      try {
        const session = await repository.getOrCreateSessionForAppointment(
          params.appointmentId,
          callerInfo,
        );
        return json(200, session);
      } catch (err) {
        return error(400, err.message);
      }
    }

    // 2. GET /teleconsultations/doctor/:doctorId
    if (method === 'GET' && (params.doctorId || path.includes('/doctor/'))) {
      const doctorId = params.doctorId || path.split('/doctor/')[1];
      const sessions = await repository.listSessionsForDoctor(doctorId);
      return json(200, { items: sessions });
    }

    // 3. GET /teleconsultations/patient/:patientId
    if (method === 'GET' && (params.patientId || path.includes('/patient/'))) {
      const patientId = params.patientId || path.split('/patient/')[1];
      const sessions = await repository.listSessionsForPatient(patientId);
      return json(200, { items: sessions });
    }

    // 4. POST /teleconsultations/sessions/:id/messages
    if (method === 'POST' && params.id && params.action === 'messages') {
      const body = parseJsonBody(event);
      try {
        const senderType = body.senderType || (isDoctor ? 'doctor' : 'patient');
        const senderId = body.senderId || callerInfo.userId;
        const senderName = body.senderName || (senderType === 'doctor' ? 'Bác sĩ' : 'Bệnh nhân');
        const createdMessage = await repository.addMessage(params.id, {
          senderType,
          senderId,
          senderName,
          message: body.message,
          imageUrl: body.imageUrl,
        });
        return json(201, createdMessage);
      } catch (err) {
        return error(400, err.message);
      }
    }

    // 5. PATCH /teleconsultations/sessions/:id/close
    if (method === 'PATCH' && params.id && params.action === 'close') {
      const body = parseJsonBody(event);
      try {
        const doctorName = body.closedByName || claims.name || 'Bác sĩ phụ trách';
        const updated = await repository.closeSession(params.id, doctorName);
        return json(200, updated);
      } catch (err) {
        return error(400, err.message);
      }
    }

    // 6. POST /teleconsultations/sessions/:id/read
    if (method === 'POST' && params.id && params.action === 'read') {
      const readerType = isDoctor ? 'doctor' : 'patient';
      await repository.markMessagesAsRead(params.id, readerType);
      return json(200, { success: true });
    }

    // 7. GET /teleconsultations/sessions/:id
    if (method === 'GET' && params.id) {
      const session = await repository.getSessionById(params.id, callerInfo);
      return session ? json(200, session) : error(404, 'Không tìm thấy phiên tư vấn.');
    }

    return error(404, 'Không tìm thấy API tư vấn y tế hậu khám.');
  });
