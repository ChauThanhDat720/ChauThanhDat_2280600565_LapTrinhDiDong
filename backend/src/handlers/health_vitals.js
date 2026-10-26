import { SqliteHealthVitalsRepository } from '../repositories/sqlite_health_vitals_repository.js';

const repo = new SqliteHealthVitalsRepository();

const jsonResponse = (statusCode, body) => ({
  statusCode,
  headers: {
    'content-type': 'application/json',
    'access-control-allow-origin': '*',
  },
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  const method = event.httpMethod || event.requestContext?.http?.method;
  const path = event.path || '';
  const query = event.queryStringParameters || {};
  const claims = event.requestContext?.authorizer?.claims || {};

  const patientId = event.pathParameters?.patientId || query.patientId || claims.sub || 'test-patient-sub-123';

  let body = {};
  if (event.body) {
    try {
      body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    } catch (_) {
      return jsonResponse(400, { message: 'Dữ liệu JSON không hợp lệ' });
    }
  }

  try {
    // 1. DELETE /vitals/:id
    if (path.startsWith('/vitals/') && method === 'DELETE') {
      const id = event.pathParameters?.id || path.split('/').pop();
      await repo.deleteVital(id);
      return jsonResponse(200, { message: 'Đã xóa bản ghi sinh hiệu', success: true });
    }

    // 2. GET /patients/:id/vitals/latest
    if (path.endsWith('/latest') && method === 'GET') {
      await repo.seedDefaultVitals(patientId);
      const latest = await repo.getLatestVitals(patientId);
      return jsonResponse(200, { latest });
    }

    // 3. GET /patients/:id/vitals (History & Summary)
    if (method === 'GET') {
      const days = query.days ? Number(query.days) : 30;
      const limit = query.limit ? Number(query.limit) : 30;

      await repo.seedDefaultVitals(patientId);
      const history = await repo.getVitalsHistory(patientId, { days, limit });
      const summary = await repo.getVitalsSummary(patientId);

      return jsonResponse(200, { history, summary });
    }

    // 4. POST /patients/:id/vitals (New Vital Entry)
    if (method === 'POST') {
      if (!body.systolic || !body.diastolic) {
        return jsonResponse(400, { message: 'Huyết áp tâm thu và tâm trương là bắt buộc' });
      }

      const recorded = await repo.recordVitals({
        ...body,
        patientId,
      });

      return jsonResponse(201, {
        message: 'Đã ghi nhận chỉ số sinh hiệu thành công',
        vital: recorded,
      });
    }

    return jsonResponse(405, { message: 'Phương thức không được hỗ trợ' });
  } catch (err) {
    console.error('Lỗi Health Vitals Handler:', err);
    return jsonResponse(500, { message: 'Lỗi xử lý sinh hiệu', error: err.message });
  }
};
