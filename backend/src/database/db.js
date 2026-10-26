import sqlite3 from 'sqlite3';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { mkdirSync } from 'node:fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const dataDir = join(__dirname, '../../data');
mkdirSync(dataDir, { recursive: true });

const isTest =
  process.env.NODE_ENV === 'test' ||
  process.execArgv.includes('--test') ||
  process.argv.some((a) => a.includes('test'));

const dbPath = isTest && !process.env.USE_FILE_DB ? ':memory:' : join(dataDir, 'hospital.db');

export const rawDb = new sqlite3.Database(dbPath);

// Enable WAL mode & Foreign Keys
rawDb.serialize(() => {
  rawDb.run('PRAGMA foreign_keys = ON;');
  if (dbPath !== ':memory:') {
    rawDb.run('PRAGMA journal_mode = WAL;');
  }
});

// Promisified Database Helper Methods
export const run = (sql, params = []) =>
  new Promise((resolve, reject) => {
    rawDb.run(sql, params, function (err) {
      if (err) reject(err);
      else resolve({ lastID: this.lastID, changes: this.changes });
    });
  });

export const get = (sql, params = []) =>
  new Promise((resolve, reject) => {
    rawDb.get(sql, params, (err, row) => {
      if (err) reject(err);
      else resolve(row);
    });
  });

export const all = (sql, params = []) =>
  new Promise((resolve, reject) => {
    rawDb.all(sql, params, (err, rows) => {
      if (err) reject(err);
      else resolve(rows || []);
    });
  });

// Schema Initialization
export const initSchema = async () => {
  await run(`
    CREATE TABLE IF NOT EXISTS patients (
      cognito_user_id TEXT PRIMARY KEY,
      patient_id TEXT NOT NULL,
      name TEXT NOT NULL,
      email TEXT,
      phone TEXT,
      date_of_birth TEXT,
      gender TEXT,
      address TEXT,
      emergency_contact_name TEXT,
      emergency_contact_phone TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS doctors (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      specialty TEXT NOT NULL,
      department TEXT NOT NULL,
      phone TEXT,
      email TEXT,
      avatar TEXT,
      rating_avg REAL DEFAULT 5.0
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS appointments (
      id TEXT PRIMARY KEY,
      patient_id TEXT NOT NULL,
      patient_name TEXT NOT NULL,
      doctor_id TEXT NOT NULL,
      doctor_name TEXT NOT NULL,
      department TEXT NOT NULL,
      specialty TEXT NOT NULL,
      scheduled_at TEXT NOT NULL,
      time TEXT NOT NULL,
      reason TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      status_note TEXT,
      diagnosis TEXT,
      prescription TEXT,
      rating INTEGER,
      review_note TEXT,
      reviewed_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      cancelled_at TEXT,
      cancellation_reason TEXT,
      queue_number INTEGER,
      checked_in_at TEXT,
      room_number TEXT DEFAULT 'Phòng 204 - Tầng 2',
      FOREIGN KEY (doctor_id) REFERENCES doctors(id)
    );
  `);

  try {
    await run('ALTER TABLE appointments ADD COLUMN queue_number INTEGER');
  } catch (_) {}
  try {
    await run('ALTER TABLE appointments ADD COLUMN checked_in_at TEXT');
  } catch (_) {}
  try {
    await run("ALTER TABLE appointments ADD COLUMN room_number TEXT DEFAULT 'Phòng 204 - Tầng 2'");
  } catch (_) {}
  try {
    await run('ALTER TABLE appointments ADD COLUMN follow_up_date TEXT');
  } catch (_) {}
  try {
    await run('ALTER TABLE appointments ADD COLUMN is_follow_up INTEGER DEFAULT 0');
  } catch (_) {}
  try {
    await run('ALTER TABLE appointments ADD COLUMN parent_appointment_id TEXT');
  } catch (_) {}
  try {
    await run('ALTER TABLE appointments ADD COLUMN has_intake INTEGER DEFAULT 0');
  } catch (_) {}

  await run(`
    CREATE INDEX IF NOT EXISTS idx_appointments_patient ON appointments(patient_id);
    CREATE INDEX IF NOT EXISTS idx_appointments_doctor_date ON appointments(doctor_id, scheduled_at);
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS idempotency_keys (
      key TEXT PRIMARY KEY,
      appointment_id TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  `);

  // Views for Medical Records and Ratings to expose standard tables to queries
  await run(`
    CREATE VIEW IF NOT EXISTS medical_records AS
    SELECT 
      id AS record_id,
      id AS appointment_id,
      patient_id,
      patient_name,
      doctor_id,
      doctor_name,
      department,
      specialty,
      scheduled_at AS examination_date,
      diagnosis,
      prescription,
      status,
      updated_at
    FROM appointments
    WHERE status = 'completed';
  `);

  await run(`
    CREATE VIEW IF NOT EXISTS ratings AS
    SELECT
      id AS rating_id,
      id AS appointment_id,
      patient_id,
      doctor_id,
      doctor_name,
      rating,
      review_note,
      reviewed_at
    FROM appointments
    WHERE rating IS NOT NULL;
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS medicines (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      brand_names TEXT NOT NULL,
      active_ingredient TEXT NOT NULL,
      category TEXT NOT NULL,
      dosage_form TEXT NOT NULL,
      indications TEXT NOT NULL,
      dosage_instructions TEXT NOT NULL,
      side_effects TEXT NOT NULL,
      contraindications TEXT NOT NULL,
      precautions TEXT,
      created_at TEXT NOT NULL
    );
  `);

  await run(`
    CREATE INDEX IF NOT EXISTS idx_medicines_name ON medicines(name);
    CREATE INDEX IF NOT EXISTS idx_medicines_category ON medicines(category);
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS medication_reminders (
      id TEXT PRIMARY KEY,
      patient_id TEXT NOT NULL,
      appointment_id TEXT,
      medicine_name TEXT NOT NULL,
      dosage TEXT NOT NULL,
      instructions TEXT,
      times_per_day INTEGER NOT NULL DEFAULT 2,
      reminder_times TEXT NOT NULL,
      start_date TEXT NOT NULL,
      days_count INTEGER NOT NULL DEFAULT 5,
      end_date TEXT NOT NULL,
      color_code TEXT DEFAULT '#0D9488',
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS medication_logs (
      id TEXT PRIMARY KEY,
      reminder_id TEXT NOT NULL,
      patient_id TEXT NOT NULL,
      date TEXT NOT NULL,
      time TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      taken_at TEXT,
      note TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (reminder_id) REFERENCES medication_reminders(id) ON DELETE CASCADE
    );
  `);

  await run(`
    CREATE INDEX IF NOT EXISTS idx_reminders_patient ON medication_reminders(patient_id);
    CREATE INDEX IF NOT EXISTS idx_logs_patient_date ON medication_logs(patient_id, date);
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS health_vitals (
      id TEXT PRIMARY KEY,
      patient_id TEXT NOT NULL,
      appointment_id TEXT,
      systolic INTEGER NOT NULL,
      diastolic INTEGER NOT NULL,
      heart_rate INTEGER,
      blood_sugar REAL,
      blood_sugar_condition TEXT DEFAULT 'fasting',
      weight REAL,
      height REAL,
      bmi REAL,
      health_status TEXT DEFAULT 'optimal',
      health_note TEXT,
      note TEXT,
      recorded_by TEXT DEFAULT 'patient',
      recorded_at TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  `);

  await run(`
    CREATE INDEX IF NOT EXISTS idx_vitals_patient_date ON health_vitals(patient_id, recorded_at);
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS hospital_invoices (
      id TEXT PRIMARY KEY,
      appointment_id TEXT NOT NULL,
      patient_id TEXT NOT NULL,
      patient_name TEXT NOT NULL,
      doctor_id TEXT,
      doctor_name TEXT,
      department TEXT,
      invoice_code TEXT UNIQUE NOT NULL,
      e_invoice_lookup_code TEXT,
      examination_fee INTEGER NOT NULL DEFAULT 150000,
      medicine_fee INTEGER NOT NULL DEFAULT 0,
      other_fee INTEGER NOT NULL DEFAULT 0,
      discount_amount INTEGER NOT NULL DEFAULT 0,
      total_amount INTEGER NOT NULL,
      payment_status TEXT NOT NULL DEFAULT 'unpaid',
      payment_method TEXT DEFAULT 'vietqr',
      payment_ref TEXT UNIQUE NOT NULL,
      bank_name TEXT DEFAULT 'MBBank',
      bank_bin TEXT DEFAULT '970422',
      bank_account_number TEXT DEFAULT '050902185537',
      bank_account_name TEXT DEFAULT 'CHAU THANH DAT',
      bank_transaction_id TEXT,
      paid_amount INTEGER DEFAULT 0,
      paid_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  await run(`
    CREATE INDEX IF NOT EXISTS idx_invoices_patient ON hospital_invoices(patient_id);
    CREATE INDEX IF NOT EXISTS idx_invoices_appointment ON hospital_invoices(appointment_id);
    CREATE INDEX IF NOT EXISTS idx_invoices_ref ON hospital_invoices(payment_ref);
    CREATE INDEX IF NOT EXISTS idx_invoices_status ON hospital_invoices(payment_status);
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS family_members (
      id TEXT PRIMARY KEY,
      primary_patient_id TEXT NOT NULL,
      full_name TEXT NOT NULL,
      relationship TEXT NOT NULL,
      date_of_birth TEXT,
      gender TEXT,
      phone TEXT,
      bhyt_code TEXT,
      identity_card TEXT,
      blood_type TEXT,
      medical_history TEXT,
      avatar TEXT,
      is_default INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  await run(`
    CREATE INDEX IF NOT EXISTS idx_family_primary ON family_members(primary_patient_id);
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS teleconsultation_sessions (
      id TEXT PRIMARY KEY,
      appointment_id TEXT UNIQUE NOT NULL,
      patient_id TEXT NOT NULL,
      patient_name TEXT NOT NULL,
      doctor_id TEXT NOT NULL,
      doctor_name TEXT NOT NULL,
      department TEXT NOT NULL,
      diagnosis TEXT,
      prescription TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      expires_at TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (appointment_id) REFERENCES appointments(id)
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS teleconsultation_messages (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      sender_type TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      sender_name TEXT NOT NULL,
      message TEXT NOT NULL,
      image_url TEXT,
      is_read INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      FOREIGN KEY (session_id) REFERENCES teleconsultation_sessions(id) ON DELETE CASCADE
    );
  `);

  await run(`
    CREATE INDEX IF NOT EXISTS idx_telecon_appt ON teleconsultation_sessions(appointment_id);
    CREATE INDEX IF NOT EXISTS idx_telecon_doctor ON teleconsultation_sessions(doctor_id);
    CREATE INDEX IF NOT EXISTS idx_telecon_patient ON teleconsultation_sessions(patient_id);
    CREATE INDEX IF NOT EXISTS idx_telecon_messages ON teleconsultation_messages(session_id, created_at);
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS clinical_intakes (
      id TEXT PRIMARY KEY,
      appointment_id TEXT UNIQUE NOT NULL,
      patient_id TEXT NOT NULL,
      chief_complaint TEXT NOT NULL,
      pain_location TEXT,
      onset_duration TEXT NOT NULL,
      pain_level INTEGER NOT NULL DEFAULT 0,
      symptoms TEXT,
      current_medications TEXT,
      medical_history TEXT,
      known_allergies TEXT,
      notes TEXT,
      submitted_at TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE
    );
  `);

  await run(`
    CREATE INDEX IF NOT EXISTS idx_intakes_appt ON clinical_intakes(appointment_id);
    CREATE INDEX IF NOT EXISTS idx_intakes_patient ON clinical_intakes(patient_id);
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS vaccinations (
      id TEXT PRIMARY KEY,
      patient_id TEXT NOT NULL,
      family_member_id TEXT DEFAULT 'fam-self',
      patient_name TEXT NOT NULL,
      vaccine_name TEXT NOT NULL,
      target_disease TEXT NOT NULL,
      dose_number INTEGER NOT NULL DEFAULT 1,
      total_doses INTEGER NOT NULL DEFAULT 3,
      batch_number TEXT NOT NULL,
      manufacturer TEXT NOT NULL,
      administered_date TEXT NOT NULL,
      next_dose_date TEXT,
      facility_name TEXT NOT NULL DEFAULT 'Bệnh viện Đa khoa Quốc tế Smart Hospital',
      doctor_name TEXT NOT NULL DEFAULT 'BS. Trần Thảo Linh',
      nurse_name TEXT DEFAULT 'ĐD. Lê Thị Hồng',
      reaction_status TEXT DEFAULT 'Bình thường, không sốt, không phản ứng phụ',
      certificate_code TEXT UNIQUE NOT NULL,
      status TEXT DEFAULT 'completed',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  await run(`
    CREATE INDEX IF NOT EXISTS idx_vaccine_patient ON vaccinations(patient_id, family_member_id);
    CREATE INDEX IF NOT EXISTS idx_vaccine_cert ON vaccinations(certificate_code);
  `);

  // Seed default vaccinations if empty
  const vacCount = await get('SELECT COUNT(*) as count FROM vaccinations');
  if (vacCount?.count === 0) {
    const now = new Date();
    const dateAdministered1 = new Date(now.getTime() - 60 * 24 * 3600 * 1000).toISOString().slice(0, 10);
    const nextDose1 = new Date(now.getTime() + 7 * 24 * 3600 * 1000).toISOString().slice(0, 10);
    const dateAdministered2 = new Date(now.getTime() - 30 * 24 * 3600 * 1000).toISOString().slice(0, 10);
    const dateAdministered3 = new Date(now.getTime() - 180 * 24 * 3600 * 1000).toISOString().slice(0, 10);
    const dateAdministeredChild = new Date(now.getTime() - 300 * 24 * 3600 * 1000).toISOString().slice(0, 10);
    const nowIso = now.toISOString();

    await run(`
      INSERT INTO vaccinations (
        id, patient_id, family_member_id, patient_name, vaccine_name, target_disease,
        dose_number, total_doses, batch_number, manufacturer, administered_date, next_dose_date,
        facility_name, doctor_name, nurse_name, reaction_status, certificate_code, status, created_at, updated_at
      ) VALUES
      (
        'vac-001', 'test-patient-sub-123', 'fam-self', 'Nguyễn Văn An',
        'Gardasil 9 (Mỹ)', 'Ung thư cổ tử cung, u nhú & mụn cóc sinh dục do HPV',
        1, 3, 'MSD-VN2408', 'Merck Sharp & Dohme (Mỹ)', '${dateAdministered1}', '${nextDose1}',
        'Bệnh viện Đa khoa Quốc tế Smart Hospital', 'BS. Trần Thảo Linh', 'ĐD. Lê Thị Hồng',
        'Vết tiêm hơi căng tức nhẹ, hết sau 24h', 'VAC-2026-VN-98231', 'completed', '${nowIso}', '${nowIso}'
      ),
      (
        'vac-002', 'test-patient-sub-123', 'fam-self', 'Nguyễn Văn An',
        'Vaxigrip Tetra (Pháp)', 'Cúm mùa tứ giá (A/H1N1, A/H3N2, B/Victoria, B/Yamagata)',
        1, 1, 'SNF-FR7712', 'Sanofi Pasteur (Pháp)', '${dateAdministered2}', NULL,
        'Bệnh viện Đa khoa Quốc tế Smart Hospital', 'BS. Trần Thảo Linh', 'ĐD. Lê Thị Hồng',
        'Bình thường, không sốt, không phản ứng phụ', 'VAC-2026-VN-87123', 'completed', '${nowIso}', '${nowIso}'
      ),
      (
        'vac-003', 'test-patient-sub-123', 'fam-self', 'Nguyễn Văn An',
        'Engerix B 20mcg (Bỉ)', 'Viêm gan virus B',
        3, 3, 'GSK-BE8921', 'GlaxoSmithKline - GSK (Bỉ)', '${dateAdministered3}', NULL,
        'Bệnh viện Đa khoa Quốc tế Smart Hospital', 'BS. Trần Thảo Linh', 'ĐD. Nguyễn Thu Hà',
        'Bình thường, nồng độ kháng thể Anti-HBs đạt > 1000 mIU/mL', 'VAC-2026-VN-66512', 'completed', '${nowIso}', '${nowIso}'
      ),
      (
        'vac-004', 'test-patient-sub-123', 'fam-child', 'Nguyễn Minh Khang',
        'Infanrix Hexa 6 trong 1 (Bỉ)', 'Bạch hầu, Ho gà, Uốn ván, Bại liệt, Hib, Viêm gan B',
        3, 3, 'GSK-6IN1-5521', 'GlaxoSmithKline - GSK (Bỉ)', '${dateAdministeredChild}', NULL,
        'Bệnh viện Đa khoa Quốc tế Smart Hospital', 'BS. Lê Thị Mai', 'ĐD. Nguyễn Thu Hà',
        'Sốt nhẹ 37.8 độ C sau tiêm 6h, hạ sốt sau uống Paracetamol', 'VAC-2026-VN-33109', 'completed', '${nowIso}', '${nowIso}'
      );
    `);
  }

  // Seed default family members for primary patient BN-01
  const famCount = await get('SELECT COUNT(*) as count FROM family_members');
  if (famCount?.count === 0) {
    const now = new Date().toISOString();
    await run(`
      INSERT INTO family_members (
        id, primary_patient_id, full_name, relationship, date_of_birth, gender,
        phone, bhyt_code, identity_card, blood_type, medical_history, is_default, created_at, updated_at
      ) VALUES
      (
        'fam-self', 'test-patient-sub-123', 'Nguyễn Văn An', 'self', '1992-04-12', 'Nam',
        '0912345678', 'DN4791234567890', '079092001234', 'O+', 'Không có tiền sử dị ứng thuốc', 1, '${now}', '${now}'
      ),
      (
        'fam-mother', 'test-patient-sub-123', 'Trần Thị Mai', 'mother', '1965-08-15', 'Nữ',
        '0908765432', 'GD4798765432100', '079165005678', 'A+', 'Tăng huyết áp vô căn 5 năm, thoái hóa khớp gối', 0, '${now}', '${now}'
      ),
      (
        'fam-child', 'test-patient-sub-123', 'Nguyễn Minh Khang', 'child', '2018-05-10', 'Nam',
        '0912345678', 'TE1791234567800', '079218009876', 'O+', 'Dị ứng nhẹ với kháng sinh Amoxicillin', 0, '${now}', '${now}'
      );
    `);
  }

  // Seed medicines if empty
  const medCount = await get('SELECT COUNT(*) as count FROM medicines');
  if (medCount?.count === 0) {
    const now = new Date().toISOString();
    const seedMedicines = [
      [
        'med-paracetamol',
        'Paracetamol',
        'Panadol, Hapacol, Efferalgan, Tylenol',
        'Paracetamol 500mg',
        'Giảm đau - Hạ sốt',
        'Viên nén / Viên sủi',
        'Hạ sốt, giảm các cơn đau từ nhẹ đến vừa: đau đầu, đau răng, đau họng, đau nhức cơ khớp, đau bụng kinh.',
        'Người lớn: 500mg - 1000mg (1-2 viên)/lần, mỗi 4-6 giờ. Tối đa không quá 4g (8 viên)/ngày. Uống sau ăn.',
        'Hiếm gặp phát ban da, nổi mề đay. Dùng quá liều hoặc kéo dài có thể gây độc tính nghiêm trọng trên gan (suy gan cấp).',
        'Quá mẫn với paracetamol. Người suy gan nặng, thiếu hụt men G6PD.',
        'Không uống rượu bia khi đang dùng thuốc. Tránh dùng chung với các thuốc khác cũng chứa paracetamol để tránh quá liều.',
        now,
      ],
      [
        'med-amlodipine',
        'Amlodipine',
        'Norvasc, Amlor, Amlopin',
        'Amlodipine besylate 5mg',
        'Tim mạch - Huyết áp',
        'Viên nén',
        'Điều trị tăng huyết áp vô căn, đau thắt ngực mạn tính ổn định, đau thắt ngực thể co thắt (Prinzmetal).',
        'Khởi đầu 5mg x 1 lần/ngày. Có thể tăng tối đa lên 10mg x 1 lần/ngày sau 2-4 tuần nếu cần. Uống cùng một thời điểm mỗi ngày.',
        'Phù cổ chân/bàn chân, nhức đầu, chóng mặt, đỏ bừng mặt, hồi hộp, mệt mỏi.',
        'Hạ huyết áp nặng, sốc tim, hẹp van động mạch chủ nặng, suy tim huyết động không ổn định.',
        'Thận trọng ở người cao tuổi và bệnh nhân suy giảm chức năng gan.',
        now,
      ],
      [
        'med-aspirin',
        'Aspirin 81mg',
        'Aspirin pH8, Aspilets, Cardiprin',
        'Acetylsalicylic acid 81mg',
        'Tim mạch - Chống đông máu',
        'Viên bao tan trong ruột',
        'Phòng ngừa tiên phát và thứ phát nhồi máu cơ tim, đột quỵ thiếu máu cục bộ, chống kết tập tiểu cầu.',
        'Người lớn: 1 viên (81mg - 100mg) x 1 lần/ngày. Uống nguyên viên với nhiều nước sau bữa ăn chính.',
        'Kích ứng dạ dày, buồn nôn, khó tiêu, nguy cơ xuất huyết tiêu hóa, bầm tím dưới da.',
        'Loét dạ dày tá tràng tiến triển, rối loạn đông máu, hen suyễn do NSAID, suy gan thận nặng.',
        'Ngừng thuốc 7 ngày trước các phẫu thuật hoặc nhổ răng. Thông báo ngay nếu có phân đen hoặc nôn ra máu.',
        now,
      ],
      [
        'med-amoxicillin',
        'Amoxicillin',
        'Augmentin, Clamoxyl, Ospamox',
        'Amoxicillin trihydrate 500mg',
        'Kháng sinh',
        'Viên nang / Viên nén',
        'Điều trị nhiễm khuẩn đường hô hấp trên và dưới (viêm họng, viêm amidan, viêm phế quản, viêm xoang), nhiễm khuẩn tai mũi họng, tiết niệu.',
        '500mg mỗi 8 giờ hoặc 875mg mỗi 12 giờ. Uống đủ đợt từ 7-10 ngày theo chỉ định, không tự ý ngưng thuốc giữa chừng.',
        'Tiêu chảy nhẹ, buồn nôn, nổi mẩn đỏ trên da, nhiễm nấm Candida miệng/âm đạo.',
        'Tiền sử dị ứng với kháng sinh nhóm Penicillin hoặc Cephalosporin, bệnh tăng bạch cầu đơn nhân nhiễm trùng.',
        'Uống nhiều nước. Nếu xuất hiện phát ban ngứa hoặc khó thở, ngưng thuốc ngay lập tức.',
        now,
      ],
      [
        'med-metformin',
        'Metformin',
        'Glucophage, Panfor, Diamet',
        'Metformin hydrochloride 500mg / 850mg',
        'Tiểu đường',
        'Viên nén bao phim',
        'Điều trị đái tháo đường type 2 ở người lớn, đặc biệt ở bệnh nhân thừa cân béo phì khi chế độ ăn và luyện tập không kiểm soát đủ đường huyết.',
        'Khởi đầu 500mg x 1-2 lần/ngày trong hoặc ngay sau bữa ăn để giảm tác dụng phụ trên đường tiêu hóa.',
        'Đầy bụng, tiêu chảy, buồn nôn, miệng có vị kim loại, chán ăn (thường tự hết sau vài tuần).',
        'Suy thận nặng (eGFR < 30), suy tim mất bù, nhiễm toan ceton do tiểu đường, nghiện rượu mạn tính.',
        'Tạm ngưng dùng trước 48 giờ khi chụp X-quang hoặc CT scan có tiêm thuốc cản quang chứa iod.',
        now,
      ],
      [
        'med-salbutamol',
        'Salbutamol',
        'Ventolin Inhaler, Asmasal',
        'Salbutamol sulfate 100mcg/nhát xịt',
        'Hô hấp - Hen suyễn',
        'Bình xịt định liều (Inhaler)',
        'Cắt cơn co thắt phế quản cấp trong hen phế quản, viêm phế quản mạn tính, bệnh phổi tắc nghẽn mạn tính (COPD).',
        'Cắt cơn hen cấp: Xịt 1-2 nhát vào miệng. Tối đa không quá 8 nhát/ngày. Lắc đều bình xịt trước khi dùng.',
        'Run ngón tay nhẹ, hồi hộp, tim đập nhanh, đau đầu, hạ kali máu thoáng qua.',
        'Quá mẫn với Salbutamol, dọa sảy thai trong 6 tháng đầu.',
        'Thận trọng ở bệnh nhân cường giáp, rối loạn nhịp tim nhanh, tăng huyết áp.',
        now,
      ],
      [
        'med-omeprazole',
        'Omeprazole',
        'Losec, Omez, Omeptik',
        'Omeprazole 20mg',
        'Tiêu hóa - Dạ dày',
        'Viên nang tan trong ruột',
        'Viêm loét dạ dày - tá tràng, trào ngược dạ dày thực quản (GERD), hội chứng Zollinger-Ellison, phối hợp kháng sinh diệt HP.',
        '20mg x 1 lần/ngày. Uống nguyên viên vào buổi sáng trước bữa ăn ít nhất 30-60 phút.',
        'Nhức đầu, đầy hơi, đau bụng, táo bón hoặc tiêu chảy nhẹ.',
        'Dị ứng với các thuốc ức chế bơm proton (PPI). Không phối hợp với nelfinavir.',
        'Không nhai hoặc nghiền nát hạt thuốc trong viên nang.',
        now,
      ],
      [
        'med-ibuprofen',
        'Ibuprofen',
        'Gofen, Brufen, Alaxan',
        'Ibuprofen 400mg',
        'Kháng viêm - Giảm đau',
        'Viên nang mềm',
        'Giảm đau và kháng viêm trong viêm khớp, thoái hóa khớp, đau lưng, đau răng, đau sau chấn thương, thống kinh.',
        'Người lớn: 400mg x 3 lần/ngày sau khi ăn no. Uống kèm một ly nước đầy.',
        'Ợ nóng, loét dạ dày, chóng mặt, tăng men gan, ứ dịch nhẹ.',
        'Viêm loét dạ dày tiến triển, suy gan thận nặng, 3 tháng cuối thai kỳ, tiền sử co thắt phế quản do aspirin.',
        'Dùng liều thấp nhất có hiệu quả trong thời gian ngắn nhất có thể.',
        now,
      ],
      [
        'med-cetirizine',
        'Cetirizine',
        'Zyrtec, Cetiriz, Virlix',
        'Cetirizine dihydrochloride 10mg',
        'Dị ứng - Kháng Histamin',
        'Viên nén bao phim',
        'Điều trị viêm mũi dị ứng theo mùa hoặc quanh năm, viêm kết mạc dị ứng, mề đay mạn tính vô căn, ngứa do dị ứng thời tiết.',
        'Người lớn và trẻ trên 12 tuổi: 10mg (1 viên) x 1 lần/ngày vào buổi tối trước khi đi ngủ.',
        'Buồn ngủ nhẹ, khô miệng, mệt mỏi, đau đầu.',
        'Suy thận giai đoạn cuối (ClCr < 10ml/phút), dị ứng với cetirizine hoặc hydroxyzine.',
        'Thận trọng khi lái xe hoặc vận hành máy móc do có thể gây buồn ngủ nhẹ.',
        now,
      ],
      [
        'med-atorvastatin',
        'Atorvastatin',
        'Lipitor, Atorlip, Stator',
        'Atorvastatin calcium 20mg',
        'Tim mạch - Hạ mỡ máu',
        'Viên nén',
        'Hạ cholesterol toàn phần, LDL-C, triglyceride; phòng ngừa tai biến mạch máu não và biến cố mạch vành ở người có nguy cơ cao.',
        'Khởi đầu 10-20mg x 1 lần/ngày vào buổi tối. Có thể điều chỉnh liều sau 4 tuần.',
        'Đau cơ, yếu cơ, rối loạn tiêu hóa nhẹ, tăng men gan thoáng qua.',
        'Bệnh gan tiến triển, phụ nữ có thai và đang cho con bú.',
        'Báo ngay cho bác sĩ nếu bị đau cơ, yếu cơ không rõ nguyên nhân.',
        now,
      ],
    ];

    for (const med of seedMedicines) {
      await run(
        `INSERT INTO medicines (
          id, name, brand_names, active_ingredient, category, dosage_form,
          indications, dosage_instructions, side_effects, contraindications,
          precautions, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        med,
      );
    }
  }

  // Seed doctors if empty
  const docCount = await get('SELECT COUNT(*) as count FROM doctors');
  if (docCount?.count === 0) {
    await run(`
      INSERT INTO doctors (id, name, specialty, department, phone, email, rating_avg) VALUES
      ('dr-linh', 'BS. Trần Thảo Linh', 'Tim mạch can thiệp', 'Tim mạch', '0901234567', 'doctor.linh@hospital.com', 4.9),
      ('dr-tuan', 'BS. Nguyễn Văn Tuấn', 'Nội tiết & Tiểu đường', 'Nội tiết', '0902345678', 'doctor.tuan@hospital.com', 4.8),
      ('dr-mai', 'BS. Lê Thị Mai', 'Nhi khoa lâm sàng', 'Nhi khoa', '0903456789', 'doctor.mai@hospital.com', 5.0),
      ('dr-hung', 'BS. Hoàng Văn Hùng', 'Phổi & Hô hấp', 'Hô hấp', '0904567890', 'doctor.hung@hospital.com', 4.7),
      ('dr-lan', 'BS. Phạm Thị Lan', 'Nhãn khoa kỹ thuật cao', 'Mắt', '0905678901', 'doctor.lan@hospital.com', 4.9);
    `);
  }
};

// Auto-run schema initialization
await initSchema();
