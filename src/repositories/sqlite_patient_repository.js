import * as db from '../database/db.js';

let failure;

const toDomain = (row) => {
  if (!row) return undefined;
  return {
    patientId: row.patient_id,
    cognitoUserId: row.cognito_user_id,
    name: row.name,
    email: row.email,
    phone: row.phone,
    dateOfBirth: row.date_of_birth,
    gender: row.gender,
    address: row.address,
    emergencyContactName: row.emergency_contact_name || '',
    emergencyContactPhone: row.emergency_contact_phone || '',
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};

export const getPatient = async (patientId) => {
  if (failure) throw failure;
  const row = await db.get(
    'SELECT * FROM patients WHERE cognito_user_id = ? OR patient_id = ?',
    [patientId, patientId],
  );
  return toDomain(row);
};

export const putPatient = async (patientId, profile) => {
  if (failure) throw failure;
  const now = new Date().toISOString();
  const current = await getPatient(patientId);

  const cognitoUserId = profile.cognitoUserId || patientId;
  const patientRecordId =
    profile.patientId || (current ? current.patientId : patientId);

  if (!current) {
    await db.run(
      `INSERT INTO patients (
        cognito_user_id, patient_id, name, email, phone, date_of_birth, gender, address,
        emergency_contact_name, emergency_contact_phone, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        cognitoUserId,
        patientRecordId,
        profile.name,
        profile.email || `${cognitoUserId}@hospital.com`,
        profile.phone || '',
        profile.dateOfBirth || '1990-01-01',
        profile.gender || 'Khác',
        profile.address || '',
        profile.emergencyContactName || '',
        profile.emergencyContactPhone || '',
        profile.createdAt || now,
        now,
      ],
    );
  } else {
    await db.run(
      `UPDATE patients SET
        name = COALESCE(?, name),
        phone = COALESCE(?, phone),
        date_of_birth = COALESCE(?, date_of_birth),
        gender = COALESCE(?, gender),
        address = COALESCE(?, address),
        emergency_contact_name = COALESCE(?, emergency_contact_name),
        emergency_contact_phone = COALESCE(?, emergency_contact_phone),
        updated_at = ?
       WHERE cognito_user_id = ?`,
      [
        profile.name,
        profile.phone,
        profile.dateOfBirth,
        profile.gender,
        profile.address,
        profile.emergencyContactName,
        profile.emergencyContactPhone,
        now,
        cognitoUserId,
      ],
    );
  }

  return await getPatient(cognitoUserId);
};

export const resetPatients = async () => {
  failure = undefined;
  await db.run('DELETE FROM patients');
};

export const failPatientStore = () => {
  failure = new Error('Database connection failure');
};
