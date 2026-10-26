import { all, get, run } from '../database/db.js';

export async function listMembers(primaryPatientId = 'test-patient-sub-123') {
  let rows = await all(
    'SELECT * FROM family_members WHERE primary_patient_id = ? ORDER BY is_default DESC, created_at ASC',
    [primaryPatientId],
  );

  // Tự động seed nếu người dùng chưa có thành viên nào
  if (rows.length === 0) {
    const now = new Date().toISOString();
    await run(
      `INSERT INTO family_members (
        id, primary_patient_id, full_name, relationship, date_of_birth, gender,
        phone, bhyt_code, identity_card, blood_type, medical_history, is_default, created_at, updated_at
      ) VALUES
      (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?),
      (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?),
      (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        `fam-self-${primaryPatientId}`,
        primaryPatientId,
        'Nguyễn Văn An',
        'self',
        '1992-04-12',
        'Nam',
        '0912345678',
        'DN4791234567890',
        '079092001234',
        'O+',
        'Không có tiền sử dị ứng thuốc',
        1,
        now,
        now,
        `fam-mother-${primaryPatientId}`,
        primaryPatientId,
        'Trần Thị Mai',
        'mother',
        '1965-08-15',
        'Nữ',
        '0908765432',
        'GD4798765432100',
        '079165005678',
        'A+',
        'Tăng huyết áp vô căn 5 năm, thoái hóa khớp gối',
        0,
        now,
        now,
        `fam-child-${primaryPatientId}`,
        primaryPatientId,
        'Nguyễn Minh Khang',
        'child',
        '2018-05-10',
        'Nam',
        '0912345678',
        'TE1791234567800',
        '079218009876',
        'O+',
        'Dị ứng nhẹ với kháng sinh Amoxicillin',
        0,
        now,
        now,
      ],
    );

    rows = await all(
      'SELECT * FROM family_members WHERE primary_patient_id = ? ORDER BY is_default DESC, created_at ASC',
      [primaryPatientId],
    );
  }

  return rows;
}

export async function getMemberById(id) {
  return get('SELECT * FROM family_members WHERE id = ?', [id]);
}

export async function createMember(data) {
  if (!data.primary_patient_id || !data.full_name || !data.relationship) {
    throw new Error('Thiếu thông tin bắt buộc: primary_patient_id, full_name, relationship');
  }

  const id = data.id || `fam-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
  const now = new Date().toISOString();
  const isDefault = data.is_default ? 1 : 0;

  if (isDefault) {
    await run(
      'UPDATE family_members SET is_default = 0, updated_at = ? WHERE primary_patient_id = ?',
      [now, data.primary_patient_id],
    );
  }

  await run(
    `INSERT INTO family_members (
      id, primary_patient_id, full_name, relationship, date_of_birth, gender,
      phone, bhyt_code, identity_card, blood_type, medical_history, avatar, is_default, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      data.primary_patient_id,
      data.full_name.trim(),
      data.relationship,
      data.date_of_birth || null,
      data.gender || 'Nam',
      data.phone || null,
      data.bhyt_code ? data.bhyt_code.trim().toUpperCase() : null,
      data.identity_card || null,
      data.blood_type || null,
      data.medical_history || null,
      data.avatar || null,
      isDefault,
      now,
      now,
    ],
  );

  return getMemberById(id);
}

export async function updateMember(id, data) {
  const existing = await getMemberById(id);
  if (!existing) return null;

  const now = new Date().toISOString();

  if (data.is_default) {
    await run(
      'UPDATE family_members SET is_default = 0, updated_at = ? WHERE primary_patient_id = ?',
      [now, existing.primary_patient_id],
    );
  }

  const fullName = data.full_name !== undefined ? data.full_name.trim() : existing.full_name;
  const relationship = data.relationship !== undefined ? data.relationship : existing.relationship;
  const dob = data.date_of_birth !== undefined ? data.date_of_birth : existing.date_of_birth;
  const gender = data.gender !== undefined ? data.gender : existing.gender;
  const phone = data.phone !== undefined ? data.phone : existing.phone;
  const bhyt = data.bhyt_code !== undefined ? data.bhyt_code.trim().toUpperCase() : existing.bhyt_code;
  const cccd = data.identity_card !== undefined ? data.identity_card : existing.identity_card;
  const bloodType = data.blood_type !== undefined ? data.blood_type : existing.blood_type;
  const history = data.medical_history !== undefined ? data.medical_history : existing.medical_history;
  const isDefault = data.is_default !== undefined ? (data.is_default ? 1 : 0) : existing.is_default;

  await run(
    `UPDATE family_members
     SET full_name = ?, relationship = ?, date_of_birth = ?, gender = ?, phone = ?,
         bhyt_code = ?, identity_card = ?, blood_type = ?, medical_history = ?,
         is_default = ?, updated_at = ?
     WHERE id = ?`,
    [fullName, relationship, dob, gender, phone, bhyt, cccd, bloodType, history, isDefault, now, id],
  );

  return getMemberById(id);
}

export async function deleteMember(id) {
  const member = await getMemberById(id);
  if (!member) return false;

  if (member.relationship === 'self') {
    throw new Error('Không thể xóa hồ sơ cá nhân của chính bạn.');
  }

  await run('DELETE FROM family_members WHERE id = ?', [id]);
  return true;
}

export async function setDefaultMember(primaryPatientId, memberId) {
  const now = new Date().toISOString();
  await run('UPDATE family_members SET is_default = 0, updated_at = ? WHERE primary_patient_id = ?', [
    now,
    primaryPatientId,
  ]);
  await run('UPDATE family_members SET is_default = 1, updated_at = ? WHERE id = ?', [now, memberId]);
  return getMemberById(memberId);
}
