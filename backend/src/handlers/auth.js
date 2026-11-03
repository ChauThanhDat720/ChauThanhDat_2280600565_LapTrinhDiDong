import { randomUUID, randomBytes, createHash } from 'node:crypto';
import * as db from '../database/db.js';

export const toUserResponse = (row) => ({
  id: row.id,
  fullName: row.name,
  email: row.email,
  phoneNumber: row.phone || '',
  role: row.role,
  doctorId: row.doctor_id || null,
  department: row.department || null,
});

export const initAuthSchema = async () => {
  await db.run(`
    CREATE TABLE IF NOT EXISTS shared_users (
      id TEXT PRIMARY KEY,
      email TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      phone TEXT,
      role TEXT NOT NULL CHECK(role IN ('patient', 'doctor')),
      doctor_id TEXT,
      department TEXT,
      password_hash TEXT NOT NULL,
      salt TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS shared_sessions (
      token TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES shared_users(id),
      expires_at INTEGER NOT NULL
    );
  `);

  // Seed default demo users if they don't exist
  const demoUsers = [
    {
      id: 'dr-linh',
      email: 'doctor.linh@hospital.com',
      name: 'BS. CKII Nguyễn Tuấn Linh',
      phone: '0901234567',
      role: 'doctor',
      doctorId: 'dr-linh',
      department: 'Tim mạch',
      password: 'Doctor@123',
    },
    {
      id: 'dr-duc',
      email: 'doctor.duc@hospital.com',
      name: 'ThS. BS Trần Minh Đức',
      phone: '0902345678',
      role: 'doctor',
      doctorId: 'dr-duc',
      department: 'Nhi khoa',
      password: 'Doctor@123',
    },
    {
      id: 'dr-lan',
      email: 'doctor.lan@hospital.com',
      name: 'BS. CKI Lê Thị Lan',
      phone: '0903456789',
      role: 'doctor',
      doctorId: 'dr-lan',
      department: 'Da liễu',
      password: 'Doctor@123',
    },
    {
      id: 'patient-an',
      email: 'patient.an@hospital.com',
      name: 'Nguyễn Văn An',
      phone: '0912345678',
      role: 'patient',
      doctorId: null,
      department: null,
      password: 'Patient@123',
    },
  ];

  for (const u of demoUsers) {
    const existing = await db.get('SELECT id FROM shared_users WHERE email = ?', [u.email]);
    if (!existing) {
      const salt = randomBytes(16).toString('hex');
      const hash = createHash('sha256').update(u.password + salt).digest('hex');
      await db.run(
        `INSERT INTO shared_users (id, email, name, phone, role, doctor_id, department, password_hash, salt, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [u.id, u.email, u.name, u.phone, u.role, u.doctorId, u.department, hash, salt, new Date().toISOString()]
      );
    }
  }
};

export const register = async (body) => {
  const email = (body.email || '').trim().toLowerCase();
  const name = (body.name || '').trim();
  const password = body.password || '';
  const phone = (body.phone || body.phoneNumber || '').trim();

  if (!email || !name || password.length < 6) {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify({ message: 'Vui lòng điền họ tên, email hợp lệ và mật khẩu tối thiểu 6 ký tự.' }),
    };
  }

  const existing = await db.get('SELECT id FROM shared_users WHERE email = ?', [email]);
  if (existing) {
    return {
      statusCode: 409,
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify({ message: 'Email đã được đăng ký trong hệ thống.' }),
    };
  }

  const id = `pt-${randomUUID().slice(0, 8)}`;
  const salt = randomBytes(16).toString('hex');
  const hash = createHash('sha256').update(password + salt).digest('hex');
  const now = new Date().toISOString();

  await db.run(
    `INSERT INTO shared_users (id, email, name, phone, role, doctor_id, department, password_hash, salt, created_at)
     VALUES (?, ?, ?, ?, 'patient', NULL, NULL, ?, ?, ?)`,
    [id, email, name, phone, hash, salt, now]
  );

  const user = toUserResponse({
    id, email, name, phone, role: 'patient', doctor_id: null, department: null,
  });

  return {
    statusCode: 201,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify({ user }),
  };
};

export const login = async (body) => {
  const email = (body.email || '').trim().toLowerCase();
  const password = body.password || '';

  const row = await db.get('SELECT * FROM shared_users WHERE email = ?', [email]);
  if (!row) {
    return {
      statusCode: 401,
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify({ message: 'Email hoặc mật khẩu không chính xác.' }),
    };
  }

  const hash = createHash('sha256').update(password + row.salt).digest('hex');
  if (hash !== row.password_hash) {
    return {
      statusCode: 401,
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify({ message: 'Email hoặc mật khẩu không chính xác.' }),
    };
  }

  const token = randomBytes(32).toString('base64url');
  const expiresAt = Date.now() + 24 * 3600000;

  await db.run(
    'INSERT OR REPLACE INTO shared_sessions (token, user_id, expires_at) VALUES (?, ?, ?)',
    [token, row.id, expiresAt]
  );

  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify({
      token,
      expiresAt,
      user: toUserResponse(row),
    }),
  };
};

export const getMe = async (token) => {
  if (!token) {
    return {
      statusCode: 401,
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify({ message: 'Chưa đăng nhập hoặc phiên đã hết hạn.' }),
    };
  }

  const session = await db.get(
    `SELECT u.* FROM shared_sessions s
     JOIN shared_users u ON u.id = s.user_id
     WHERE s.token = ? AND s.expires_at > ?`,
    [token, Date.now()]
  );

  if (!session) {
    return {
      statusCode: 401,
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify({ message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.' }),
    };
  }

  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify({ user: toUserResponse(session) }),
  };
};

export const logout = async (token) => {
  if (token) {
    await db.run('DELETE FROM shared_sessions WHERE token = ?', [token]);
  }
  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify({ ok: true }),
  };
};

export const getUserByToken = async (token) => {
  if (!token) return null;
  const session = await db.get(
    `SELECT u.* FROM shared_sessions s
     JOIN shared_users u ON u.id = s.user_id
     WHERE s.token = ? AND s.expires_at > ?`,
    [token, Date.now()]
  );
  return session ? toUserResponse(session) : null;
};
