import { createHash, randomUUID } from 'node:crypto';
import { HttpError, requireRole, text } from './http.js';
import { WriteConflict } from './store.js';
import { doctors } from './catalog.js';
import { assistantReply } from './assistant.js';

const DAY = 86400000;
const vnDate = (value) => new Date(Date.parse(value) + 7 * 3600000).toISOString().slice(0, 10);
const item = (pk, sk, data, old, indexes = {}) => ({ pk, sk, data, version: (old?.version ?? 0) + 1, ...indexes });
const put = (next, old) => ({ put: next, expected: old?.version ?? null });
const missing = () => { throw new HttpError(404, 'Không tìm thấy dữ liệu hoặc bạn không có quyền truy cập.'); };
const conflict = () => { throw new HttpError(409, 'Dữ liệu vừa thay đổi hoặc khung giờ đã được đặt. Vui lòng tải lại.'); };
const iso = () => new Date().toISOString();
const dateOnly = (value) => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value ?? '') || Number.isNaN(Date.parse(value)) || new Date(value).toISOString().slice(0, 10) !== value) {
    throw new HttpError(400, 'Ngày không hợp lệ. Dùng định dạng YYYY-MM-DD.');
  }
  return value;
};
const transitions = { pending: ['confirmed', 'cancelled'], confirmed: ['checked_in', 'completed', 'cancelled'], checked_in: ['completed', 'cancelled'], completed: [], cancelled: [] };

export class HospitalService {
  constructor(store, attachments) { this.store = store; this.attachments = attachments; }
  async update(pk, sk, change) {
    for (let retry = 0; retry < 4; retry++) {
      const old = await this.store.get(pk, sk);
      const { data, extra = [], indexes = {} } = await change(old?.data, old);
      const next = item(pk, sk, data, old, indexes);
      try {
        await this.store.transact([put(next, old), ...extra]);
        return data;
      } catch (error) { if (!(error instanceof WriteConflict)) throw error; }
    }
    return conflict();
  }
  async profile(actor, method, body) {
    requireRole(actor, 'patients');
    if (method === 'GET') return (await this.store.get(`USER#${actor.sub}`, 'PROFILE'))?.data ?? missing();
    return this.update(`USER#${actor.sub}`, 'PROFILE', (current) => {
      if (method === 'POST' && current) throw new HttpError(409, 'Hồ sơ đã tồn tại.');
      if (method === 'PATCH' && !current) return missing();
      const dob = dateOnly(body.dateOfBirth);
      if (dob > iso().slice(0, 10)) throw new HttpError(400, 'Ngày sinh không hợp lệ.');
      return { data: {
        patientId: current?.patientId ?? `BN-${randomUUID()}`, cognitoUserId: actor.sub,
        name: text(body.name, 'Họ tên', 120), email: actor.email,
        phone: text(body.phone, 'Số điện thoại', 30), dateOfBirth: dob,
        gender: text(body.gender, 'Giới tính', 30), address: text(body.address, 'Địa chỉ', 300),
        emergencyContactName: text(body.emergencyContactName ?? '', 'Người liên hệ', 120, false),
        emergencyContactPhone: text(body.emergencyContactPhone ?? '', 'Số điện thoại liên hệ', 30, false),
        createdAt: current?.createdAt ?? iso(), updatedAt: iso(),
      } };
    });
  }
  appointmentIndexes(a) {
    const key = `APPOINTMENT#${vnDate(a.scheduledAt)}#${a.scheduledAt}#${a.id}`;
    return { gsi1pk: `PATIENT#${a.patientId}`, gsi1sk: key, gsi2pk: `DOCTOR#${a.doctorId}`, gsi2sk: key };
  }
  async appointment(actor, id) {
    const result = (await this.store.get(`APPOINTMENT#${id}`, 'DETAIL'))?.data ?? missing();
    this.requireAppointmentAccess(actor, result);
    return result;
  }
  requireAppointmentAccess(actor, appointment) {
    const patient = actor.roles.includes('patients') && appointment.patientId === actor.sub;
    const doctor = actor.roles.includes('doctors') && appointment.doctorId === actor.doctorId;
    if (!patient && !doctor) return missing();
    return doctor ? 'doctor' : 'patient';
  }
  async listAppointments(actor, doctorView, date) {
    requireRole(actor, doctorView ? 'doctors' : 'patients');
    if (date) dateOnly(date);
    const index = doctorView ? 'gsi2' : 'gsi1';
    const owner = doctorView ? `DOCTOR#${actor.doctorId}` : `PATIENT#${actor.sub}`;
    return (await this.store.query(owner, `APPOINTMENT#${date ?? ''}`, index)).map((x) => x.data);
  }
  async availability(doctorId, date) {
    if (!doctors.some((d) => d.id === doctorId)) return missing();
    dateOnly(date);
    const occupied = await this.store.query(`SLOTS#${doctorId}#${date}`);
    const slots = [];
    for (const hour of [8, 9, 10, 11, 13, 14, 15, 16]) {
      for (const minute of [0, 30]) {
        const time = `${String(hour).padStart(2, '0')}:${minute === 0 ? '00' : '30'}`;
        const start = Date.parse(`${date}T${time}:00+07:00`);
        slots.push({ time, startTime: new Date(start).toISOString(), endTime: new Date(start + 1800000).toISOString(),
          isAvailable: start > Date.now() && !occupied.some((x) => x.sk === time),
          unavailableReason: start <= Date.now() ? 'Đã qua giờ khám' : occupied.some((x) => x.sk === time) ? 'Đã có người đặt' : null });
      }
    }
    return { items: slots, slots };
  }
  async createAppointment(actor, body, idempotencyKey) {
    requireRole(actor, 'patients');
    const doctor = doctors.find((d) => d.id === body.doctorId) ?? missing();
    const raw = body.startTime ?? body.scheduledAt;
    if (typeof raw !== 'string' || Number.isNaN(Date.parse(raw))) throw new HttpError(400, 'Thời điểm khám không hợp lệ.');
    const scheduledAt = new Date(raw).toISOString();
    const date = vnDate(scheduledAt);
    const slot = (await this.availability(doctor.id, date)).items.find((s) => s.startTime === scheduledAt);
    if (!slot || Date.parse(scheduledAt) <= Date.now()) throw new HttpError(400, 'Khung giờ không hợp lệ hoặc đã qua.');
    const reason = text(body.reason, 'Lý do khám', 500);
    const parentId = body.parentAppointmentId ?? body.parent_appointment_id;
    if (parentId) {
      const parent = await this.appointment(actor, parentId);
      if (parent.patientId !== actor.sub || parent.status !== 'completed') throw new HttpError(400, 'Lịch khám gốc chưa hoàn thành.');
    }
    const fingerprint = createHash('sha256').update(JSON.stringify([doctor.id, scheduledAt, reason, parentId ?? null])).digest('hex');
    const requestKey = idempotencyKey ? createHash('sha256').update(text(idempotencyKey, 'Mã yêu cầu', 200)).digest('hex') : null;
    const lookup = requestKey ? { pk: `USER#${actor.sub}`, sk: `REQUEST#${requestKey}` } : null;
    const replay = async () => {
      const prior = lookup && await this.store.get(lookup.pk, lookup.sk);
      if (!prior) return null;
      if (prior.data.fingerprint !== fingerprint) throw new HttpError(409, 'Mã yêu cầu đã dùng với nội dung khác.');
      return this.appointment(actor, prior.data.appointmentId);
    };
    const previous = await replay();
    if (previous) return previous;
    const profile = (await this.store.get(`USER#${actor.sub}`, 'PROFILE'))?.data;
    const now = iso();
    const a = { id: randomUUID(), patientId: actor.sub, patientName: profile?.name || actor.name || 'Bệnh nhân',
      doctorId: doctor.id, doctorName: doctor.name, department: doctor.department, departmentId: doctor.departmentId,
      specialty: doctor.specialty, scheduledAt, startTime: scheduledAt, endTime: slot.endTime, time: slot.time,
      reason, status: 'pending', createdAt: now, updatedAt: now, hasIntake: false,
      isFollowUp: !!parentId, parentAppointmentId: parentId ?? null };
    const operations = [
      put(item(`APPOINTMENT#${a.id}`, 'DETAIL', a, null, this.appointmentIndexes(a))),
      put(item(`SLOTS#${doctor.id}#${date}`, slot.time, { appointmentId: a.id })),
    ];
    if (lookup) operations.push(put(item(lookup.pk, lookup.sk, { fingerprint, appointmentId: a.id })));
    try { await this.store.transact(operations); }
    catch (error) {
      if (!(error instanceof WriteConflict)) throw error;
      const created = await replay();
      if (created) return created;
      return conflict();
    }
    return a;
  }
  async changeAppointment(actor, id, action, body, method = 'PATCH') {
    return this.update(`APPOINTMENT#${id}`, 'DETAIL', async (a) => {
      if (!a) return missing();
      const caller = this.requireAppointmentAccess(actor, a);
      const next = { ...a, updatedAt: iso() };
      const extra = [];
      if (action === 'status') {
        requireRole(actor, 'doctors');
        if (caller !== 'doctor') return missing();
        const status = String(body.status ?? '').replace('checkedIn', 'checked_in').toLowerCase();
        if (!transitions[a.status]?.includes(status)) throw new HttpError(400, 'Không thể chuyển trạng thái lịch khám.');
        // Queue numbers are allocated through checkin, not an unchecked status patch.
        if (status === 'checked_in') throw new HttpError(400, 'Dùng chức năng tiếp nhận để cấp số thứ tự.');
        next.status = status;
        if (body.note != null) next.statusNote = text(body.note, 'Ghi chú', 500, false);
        if (body.diagnosis != null) next.diagnosis = text(body.diagnosis, 'Chẩn đoán', 2000, false);
        if (body.prescription != null) next.prescription = text(body.prescription, 'Đơn thuốc', 4000, false);
        if (body.followUpDate != null) {
          if (Number.isNaN(Date.parse(body.followUpDate))) throw new HttpError(400, 'Ngày tái khám không hợp lệ.');
          next.followUpDate = new Date(body.followUpDate).toISOString();
        }
        if (status === 'completed') next.completedAt = iso();
      } else if (action === 'cancel') {
        requireRole(actor, 'patients');
        if (a.patientId !== actor.sub) return missing();
        if (!['pending', 'confirmed'].includes(a.status)) throw new HttpError(400, 'Không thể hủy lịch khám này.');
        next.status = 'cancelled'; next.cancelledAt = iso();
        next.cancellationReason = text(body.reason ?? '', 'Lý do hủy', 500, false);
      } else if (action === 'rating') {
        requireRole(actor, 'patients');
        if (a.patientId !== actor.sub) return missing();
        if (a.status !== 'completed' || !Number.isInteger(body.rating) || body.rating < 1 || body.rating > 5) throw new HttpError(400, 'Chỉ đánh giá lịch đã khám, từ 1 đến 5 sao.');
        next.rating = body.rating; next.reviewNote = text(body.reviewNote ?? '', 'Đánh giá', 500, false); next.reviewedAt = iso();
      } else if (action === 'checkin') {
        if (a.status === 'checked_in') return { data: a, indexes: this.appointmentIndexes(a) };
        if (a.status !== 'confirmed') throw new HttpError(400, 'Lịch khám chưa được xác nhận.');
        const pk = `QUEUE#${a.doctorId}#${vnDate(a.scheduledAt)}`;
        const count = await this.store.get(pk, 'COUNTER');
        next.queueNumber = (count?.data.value ?? 0) + 1;
        next.checkedInAt = iso(); next.status = 'checked_in';
        next.roomNumber = text(body.roomNumber ?? a.roomNumber ?? 'Quầy tiếp nhận', 'Phòng khám', 120);
        extra.push(put(item(pk, 'COUNTER', { value: next.queueNumber }, count), count));
      } else if (action === 'intake' && method === 'POST') {
        requireRole(actor, 'patients');
        if (a.patientId !== actor.sub || ['cancelled', 'completed'].includes(a.status)) throw new HttpError(400, 'Không thể gửi phiếu tiền khám cho lịch này.');
        const intake = { id: `intake-${a.id}`, appointmentId: a.id, patientId: actor.sub, submittedAt: iso() };
        for (const field of ['chiefComplaint', 'painLocation', 'onsetDuration', 'currentMedications', 'medicalHistory', 'knownAllergies', 'notes']) intake[field] = text(body[field] ?? '', field, 2000, field === 'chiefComplaint');
        if (!Number.isInteger(body.painLevel) || body.painLevel < 0 || body.painLevel > 10) throw new HttpError(400, 'Mức đau phải từ 0 đến 10.');
        intake.painLevel = body.painLevel;
        if (!Array.isArray(body.symptoms) || body.symptoms.length > 30) throw new HttpError(400, 'Triệu chứng không hợp lệ.');
        intake.symptoms = body.symptoms.map((v) => text(v, 'Triệu chứng', 150));
        next.intake = intake; next.hasIntake = true;
      } else throw new HttpError(405, 'Thao tác không được hỗ trợ.');
      if (next.status === 'cancelled') {
        const pk = `SLOTS#${a.doctorId}#${vnDate(a.scheduledAt)}`;
        const lock = await this.store.get(pk, a.time);
        if (lock?.data.appointmentId === a.id) extra.push({ remove: { pk, sk: a.time }, expected: lock.version });
      }
      return { data: next, extra, indexes: this.appointmentIndexes(next) };
    });
  }
  async family(actor, method, id, action, body) {
    requireRole(actor, 'patients');
    const pk = `USER#${actor.sub}`;
    const existing = await this.store.get(pk, 'FAMILY');
    if (method === 'GET' && existing) {
      return id ? existing.data.find((m) => m.id === id) ?? missing() : { items: existing.data };
    }
    let result;
    await this.update(pk, 'FAMILY', (saved) => {
      const members = saved ? structuredClone(saved) : [{ id: randomUUID(), primary_patient_id: actor.sub,
        full_name: actor.name || 'Bản thân', relationship: 'self', gender: 'Khác', is_default: 1, created_at: iso() }];
      if (method === 'GET') { result = id ? members.find((m) => m.id === id) ?? missing() : { items: members }; }
      else if (method === 'POST') {
        if (members.length >= 20) throw new HttpError(400, 'Tối đa 20 hồ sơ gia đình.');
        const member = this.familyInput(body, actor);
        if (member.relationship === 'self') throw new HttpError(400, 'Đã có hồ sơ bản thân.');
        result = { ...member, id: randomUUID(), is_default: 0, created_at: iso(), updated_at: iso() };
        members.push(result);
      } else {
        const index = members.findIndex((m) => m.id === id);
        if (index < 0) return missing();
        if (method === 'PATCH' && action === 'default') {
          members.forEach((m) => { m.is_default = m.id === id ? 1 : 0; }); result = members[index];
        } else if (method === 'PATCH') {
          const member = this.familyInput(body, actor);
          if ((members[index].relationship === 'self') !== (member.relationship === 'self')) throw new HttpError(400, 'Không thể thay đổi loại hồ sơ bản thân.');
          members[index] = { ...members[index], ...member, updated_at: iso() }; result = members[index];
        } else if (method === 'DELETE') {
          if (members[index].relationship === 'self') throw new HttpError(400, 'Không thể xóa hồ sơ bản thân.');
          const [removed] = members.splice(index, 1);
          if (removed.is_default && members.length) members.find((m) => m.relationship === 'self').is_default = 1;
          result = { success: true };
        } else throw new HttpError(405, 'Thao tác không được hỗ trợ.');
      }
      return { data: members };
    });
    return result;
  }
  familyInput(body, actor) {
    const relationship = text(body.relationship, 'Mối quan hệ', 20);
    if (!['self', 'father', 'mother', 'spouse', 'child', 'grandparent', 'other'].includes(relationship)) throw new HttpError(400, 'Mối quan hệ không hợp lệ.');
    const result = { primary_patient_id: actor.sub, full_name: text(body.full_name, 'Họ tên', 120), relationship,
      gender: text(body.gender ?? 'Khác', 'Giới tính', 20) };
    for (const field of ['phone', 'bhyt_code', 'identity_card', 'blood_type', 'medical_history']) result[field] = body[field] == null ? null : text(body[field], field, field === 'medical_history' ? 2000 : 100, false);
    result.date_of_birth = body.date_of_birth ? dateOnly(body.date_of_birth) : null;
    if (result.date_of_birth && result.date_of_birth > iso().slice(0, 10)) throw new HttpError(400, 'Ngày sinh không hợp lệ.');
    return result;
  }
  async sessionRecord(actor, id) {
    const record = await this.store.get(`SESSION#${id}`, 'DETAIL');
    if (!record) return missing();
    this.requireAppointmentAccess(actor, record.data);
    return record;
  }
  async sessionForAppointment(actor, appointmentId) {
    const a = await this.appointment(actor, appointmentId);
    if (a.status !== 'completed' || !a.completedAt) throw new HttpError(400, 'Chỉ mở tư vấn sau khi hoàn tất khám.');
    const id = `tc-${a.id}`;
    if (!await this.store.get(`SESSION#${id}`, 'DETAIL')) {
      const data = { id, appointmentId: a.id, patientId: a.patientId, patientName: a.patientName,
        doctorId: a.doctorId, doctorName: a.doctorName, department: a.department,
        diagnosis: a.diagnosis ?? '', prescription: a.prescription ?? '', status: 'active',
        expires_at: new Date(Date.parse(a.completedAt) + 7 * DAY).toISOString(),
        created_at: iso(), updated_at: iso(), unreadCount: 0, auto_reply_enabled: true };
      const indexes = { gsi1pk: `PATIENT#${a.patientId}`, gsi1sk: `SESSION#${a.completedAt}#${id}`,
        gsi2pk: `DOCTOR#${a.doctorId}`, gsi2sk: `SESSION#${a.completedAt}#${id}` };
      const welcome = this.message(id, 'system', 'system', 'Hệ thống Bệnh viện',
        'Chào bạn! Phiên hậu khám đã được mở. Trợ lý tự động hỗ trợ thông tin cơ bản; các quyết định điều trị cần bác sĩ đánh giá.');
      try { await this.store.transact([put(item(`SESSION#${id}`, 'DETAIL', data, null, indexes)), put(item(`SESSION#${id}`, 'MESSAGE#000000000000#0', welcome))]); }
      catch (error) { if (!(error instanceof WriteConflict)) throw error; }
    }
    return this.getSession(actor, id);
  }
  async getSession(actor, id) {
    const record = await this.sessionRecord(actor, id);
    const messages = (await this.store.query(record.pk, 'MESSAGE#')).map((x) => x.data);
    const data = record.data;
    return { ...data, messages: await Promise.all(messages.map(async (m) => ({ ...m,
      is_read: m.senderType === 'system' || (m.senderType === 'patient' ? m.created_at <= (data.doctorReadAt ?? '') : m.created_at <= (data.patientReadAt ?? '')),
      ...(m.imageKey ? { imageUrl: await this.attachments.download(m.imageKey) } : {}),
    }))) };
  }
  message(sessionId, senderType, senderId, senderName, message, imageKey) {
    return { id: randomUUID(), sessionId, senderType, senderId, senderName, message, created_at: iso(), ...(imageKey ? { imageKey } : {}) };
  }
  async sessionAction(actor, id, action, body) {
    let created;
    await this.update(`SESSION#${id}`, 'DETAIL', async (data, old) => {
      if (!data) return missing();
      const type = this.requireAppointmentAccess(actor, data);
      const next = { ...data, updated_at: iso() };
      const extra = [];
      if (action === 'read') {
        next[type === 'doctor' ? 'doctorReadAt' : 'patientReadAt'] = iso();
        if (type === 'doctor') next.unreadCount = 0;
      } else {
        if (data.status !== 'active' || Date.parse(data.expires_at) <= Date.now()) throw new HttpError(400, 'Phiên tư vấn đã kết thúc hoặc hết hạn.');
        if (action === 'close') {
          if (type !== 'doctor') throw new HttpError(403, 'Chỉ bác sĩ phụ trách có thể đóng phiên.');
          next.status = 'closed';
        } else if (action === 'settings') {
          if (type !== 'patient' || typeof body.auto_reply_enabled !== 'boolean') throw new HttpError(400, 'Cấu hình trợ lý không hợp lệ.');
          next.auto_reply_enabled = body.auto_reply_enabled;
        } else if (action === 'messages') {
          if (body.senderType && body.senderType !== type) throw new HttpError(403, 'Không thể gửi tin dưới vai trò khác.');
          if (body.imageUrl) throw new HttpError(400, 'Dùng API tải ảnh, sau đó gửi imageKey.');
          const message = text(body.message ?? '', 'Tin nhắn', 4000, !body.imageKey);
          if (body.imageKey && (typeof body.imageKey !== 'string' || !body.imageKey.startsWith(`consultations/${id}/${actor.sub}/`))) throw new HttpError(403, 'Ảnh không thuộc người gửi hoặc phiên tư vấn.');
          created = this.message(id, type, actor.sub, type === 'doctor' ? data.doctorName : data.patientName, message, body.imageKey);
          const order = String(old.version).padStart(12, '0');
          extra.push(put(item(old.pk, `MESSAGE#${order}#0`, created)));
          let last = created;
          if (type === 'patient' && data.auto_reply_enabled) {
            last = this.message(id, 'assistant', 'post-care-assistant', 'Trợ lý hậu khám tự động', assistantReply(data, message, !!body.imageKey));
            extra.push(put(item(old.pk, `MESSAGE#${order}#1`, last)));
          }
          next.lastMessage = last.message; next.lastMessageSender = last.senderName; next.lastMessageAt = last.created_at;
          next.unreadCount = type === 'patient' ? data.unreadCount + 1 : 0;
        } else throw new HttpError(405, 'Thao tác không được hỗ trợ.');
      }
      const indexes = { gsi1pk: old.gsi1pk, gsi1sk: old.gsi1sk, gsi2pk: old.gsi2pk, gsi2sk: old.gsi2sk };
      return { data: next, extra, indexes };
    });
    return created ?? this.getSession(actor, id);
  }
  async listSessions(actor, doctorView, requestedId) {
    requireRole(actor, doctorView ? 'doctors' : 'patients');
    const id = doctorView ? actor.doctorId : actor.sub;
    if (requestedId !== 'me' && requestedId !== id) return missing();
    return (await this.store.query(`${doctorView ? 'DOCTOR' : 'PATIENT'}#${id}`, 'SESSION#', doctorView ? 'gsi2' : 'gsi1')).map((x) => x.data);
  }
  async upload(actor, id, body) {
    const record = await this.sessionRecord(actor, id);
    if (record.data.status !== 'active' || Date.parse(record.data.expires_at) <= Date.now()) throw new HttpError(400, 'Phiên tư vấn đã kết thúc.');
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(body.contentType) || !Number.isInteger(body.size) || body.size <= 0 || body.size > 1048576) throw new HttpError(400, 'Chọn ảnh JPEG/PNG/WebP tối đa 1 MB.');
    return this.attachments.upload(`consultations/${id}/${actor.sub}/${randomUUID()}`, body.contentType, body.size);
  }
}
