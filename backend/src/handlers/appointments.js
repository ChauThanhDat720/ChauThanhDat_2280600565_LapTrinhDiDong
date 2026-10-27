import * as repository from '../repositories/sqlite_appointment_repository.js';
import {
  doctorIdFromEvent,
  patientIdFromEvent,
  requireDoctorRole,
  requirePatientRole,
} from '../utils/auth.js';
import { error, handle, json, parseJsonBody } from '../utils/http.js';
import { appointmentInput, ratingInput, statusInput } from '../utils/validation.js';

export const handler = async (event) =>
  handle(async () => {
    const method = event.requestContext?.http?.method ?? event.httpMethod;
    const path = event.path || '';
    const appointmentId = event.pathParameters?.id;
    const doctorIdParam = event.pathParameters?.doctorId;

    // 1. GET /doctors/{doctorId}/availability?date=YYYY-MM-DD
    if (doctorIdParam && path.includes('/availability')) {
      const date =
        event.queryStringParameters?.date ??
        new Date().toISOString().split('T')[0];
      return json(200, await repository.getDoctorAvailability(doctorIdParam, date));
    }

    // 1b. GET /doctors/{doctorId}/queue?date=YYYY-MM-DD
    if (doctorIdParam && path.includes('/queue')) {
      const date =
        event.queryStringParameters?.date ??
        new Date().toISOString().split('T')[0];
      return json(200, await repository.getDoctorQueue(doctorIdParam, date));
    }

    // 2. GET /doctors/me/appointments
    if (path.includes('/doctors/me/appointments')) {
      requireDoctorRole(event);
      const doctorId = doctorIdFromEvent(event);
      const date = event.queryStringParameters?.date;
      return json(200, { items: await repository.listByDoctor(doctorId, date) });
    }

    // 3. PATCH /appointments/{id}/status (Doctor updates status, diagnosis, prescription)
    if (method === 'PATCH' && (path.endsWith('/status') || event.pathParameters?.action === 'status')) {
      requireDoctorRole(event);
      const doctorId = doctorIdFromEvent(event);
      const { status, note, diagnosis, prescription, followUpDate } = statusInput(parseJsonBody(event));
      const updated = await repository.updateStatusByDoctor(
        doctorId,
        appointmentId,
        status,
        note,
        diagnosis,
        prescription,
        followUpDate,
      );
      return updated
        ? json(200, updated)
        : error(404, 'Không tìm thấy lịch khám hoặc bạn không có quyền cập nhật.');
    }

    // 3b. PATCH /appointments/{id}/rating (Patient rates completed appointment)
    if (method === 'PATCH' && (path.endsWith('/rating') || event.pathParameters?.action === 'rating')) {
      requirePatientRole(event);
      const patientId = patientIdFromEvent(event);
      const { rating, reviewNote } = ratingInput(parseJsonBody(event));
      const updated = await repository.rateAppointmentByPatient(
        patientId,
        appointmentId,
        rating,
        reviewNote,
      );
      return updated
        ? json(200, updated)
        : error(404, 'Không tìm thấy lịch khám hoặc bạn không có quyền đánh giá.');
    }

    // 4. PATCH /appointments/{id}/cancel (Patient cancels appointment)
    if (method === 'PATCH' && (path.endsWith('/cancel') || event.pathParameters?.action === 'cancel')) {
      requirePatientRole(event);
      const patientId = patientIdFromEvent(event);
      const body = parseJsonBody(event);
      const appointment = await repository.cancelForPatient(
        patientId,
        appointmentId,
        body?.reason,
      );
      return appointment
        ? json(200, appointment)
        : error(404, 'Không tìm thấy lịch khám.');
    }

    // 4b. POST or PATCH /appointments/{id}/checkin (Reception / Kiosk check-in)
    if ((method === 'POST' || method === 'PATCH') && (path.endsWith('/checkin') || event.pathParameters?.action === 'checkin')) {
      const body = parseJsonBody(event);
      const updated = await repository.checkinAppointment(appointmentId, {
        roomNumber: body?.roomNumber,
      });
      return updated
        ? json(200, updated)
        : error(404, 'Không tìm thấy lịch khám.');
    }

    // 4c. GET /appointments/{id}/intake & POST /appointments/{id}/intake (Pre-visit Clinical Intake)
    if (appointmentId && (path.endsWith('/intake') || event.pathParameters?.action === 'intake')) {
      if (method === 'GET') {
        const intake = await repository.getIntake(appointmentId);
        return intake ? json(200, intake) : error(404, 'Chưa có phiếu khai báo tiền khám cho ca này.');
      }
      if (method === 'POST' || method === 'PUT') {
        const body = parseJsonBody(event);
        const patientId = patientIdFromEvent(event) || body.patientId || 'anonymous';
        const saved = await repository.saveIntake(appointmentId, patientId, body);
        return json(200, saved);
      }
    }

    // 5. GET /appointments (Patient lists own or active family member's appointments)
    if (method === 'GET' && !appointmentId) {
      requirePatientRole(event);
      const basePatientId = patientIdFromEvent(event);
      const requestedId = event.queryStringParameters?.patientId;
      const patientId =
        requestedId &&
        basePatientId &&
        (requestedId === basePatientId || requestedId.startsWith(`${basePatientId}::`))
          ? requestedId
          : basePatientId;
      return json(200, { items: await repository.listByPatient(patientId) });
    }

    // 6. POST /appointments (Patient creates appointment for self or family member)
    if (method === 'POST' && !appointmentId) {
      requirePatientRole(event);
      const basePatientId = patientIdFromEvent(event);
      const body = parseJsonBody(event);
      const requestedId = body?.patientId;
      const patientId =
        requestedId &&
        basePatientId &&
        (requestedId === basePatientId || requestedId.startsWith(`${basePatientId}::`))
          ? requestedId
          : basePatientId;
      const idempotencyKey =
        event.headers?.['idempotency-key'] ||
        event.headers?.['Idempotency-Key'] ||
        body?.idempotencyKey;
      return json(
        201,
        await repository.create(patientId, appointmentInput(body), idempotencyKey),
      );
    }

    // 6b. GET /appointments/{id}/medical-record
    if (method === 'GET' && appointmentId && (path.endsWith('/medical-record') || event.pathParameters?.action === 'medical-record')) {
      const record = await repository.getMedicalRecord(appointmentId);
      return record
        ? json(200, record)
        : error(404, 'Không tìm thấy hồ sơ bệnh án hoặc ca khám chưa hoàn tất.');
    }

    // 7. GET /appointments/{id} (Patient gets appointment detail)
    if (method === 'GET' && appointmentId) {
      requirePatientRole(event);
      const patientId = patientIdFromEvent(event);
      const appointment = await repository.getForPatient(patientId, appointmentId);
      return appointment
        ? json(200, appointment)
        : error(404, 'Không tìm thấy lịch khám.');
    }

    return error(405, 'Phương thức không được hỗ trợ.');
  });
