import * as repository from '../repositories/sqlite_family_repository.js';
import { patientIdFromEvent, requirePatientRole } from '../utils/auth.js';
import { error, handle, json, parseJsonBody } from '../utils/http.js';

export const handler = async (event) =>
  handle(async () => {
    const method = event.requestContext?.http?.method ?? event.httpMethod;
    const path = event.path || '';
    const memberId = event.pathParameters?.id;
    const isDefaultAction = event.pathParameters?.action === 'default' || path.endsWith('/default');

    requirePatientRole(event);
    const primaryPatientId = patientIdFromEvent(event) || 'test-patient-sub-123';

    // 1. PATCH /family/members/:id/default
    if (method === 'PATCH' && memberId && isDefaultAction) {
      const updated = await repository.setDefaultMember(primaryPatientId, memberId);
      return updated ? json(200, updated) : error(404, 'Không tìm thấy thành viên.');
    }

    // 2. GET /family/members/:id
    if (method === 'GET' && memberId) {
      const member = await repository.getMemberById(memberId);
      return member ? json(200, member) : error(404, 'Không tìm thấy thành viên.');
    }

    // 3. PATCH /family/members/:id
    if (method === 'PATCH' && memberId) {
      const body = parseJsonBody(event);
      const updated = await repository.updateMember(memberId, body);
      return updated ? json(200, updated) : error(404, 'Không tìm thấy thành viên.');
    }

    // 4. DELETE /family/members/:id
    if (method === 'DELETE' && memberId) {
      try {
        const deleted = await repository.deleteMember(memberId);
        return deleted ? json(200, { success: true, message: 'Đã xóa thành viên khỏi hồ sơ gia đình.' }) : error(404, 'Không tìm thấy thành viên.');
      } catch (err) {
        return error(400, err.message);
      }
    }

    // 5. GET /family/members
    if (method === 'GET') {
      const items = await repository.listMembers(primaryPatientId);
      return json(200, { items });
    }

    // 6. POST /family/members
    if (method === 'POST') {
      const body = parseJsonBody(event);
      if (!body.full_name || !body.relationship) {
        return error(400, 'Họ tên và mối quan hệ là bắt buộc.');
      }
      const created = await repository.createMember({
        ...body,
        primary_patient_id: primaryPatientId,
      });
      return json(201, created);
    }

    return error(405, 'Phương thức không được hỗ trợ.');
  });
