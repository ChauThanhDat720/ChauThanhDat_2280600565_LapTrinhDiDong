import * as repository from '../repositories/sqlite_vaccination_repository.js';
import { patientIdFromEvent } from '../utils/auth.js';
import { error, handle, json, parseJsonBody } from '../utils/http.js';

export const handler = async (event) =>
  handle(async () => {
    const method = event.requestContext?.http?.method ?? event.httpMethod;
    const path = event.path || '';
    const id = event.pathParameters?.id;
    const code = event.pathParameters?.code;
    const query = event.queryStringParameters || {};
    let patientId = query.patientId;
    if (!patientId) {
      try {
        patientId = patientIdFromEvent(event);
      } catch (_) {
        patientId = 'test-patient-sub-123';
      }
    }

    // 1. GET /vaccinations/protocols
    if (method === 'GET' && (path.endsWith('/protocols') || id === 'protocols')) {
      return json(200, {
        protocols: repository.getVaccineProtocols(),
      });
    }

    // 2. GET /vaccinations/upcoming
    if (method === 'GET' && (path.endsWith('/upcoming') || id === 'upcoming')) {
      const upcoming = await repository.getUpcomingDoses(patientId);
      return json(200, { upcoming });
    }

    // 3. GET /vaccinations/passport/:code
    if (method === 'GET' && (path.includes('/passport/') || code)) {
      const certCode = code || path.split('/passport/')[1];
      const record = await repository.getVaccinationByCertificateCode(certCode);
      if (!record) {
        return error(404, 'Không tìm thấy chứng nhận tiêm chủng điện tử hợp lệ.');
      }
      return json(200, {
        valid: true,
        certificate: record,
        issuedBy: 'Bệnh viện Đa khoa Quốc tế Smart Hospital',
        verifiedAt: new Date().toISOString(),
      });
    }

    // 4. GET /vaccinations/:id
    if (method === 'GET' && id && id !== 'protocols' && id !== 'upcoming') {
      const record = await repository.getVaccinationById(id);
      if (!record) {
        return error(404, 'Không tìm thấy thông tin mũi tiêm.');
      }
      return json(200, record);
    }

    // 5. POST /vaccinations
    if (method === 'POST') {
      const body = parseJsonBody(event);
      if (!body.vaccineName) {
        return error(400, 'Tên vắc-xin không được để trống.');
      }
      const record = await repository.createVaccination({
        ...body,
        patientId: body.patientId || patientId,
      });
      return json(201, record);
    }

    // 6. GET /vaccinations
    if (method === 'GET') {
      const familyMemberId = query.familyMemberId;
      const list = await repository.getVaccinations({ patientId, familyMemberId });
      return json(200, {
        vaccinations: list,
        total: list.length,
      });
    }

    return error(404, 'Endpoint không tồn tại.');
  });
