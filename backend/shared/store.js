import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { createHash, randomBytes, randomUUID, scrypt as derive, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { doctors } from '../src/repositories/catalog_repository.js';
import { HttpError } from '../src/utils/http.js';

const scrypt = promisify(derive);
const digest = (value) => createHash('sha256').update(value).digest('hex');
const text = (value, max = 120) => typeof value === 'string' ? value.trim().slice(0, max) : '';
export const slots = ['08:00', '08:30', '09:00', '09:30', '10:00', '10:30', '11:00', '13:00', '13:30', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30'];
export const vietnamDate = (value) => new Date(new Date(value).getTime() + 7 * 3600000).toISOString().slice(0, 10);

export class SharedStore {
  constructor(path) {
    if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
    this.db = new DatabaseSync(path);
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS shared_users (
        id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
        phone TEXT NOT NULL, role TEXT NOT NULL CHECK(role IN ('patient','doctor')),
        doctor_id TEXT, salt TEXT NOT NULL, password_hash TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS shared_sessions (
        token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES shared_users(id), expires_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS shared_appointments (
        id TEXT PRIMARY KEY, patient_id TEXT NOT NULL REFERENCES shared_users(id), doctor_id TEXT NOT NULL,
        start_time TEXT NOT NULL, status TEXT NOT NULL, payload TEXT NOT NULL,
        request_key TEXT, UNIQUE(patient_id, request_key));
      CREATE TABLE IF NOT EXISTS shared_queue_counters (
        doctor_id TEXT NOT NULL, visit_date TEXT NOT NULL, last_number INTEGER NOT NULL,
        PRIMARY KEY(doctor_id, visit_date));
      CREATE UNIQUE INDEX IF NOT EXISTS shared_active_slot ON shared_appointments(doctor_id, start_time)
        WHERE status IN ('pending','confirmed','checked_in');`);
  }

  user(row) {
    if (!row) return null;
    const doctor = doctors.find((d) => d.id === row.doctor_id);
    return { id: row.id, email: row.email, fullName: row.name, phoneNumber: row.phone,
      role: row.role, doctorId: row.doctor_id, department: doctor?.department };
  }

  async register(body, doctorId = null) {
    const email = text(body.email, 254).toLowerCase();
    const name = text(body.name);
    const password = body.password;
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || !name ||
        typeof password !== 'string' || password.length < 8 || password.length > 128) {
      throw new HttpError(400, 'Nhập họ tên, email hợp lệ và mật khẩu từ 8 đến 128 ký tự.');
    }
    const salt = randomBytes(16).toString('hex');
    const hash = (await scrypt(password, salt, 64)).toString('hex');
    const id = randomUUID();
    try {
      this.db.prepare('INSERT INTO shared_users VALUES (?,?,?,?,?,?,?,?)').run(
        id, email, name, text(body.phone, 30), doctorId ? 'doctor' : 'patient', doctorId, salt, hash);
    } catch (error) {
      if (error.message.includes('UNIQUE')) throw new HttpError(409, 'Email đã được đăng ký.');
      throw error;
    }
    return this.user(this.db.prepare('SELECT * FROM shared_users WHERE id=?').get(id));
  }

  async seedDemo() {
    for (const doctor of doctors) {
      const email = `doctor.${doctor.id.slice(3)}@hospital.com`;
      if (!this.db.prepare('SELECT id FROM shared_users WHERE email=?').get(email)) {
        await this.register({ email, name: doctor.name, password: 'Doctor@123' }, doctor.id);
      }
    }
    if (!this.db.prepare('SELECT id FROM shared_users WHERE email=?').get('patient.an@hospital.com')) {
      await this.register({email:'patient.an@hospital.com', name:'Nguyễn Văn An', phone:'0912345678', password:'Patient@123'});
    }
  }

  async login(body) {
    const row = this.db.prepare('SELECT * FROM shared_users WHERE email=?').get(text(body.email, 254).toLowerCase());
    const password = typeof body.password === 'string' && body.password.length <= 128 ? body.password : '';
    const hash = await scrypt(password, row?.salt ?? 'invalid-user-salt', 64);
    if (!row || !timingSafeEqual(hash, Buffer.from(row.password_hash, 'hex'))) {
      throw new HttpError(401, 'Email hoặc mật khẩu không đúng.');
    }
    const token = randomBytes(32).toString('base64url');
    const expiresAt = Date.now() + 24 * 3600000;
    this.db.prepare('DELETE FROM shared_sessions WHERE expires_at<=?').run(Date.now());
    this.db.prepare('INSERT INTO shared_sessions VALUES (?,?,?)').run(digest(token), row.id, expiresAt);
    return { token, expiresAt, user: this.user(row) };
  }

  authenticate(header = '') {
    const token = header.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1];
    const row = token && this.db.prepare(`SELECT u.* FROM shared_sessions s JOIN shared_users u ON u.id=s.user_id
      WHERE s.token_hash=? AND s.expires_at>?`).get(digest(token), Date.now());
    if (!row) throw new HttpError(401, 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    return this.user(row);
  }

  logout(header) {
    const token = header?.replace(/^Bearer /, '');
    if (token) this.db.prepare('DELETE FROM shared_sessions WHERE token_hash=?').run(digest(token));
  }

  requireRole(user, role) {
    if (user.role !== role) throw new HttpError(403, 'Tài khoản không có quyền thực hiện thao tác này.');
  }

  availability(doctorId, date) {
    if (!doctors.some((d) => d.id === doctorId)) throw new HttpError(404, 'Không tìm thấy bác sĩ.');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date ?? '') || Number.isNaN(Date.parse(`${date}T00:00:00+07:00`)) ||
        vietnamDate(`${date}T00:00:00+07:00`) !== date) throw new HttpError(400, 'Ngày khám không hợp lệ.');
    const booked = new Set(this.db.prepare(`SELECT start_time FROM shared_appointments
      WHERE doctor_id=? AND status IN ('pending','confirmed','checked_in')`).all(doctorId).map((r) => r.start_time));
    return { doctorId, date, slots: slots.map((time) => {
      const startTime = new Date(`${date}T${time}:00+07:00`).toISOString();
      const past = Date.parse(startTime) <= Date.now();
      return {time, startTime, endTime:new Date(Date.parse(startTime)+1800000).toISOString(),
        isAvailable:!past && !booked.has(startTime), unavailableReason:past ? 'Khung giờ đã qua' : booked.has(startTime) ? 'Khung giờ đã được đặt' : null};
    }) };
  }

  list(user, date) {
    const rows = user.role === 'doctor'
      ? this.db.prepare('SELECT payload FROM shared_appointments WHERE doctor_id=? ORDER BY start_time').all(user.doctorId)
      : this.db.prepare('SELECT payload FROM shared_appointments WHERE patient_id=? ORDER BY start_time').all(user.id);
    const items = rows.map((r) => JSON.parse(r.payload));
    return date ? items.filter((a) => vietnamDate(a.startTime) === date) : items;
  }

  get(user, id) {
    const row = this.db.prepare('SELECT * FROM shared_appointments WHERE id=?').get(id);
    if (!row || (user.role === 'doctor' ? row.doctor_id !== user.doctorId : row.patient_id !== user.id)) {
      throw new HttpError(404, 'Không tìm thấy lịch khám.');
    }
    return JSON.parse(row.payload);
  }

  create(user, body, requestKey) {
    this.requireRole(user, 'patient');
    const key = text(requestKey, 120) || text(body.appointmentId, 120) || null;
    if (key) {
      const existing = this.db.prepare('SELECT payload FROM shared_appointments WHERE patient_id=? AND request_key=?').get(user.id, key);
      if (existing) return JSON.parse(existing.payload);
    }
    const doctor = doctors.find((d) => d.id === body.doctorId);
    const start = Date.parse(body.startTime);
    if (!doctor || !Number.isFinite(start) || typeof body.reason !== 'string' ||
        !body.reason.trim() || body.reason.trim().length > 500) throw new HttpError(400, 'Bác sĩ, thời gian hoặc lý do khám không hợp lệ.');
    const startTime = new Date(start).toISOString();
    const slot = this.availability(doctor.id, vietnamDate(startTime)).slots.find((s) => s.startTime === startTime);
    if (!slot) throw new HttpError(400, 'Khung giờ không thuộc lịch làm việc.');
    if (!slot.isAvailable) throw new HttpError(start <= Date.now() ? 400 : 409, slot.unavailableReason);
    let parent;
    if (body.parentAppointmentId) {
      parent = this.get(user, body.parentAppointmentId);
      if (parent.status !== 'completed') throw new HttpError(400, 'Chỉ tái khám từ ca đã hoàn thành.');
    }
    const now = new Date().toISOString();
    const item = {id:`APT-${randomUUID()}`, patientId:user.id, patientName:user.fullName,
      doctorId:doctor.id, doctorName:doctor.name, department:doctor.department, departmentId:doctor.departmentId,
      specialty:doctor.specialty, startTime, endTime:slot.endTime, scheduledAt:startTime,
      reason:body.reason.trim(), status:'pending', createdAt:now, updatedAt:now,
      isFollowUp:!!parent, parentAppointmentId:parent?.id};
    try {
      this.db.prepare('INSERT INTO shared_appointments VALUES (?,?,?,?,?,?,?)')
        .run(item.id, user.id, doctor.id, startTime, 'pending', JSON.stringify(item), key);
    } catch (error) {
      if (error.message.includes('UNIQUE')) throw new HttpError(409, 'Khung giờ đã được đặt. Vui lòng chọn lại.');
      throw error;
    }
    return item;
  }

  update(user, id, body, action) {
    if (action === 'status' && body.status === 'completed') {
      return this.journeyAction(user, id, {...body, action:'prescribe'});
    }
    const item = this.get(user, id);
    const previous = JSON.stringify(item);
    if (action === 'cancel') {
      this.requireRole(user, 'patient');
      body = {status:'cancelled', note:text(body.reason, 500)};
      if (!['pending','confirmed'].includes(item.status)) throw new HttpError(409, 'Không thể hủy lịch ở trạng thái hiện tại.');
    } else {
      this.requireRole(user, 'doctor');
    }
    const allowed = {pending:['confirmed','cancelled'], confirmed:['cancelled'], checked_in:['cancelled'], completed:[], cancelled:[]};
    if (!allowed[item.status]?.includes(body.status)) throw new HttpError(409, 'Trạng thái lịch đã thay đổi. Vui lòng tải lại.');
    Object.assign(item, {status:body.status, statusNote:text(body.note, 500), updatedAt:new Date().toISOString()});
    if (item.status === 'cancelled') Object.assign(item, {cancelledAt:item.updatedAt, cancellationReason:item.statusNote});
    for (const field of ['diagnosis','prescription']) if (typeof body[field] === 'string') item[field] = text(body[field], 2000);
    return this.save(item, previous);
  }

  save(item, previous) {
    item.updatedAt = new Date().toISOString();
    const changed = this.db.prepare('UPDATE shared_appointments SET status=?,payload=? WHERE id=? AND payload=?')
      .run(item.status, JSON.stringify(item), item.id, previous);
    if (!changed.changes) throw new HttpError(409, 'Ca khám vừa thay đổi. Vui lòng tải lại.');
    return item;
  }

  checkin(user, id) {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const item = this.get(user, id);
      if (item.status === 'cancelled') throw new HttpError(409, 'Lịch đã hủy, không thể check-in.');
      if (item.checkedInAt) { this.db.exec('COMMIT'); return item; }
      if (item.status !== 'confirmed') throw new HttpError(409, 'Chỉ lịch đã được bác sĩ xác nhận mới được check-in.');
      const previous = JSON.stringify(item);
      const date = vietnamDate(item.startTime);
      const number = this.db.prepare(`INSERT INTO shared_queue_counters VALUES (?,?,1)
        ON CONFLICT(doctor_id,visit_date) DO UPDATE SET last_number=last_number+1 RETURNING last_number`)
        .get(item.doctorId, date).last_number;
      const rooms = {'dr-linh':'Phòng 204 - Tầng 2', 'dr-duc':'Phòng 105 - Tầng 1', 'dr-lan':'Phòng 302 - Tầng 3'};
      Object.assign(item, {status:'checked_in', queueNumber:number, checkedInAt:new Date().toISOString(),
        roomNumber:rooms[item.doctorId] || 'Quầy hướng dẫn',
        journey:{stage:'waiting', message:'Đã tiếp đón. Vui lòng chờ bác sĩ gọi số thứ tự.'}});
      this.save(item, previous);
      this.db.exec('COMMIT');
      return item;
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }

  journeyAction(user, id, body) {
    const item = this.get(user, id);
    const previous = JSON.stringify(item);
    const journey = {...item.journey};
    const now = new Date().toISOString();
    const patientActions = ['report_lab','simulate_payment','receive_medicines'];
    const doctorActions = ['call','order_lab','review_lab','prescribe'];
    if (!patientActions.includes(body.action) && !doctorActions.includes(body.action)) {
      throw new HttpError(400, 'Thao tác lộ trình không hợp lệ.');
    }
    this.requireRole(user, patientActions.includes(body.action) ? 'patient' : 'doctor');
    if (['pending','confirmed','cancelled'].includes(item.status)) {
      throw new HttpError(409, 'Bệnh nhân cần check-in trước khi thực hiện lộ trình khám.');
    }
    const requireStage = (...stages) => {
      if (!stages.includes(journey.stage)) throw new HttpError(409, 'Bước khám đã thay đổi hoặc chưa đến lượt. Vui lòng tải lại.');
    };
    const required = (value, name, max) => {
      if (typeof value !== 'string' || !value.trim() || value.trim().length > max) {
        throw new HttpError(400, `${name} là bắt buộc, tối đa ${max} ký tự.`);
      }
      return value.trim();
    };
    switch (body.action) {
      case 'call':
        if (item.status !== 'checked_in') throw new HttpError(409, 'Ca khám không còn ở hàng đợi.');
        requireStage('waiting');
        Object.assign(journey, {stage:'consulting', calledAt:now,
          message:`Mời số ${item.queueNumber} vào ${item.roomNumber} gặp ${item.doctorName}.`});
        break;
      case 'order_lab':
        requireStage('consulting');
        Object.assign(journey, {stage:'lab_ordered', labOrder:required(body.labOrder,'Chỉ định cận lâm sàng',1000),
          labOrderedAt:now, message:'Bác sĩ đã chỉ định cận lâm sàng. Xem hướng dẫn ở bước 3.'});
        break;
      case 'report_lab':
        requireStage('lab_ordered');
        Object.assign(journey, {stage:'lab_reported', labPatientReportedAt:now,
          message:'Bạn đã báo thực hiện cận lâm sàng. Chờ bác sĩ kiểm tra kết quả.'});
        break;
      case 'review_lab':
        requireStage('lab_reported');
        Object.assign(journey, {stage:'lab_completed', labReviewedAt:now,
          labResultNote:required(body.labResultNote,'Ghi nhận kết quả cận lâm sàng',2000),
          message:'Bác sĩ đã kiểm tra kết quả cận lâm sàng, đang hoàn tất kết luận và đơn thuốc.'});
        break;
      case 'prescribe':
        requireStage('consulting','lab_completed');
        if (item.status !== 'checked_in') throw new HttpError(409, 'Ca khám đã hoàn tất.');
        item.diagnosis = required(body.diagnosis,'Kết luận khám',1000);
        item.prescription = required(body.prescription,'Đơn thuốc',4000);
        item.statusNote = text(body.note,1000);
        item.status = 'completed';
        Object.assign(journey, {stage:'prescribed', prescribedAt:now, message:'Bác sĩ đã lưu đơn thuốc. Bạn có thể xem ở bước 4.'});
        break;
      case 'simulate_payment':
        requireStage('prescribed','finished');
        if (journey.paymentSimulatedAt) return item;
        Object.assign(journey, {paymentSimulatedAt:now, message:'Đã ghi nhận thanh toán mô phỏng. Vui lòng đến quầy dược nhận thuốc.'});
        break;
      case 'receive_medicines':
        requireStage('prescribed','finished');
        if (journey.medicinesReceivedAt) return item;
        if (!journey.paymentSimulatedAt) throw new HttpError(409, 'Cần hoàn tất bước thanh toán mô phỏng trước.');
        Object.assign(journey, {stage:'finished', medicinesReceivedAt:now,
          message:'Bạn đã xác nhận nhận thuốc. Lộ trình khám hoàn tất.'});
        break;
    }
    item.journey = journey;
    return this.save(item, previous);
  }

  close() { this.db.close(); }
}
