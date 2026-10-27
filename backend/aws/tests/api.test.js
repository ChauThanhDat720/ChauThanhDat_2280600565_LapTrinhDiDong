import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from '../src/app.js';
import { HospitalService } from '../src/service.js';
import { MemoryStore } from './memory_store.js';

const patient = { sub: 'patient-a', name: 'Bệnh nhân A', email: 'a@example.com', 'cognito:groups': 'patients' };
const other = { ...patient, sub: 'patient-b' };
const doctor = { sub: 'doctor-sub', name: 'Bác sĩ', 'cognito:groups': ['doctors'], 'custom:doctorId': 'dr-linh' };
const otherDoctor = { ...doctor, sub: 'other-doctor', 'custom:doctorId': 'dr-duc' };
const futureDate = () => new Date(Date.now() + 10 * 86400000).toISOString().slice(0, 10);
const booking = () => ({ doctorId: 'dr-linh', startTime: `${futureDate()}T08:00:00+07:00`, reason: 'Tái khám' });
function fixture() {
  const store = new MemoryStore();
  const uploads = [];
  const attachments = { async upload(key, contentType, size) { uploads.push(key); return { objectKey: key, contentType, size, uploadUrl: 'https://example.s3.amazonaws.com/upload' }; }, async download(key) { return `https://example.s3.amazonaws.com/${key}?signed=1`; } };
  const service = new HospitalService(store, attachments);
  const handler = createHandler(service);
  const request = async (path, method = 'GET', body, claims = patient, headers = {}) => {
    const url = new URL(path, 'https://example.com');
    const result = await handler({ path: url.pathname, httpMethod: method, headers,
      body: typeof body === 'string' ? body : body ? JSON.stringify(body) : null,
      queryStringParameters: Object.fromEntries(url.searchParams),
      requestContext: { authorizer: claims ? { claims } : {} } });
    return { status: result.statusCode, data: JSON.parse(result.body) };
  };
  const completed = async () => {
    const { data: a } = await request('/appointments', 'POST', booking());
    assert.equal((await request(`/appointments/${a.id}/status`, 'PATCH', { status: 'confirmed' }, doctor)).status, 200);
    assert.equal((await request(`/appointments/${a.id}/status`, 'PATCH', { status: 'completed', diagnosis: 'Theo dõi', prescription: 'Đơn bác sĩ đã lưu' }, doctor)).status, 200);
    return (await request(`/appointments/${a.id}`)).data;
  };
  return { store, service, handler, request, completed, uploads };
}

test('public API works; raw bearer headers cannot bypass Gateway authorizer', async () => {
  const { request } = fixture();
  assert.equal((await request('/health', 'GET', null, null)).data.storage, 'dynamodb');
  assert.equal((await request('/doctors', 'GET', null, null)).data.items.length, 3);
  assert.equal((await request('/patients/me', 'GET', null, null, { Authorization: 'Bearer forged-patient' })).status, 401);
  assert.equal((await request('/patients/me', 'GET', null, { sub: 'u', 'cognito:groups': 'untrusted' })).status, 403);
});

test('profile identity is derived from Cognito and fields are persisted', async () => {
  const { request, store } = fixture();
  const body = { name: 'Nguyễn A', email: 'forged@example.com', phone: '0901234567', dateOfBirth: '1990-01-02', gender: 'Nam', address: 'TP.HCM', cognitoUserId: 'other-id' };
  assert.equal((await request('/patients/me')).status, 404);
  assert.equal((await request('/patients/me', 'POST', body)).data.cognitoUserId, patient.sub);
  assert.equal((await request('/patients/me')).data.email, patient.email);
  assert.equal((await request('/patients/me', 'GET', null, other)).status, 404);
  assert.equal((await store.get(`USER#${patient.sub}`, 'PROFILE')).data.name, 'Nguyễn A');
});

test('atomic booking prevents duplicate slots and honors scoped idempotency', async () => {
  const { request } = fixture();
  const [a, b] = await Promise.all([request('/appointments', 'POST', booking()), request('/appointments', 'POST', booking(), other)]);
  assert.deepEqual([a.status, b.status].sort(), [201, 409]);
  const second = { ...booking(), startTime: `${futureDate()}T08:30:00+07:00` };
  const one = await request('/appointments', 'POST', second, patient, { 'idempotency-key': 'same-key' });
  const two = await request('/appointments', 'POST', second, patient, { 'idempotency-key': 'same-key' });
  assert.equal(one.data.id, two.data.id);
  assert.equal((await request('/appointments', 'POST', { ...second, reason: 'Nội dung khác' }, patient, { 'idempotency-key': 'same-key' })).status, 409);
});

test('appointment reads, writes and clinical intake enforce ownership and role', async () => {
  const { request } = fixture();
  const a = (await request('/appointments', 'POST', booking())).data;
  assert.equal((await request(`/appointments/${a.id}`, 'GET', null, other)).status, 404);
  assert.equal((await request(`/appointments/${a.id}/status`, 'PATCH', { status: 'confirmed' }, otherDoctor)).status, 404);
  assert.equal((await request(`/appointments/${a.id}/status`, 'PATCH', { status: 'confirmed' })).status, 403);
  assert.equal((await request(`/appointments/${a.id}/intake`, 'POST', { chiefComplaint: 'Mệt', painLevel: 3, symptoms: [] })).status, 200);
  assert.equal((await request(`/appointments/${a.id}/intake`, 'GET', null, other)).status, 404);
  const updated = (await request(`/appointments/${a.id}/status`, 'PATCH', { status: 'confirmed', patientId: 'forged' }, doctor)).data;
  assert.equal(updated.patientId, patient.sub);
  assert.equal((await request(`/appointments/${a.id}/checkin`, 'POST', {})).data.queueNumber, 1);
  assert.equal((await request(`/appointments/${a.id}/checkin`, 'POST', {})).data.queueNumber, 1);
});

test('cancellation atomically frees the slot', async () => {
  const { request } = fixture();
  const a = (await request('/appointments', 'POST', booking())).data;
  assert.equal((await request(`/appointments/${a.id}/cancel`, 'PATCH', { reason: 'Bận' })).status, 200);
  assert.equal((await request('/appointments', 'POST', booking(), other)).status, 201);
});

test('family operations are isolated; protected self and defaults survive changes', async () => {
  const { request } = fixture();
  const self = (await request('/family/members')).data.items[0];
  const member = (await request('/family/members', 'POST', { full_name: 'Mẹ', relationship: 'mother', primary_patient_id: 'forged' })).data;
  assert.equal(member.primary_patient_id, patient.sub);
  assert.equal((await request(`/family/members/${member.id}`, 'GET', null, other)).status, 404);
  assert.equal((await request(`/family/members/${member.id}`, 'PATCH', { full_name: 'Bị sửa', relationship: 'mother' }, other)).status, 404);
  await request(`/family/members/${member.id}/default`, 'PATCH', {});
  const edited = await request(`/family/members/${member.id}`, 'PATCH', { full_name: 'Mẹ đã sửa', relationship: 'mother', phone: null });
  assert.equal(edited.data.full_name, 'Mẹ đã sửa');
  assert.equal(edited.data.phone, null);
  assert.equal((await request(`/family/members/${self.id}`, 'DELETE')).status, 400);
  await request(`/family/members/${member.id}`, 'DELETE');
  assert.equal((await request('/family/members')).data.items.find((x) => x.is_default).id, self.id);
});

test('consultation requires completed appointment and prevents patient/doctor impersonation', async () => {
  const { request, completed } = fixture();
  const a = await completed();
  const session = (await request(`/teleconsultations/appointment/${a.id}`)).data;
  assert.equal(Date.parse(session.expires_at) - Date.parse(a.completedAt), 7 * 86400000);
  assert.equal((await request(`/teleconsultations/sessions/${session.id}`, 'GET', null, other)).status, 404);
  assert.equal((await request(`/teleconsultations/sessions/${session.id}`, 'GET', null, otherDoctor)).status, 404);
  assert.equal((await request(`/teleconsultations/sessions/${session.id}/messages`, 'POST', { senderType: 'doctor', message: 'Giả mạo' })).status, 403);
  const sent = await request(`/teleconsultations/sessions/${session.id}/messages`, 'POST', { senderId: 'forged', senderName: 'Giả tên', message: 'Em quên uống thuốc' });
  assert.equal(sent.data.senderId, patient.sub);
  const conversation = (await request(`/teleconsultations/sessions/${session.id}`)).data;
  assert.equal(conversation.messages.length, 3);
  assert.equal(conversation.messages[2].senderType, 'assistant');
  await request(`/teleconsultations/sessions/${session.id}/read`, 'POST', {});
  assert.equal((await request(`/teleconsultations/sessions/${session.id}`)).data.unreadCount, 1);
  await request(`/teleconsultations/sessions/${session.id}/read`, 'POST', {}, doctor);
  assert.equal((await request(`/teleconsultations/sessions/${session.id}`)).data.unreadCount, 0);
  assert.equal((await request('/teleconsultations/patient/patient-b')).status, 404);
});

test('signed uploads are owner scoped, size limited and never stored as inline blobs', async () => {
  const { request, completed, uploads } = fixture();
  const a = await completed();
  const session = (await request(`/teleconsultations/appointment/${a.id}`)).data;
  const path = `/teleconsultations/sessions/${session.id}`;
  assert.equal((await request(`${path}/attachments`, 'POST', { contentType: 'image/jpeg', size: 1024 }, other)).status, 404);
  assert.equal((await request(`${path}/attachments`, 'POST', { contentType: 'image/jpeg', size: 2000000 })).status, 400);
  const upload = (await request(`${path}/attachments`, 'POST', { contentType: 'image/png', size: 1024 })).data;
  assert.equal(uploads.length, 1);
  assert.ok(upload.objectKey.startsWith(`consultations/${session.id}/${patient.sub}/`));
  assert.equal((await request(`${path}/messages`, 'POST', { message: 'Ảnh', imageUrl: 'data:image/png;base64,a' })).status, 400);
  assert.equal((await request(`${path}/messages`, 'POST', { message: 'Ảnh', imageKey: upload.objectKey.replace(patient.sub, other.sub) })).status, 403);
  assert.equal((await request(`${path}/messages`, 'POST', { message: 'Ảnh', imageKey: upload.objectKey })).status, 201);
  const conversation = (await request(path)).data;
  assert.match(conversation.messages.find((m) => m.imageKey).imageUrl, /signed=1/);
});

test('closed sessions and disabled automation remain enforced across service instances', async () => {
  const { request, completed, store } = fixture();
  const a = await completed();
  const session = (await request(`/teleconsultations/appointment/${a.id}`)).data;
  const path = `/teleconsultations/sessions/${session.id}`;
  await request(path, 'PATCH', { auto_reply_enabled: false });
  await request(`${path}/messages`, 'POST', { message: 'Chào' });
  const fresh = new HospitalService(store, { download: async () => '' });
  const actor = { sub: patient.sub, roles: ['patients'] };
  assert.equal((await fresh.getSession(actor, session.id)).messages.length, 2);
  assert.equal((await request(`${path}/close`, 'PATCH', {})).status, 403);
  assert.equal((await request(`${path}/close`, 'PATCH', {}, doctor)).status, 200);
  assert.equal((await request(`${path}/messages`, 'POST', { message: 'Chào lần nữa' })).status, 400);
});

test('malformed, oversized and unauthorized requests fail before writing', async () => {
  const { request } = fixture();
  assert.equal((await request('/patients/me', 'POST', '{bad json')).status, 400);
  assert.equal((await request('/patients/me', 'POST', { large: 'x'.repeat(33000) })).status, 413);
  assert.equal((await request('/payments/mock')).status, 404);
});
