import { all, get, run } from '../database/db.js';

const toDomain = (row) => {
  if (!row) return null;
  return {
    id: row.id,
    patientId: row.patient_id,
    familyMemberId: row.family_member_id || 'fam-self',
    patientName: row.patient_name,
    vaccineName: row.vaccine_name,
    targetDisease: row.target_disease,
    doseNumber: row.dose_number,
    totalDoses: row.total_doses,
    batchNumber: row.batch_number,
    manufacturer: row.manufacturer,
    administeredDate: row.administered_date,
    nextDoseDate: row.next_dose_date || null,
    facilityName: row.facility_name,
    doctorName: row.doctor_name,
    nurseName: row.nurse_name || null,
    reactionStatus: row.reaction_status || 'Bình thường, không sốt, không phản ứng phụ',
    certificateCode: row.certificate_code,
    status: row.status || 'completed',
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};

export const getVaccinations = async ({ patientId, familyMemberId }) => {
  let query = 'SELECT * FROM vaccinations';
  const params = [];
  const conditions = [];

  if (patientId) {
    conditions.push('patient_id = ?');
    params.push(patientId);
  }
  if (familyMemberId) {
    conditions.push('family_member_id = ?');
    params.push(familyMemberId);
  }

  if (conditions.length > 0) {
    query += ` WHERE ${conditions.join(' AND ')}`;
  }
  query += ' ORDER BY administered_date DESC, created_at DESC';

  const rows = await all(query, params);
  return rows.map(toDomain);
};

export const getVaccinationById = async (id) => {
  const row = await get('SELECT * FROM vaccinations WHERE id = ?', [id]);
  return toDomain(row);
};

export const getVaccinationByCertificateCode = async (code) => {
  const row = await get('SELECT * FROM vaccinations WHERE certificate_code = ?', [code]);
  return toDomain(row);
};

export const getUpcomingDoses = async (patientId) => {
  const now = new Date().toISOString().slice(0, 10);
  const rows = await all(
    `SELECT * FROM vaccinations 
     WHERE patient_id = ? AND next_dose_date IS NOT NULL AND next_dose_date >= ?
     ORDER BY next_dose_date ASC`,
    [patientId, now],
  );
  return rows.map(toDomain);
};

export const createVaccination = async (data) => {
  const id = data.id || `vac-${Date.now()}`;
  const now = new Date().toISOString();
  const certCode = data.certificateCode || `VAC-${new Date().getFullYear()}-VN-${Math.floor(10000 + Math.random() * 90000)}`;

  await run(
    `INSERT INTO vaccinations (
      id, patient_id, family_member_id, patient_name, vaccine_name, target_disease,
      dose_number, total_doses, batch_number, manufacturer, administered_date, next_dose_date,
      facility_name, doctor_name, nurse_name, reaction_status, certificate_code, status, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      data.patientId || 'test-patient-sub-123',
      data.familyMemberId || 'fam-self',
      data.patientName || 'Nguyễn Văn An',
      data.vaccineName,
      data.targetDisease,
      data.doseNumber || 1,
      data.totalDoses || 3,
      data.batchNumber || 'BATCH-DEFAULT',
      data.manufacturer || 'Quốc tế',
      data.administeredDate || now.slice(0, 10),
      data.nextDoseDate || null,
      data.facilityName || 'Bệnh viện Đa khoa Quốc tế Smart Hospital',
      data.doctorName || 'BS. Trần Thảo Linh',
      data.nurseName || 'ĐD. Lê Thị Hồng',
      data.reactionStatus || 'Bình thường, không sốt, không phản ứng phụ',
      certCode,
      data.status || 'completed',
      now,
      now,
    ],
  );

  return getVaccinationById(id);
};

export const getVaccineProtocols = () => {
  return [
    {
      ageGroup: '0 - 12 tuổi (Trẻ sơ sinh & Trẻ nhỏ)',
      vaccines: [
        {
          name: 'Vắc-xin Lao (BCG)',
          target: 'Lao màng não & lao phổi sơ sinh',
          schedule: '1 mũi duy nhất trong 24-48h sau sinh',
          recommendedDoses: 1,
        },
        {
          name: 'Vắc-xin 6 trong 1 (Infanrix Hexa / Hexaxim)',
          target: 'Bạch hầu, Ho gà, Uốn ván, Bại liệt, Hib, Viêm gan B',
          schedule: '3 mũi lúc 2, 3, 4 tháng; nhắc mũi 4 lúc 16-18 tháng',
          recommendedDoses: 4,
        },
        {
          name: 'Vắc-xin Phế cầu khuẩn (Synflorix / Prevenar 13)',
          target: 'Viêm phổi, viêm tai giữa, viêm màng não do phế cầu',
          schedule: 'Lúc 2, 4, 6 tháng và mũi nhắc sau 1 tuổi',
          recommendedDoses: 4,
        },
        {
          name: 'Vắc-xin Sởi - Quai bị - Rubella (MMR)',
          target: 'Sởi, Quai bị, Rubella',
          schedule: 'Mũi 1 lúc 9-12 tháng, mũi 2 lúc 4-6 tuổi',
          recommendedDoses: 2,
        },
      ],
    },
    {
      ageGroup: '13 - 49 tuổi (Thanh thiếu niên & Người trưởng thành)',
      vaccines: [
        {
          name: 'Vắc-xin HPV 9 chủng (Gardasil 9)',
          target: 'Ung thư cổ tử cung, âm đạo, hậu môn và sùi mào gà',
          schedule: 'Phác đồ 3 mũi: 0 - 2 - 6 tháng (từ 9 đến 45 tuổi)',
          recommendedDoses: 3,
        },
        {
          name: 'Vắc-xin Cúm mùa tứ giá (Vaxigrip Tetra / Influvac Tetra)',
          target: 'Cúm mùa A (H1N1, H3N2) và Cúm B',
          schedule: 'Tiêm nhắc lại 1 mũi mỗi năm vào đầu mùa dịch',
          recommendedDoses: 1,
        },
        {
          name: 'Vắc-xin Viêm gan B (Engerix B / Euvax B)',
          target: 'Viêm gan B, xơ gan và ung thư tế bào gan',
          schedule: 'Phác đồ 0 - 1 - 6 tháng; kiểm tra kháng thể sau 5 năm',
          recommendedDoses: 3,
        },
        {
          name: 'Vắc-xin Uốn ván - Bạch hầu (Td / Adacel)',
          target: 'Uốn ván, Bạch hầu',
          schedule: 'Tiêm nhắc lại mỗi 10 năm/lần hoặc khi có vết thương',
          recommendedDoses: 1,
        },
      ],
    },
    {
      ageGroup: 'Phụ nữ chuẩn bị mang thai',
      vaccines: [
        {
          name: 'Vắc-xin Sởi - Quai bị - Rubella (MMR II)',
          target: 'Hội chứng Rubella bẩm sinh, quái thai',
          schedule: 'Hoàn tất trước khi có thai tối thiểu 3 tháng',
          recommendedDoses: 1,
        },
        {
          name: 'Vắc-xin Thủy đậu (Varivax / Varilrix)',
          target: 'Thủy đậu thai kỳ, dị tật bẩm sinh ở thai nhi',
          schedule: '2 mũi cách nhau 1 tháng, hoàn tất trước mang thai 3 tháng',
          recommendedDoses: 2,
        },
        {
          name: 'Vắc-xin Uốn ván thai phụ (VAT)',
          target: 'Uốn ván sơ sinh cho mẹ và con',
          schedule: '2 mũi trong thai kỳ (mũi 2 trước sinh tối thiểu 1 tháng)',
          recommendedDoses: 2,
        },
      ],
    },
    {
      ageGroup: 'Người cao tuổi & Bệnh nền tim mạch (≥ 50 tuổi)',
      vaccines: [
        {
          name: 'Vắc-xin Phế cầu 13 (Prevenar 13)',
          target: 'Viêm phổi cộng đồng, nhiễm khuẩn huyết phế cầu',
          schedule: '1 mũi duy nhất cho người lớn tuổi / suy tim, tăng huyết áp',
          recommendedDoses: 1,
        },
        {
          name: 'Vắc-xin Cúm mùa hàng năm (Vaxigrip Tetra)',
          target: 'Biến chứng tim mạch do cúm, suy tim cấp do nhiễm trùng',
          schedule: '1 mũi tiêm nhắc đều đặn mỗi năm',
          recommendedDoses: 1,
        },
        {
          name: 'Vắc-xin Zona thần kinh (Shingrix)',
          target: 'Đau dây thần kinh sau zona, biến chứng mắt',
          schedule: '2 mũi cách nhau 2-6 tháng cho người từ 50 tuổi trở lên',
          recommendedDoses: 2,
        },
      ],
    },
  ];
};
