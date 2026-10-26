import { run, get, all } from '../database/db.js';

export class SqliteHealthVitalsRepository {
  /**
   * Evaluate Blood Pressure according to WHO / VN Ministry of Health guidelines
   */
  evaluateBloodPressure(systolic, diastolic) {
    const sys = Number(systolic);
    const dia = Number(diastolic);

    if (sys >= 160 || dia >= 100) {
      return {
        status: 'danger',
        note: 'Tăng huyết áp độ 2 (Nguy cơ cao - Cần can thiệp y tế)',
        category: 'hypertension_stage_2',
      };
    }
    if (sys >= 140 || dia >= 90) {
      return {
        status: 'danger',
        note: 'Tăng huyết áp độ 1 (Vượt ngưỡng an toàn)',
        category: 'hypertension_stage_1',
      };
    }
    if (sys >= 120 || dia >= 80) {
      return {
        status: 'warning',
        note: 'Tiền tăng huyết áp (Cần theo dõi chế độ ăn & tập luyện)',
        category: 'prehypertension',
      };
    }
    if (sys >= 90 && dia >= 60) {
      return {
        status: 'optimal',
        note: 'Huyết áp chuẩn tối ưu (Bình thường)',
        category: 'optimal',
      };
    }
    return {
      status: 'warning',
      note: 'Huyết áp thấp (Chú ý bù nước và nghỉ ngơi)',
      category: 'low',
    };
  }

  /**
   * Calculate BMI = weight (kg) / [height (m)]^2
   */
  calculateBmi(weight, height) {
    const w = Number(weight);
    const h = Number(height);
    if (!w || !h || h <= 0) return null;
    const heightInMeters = h > 3 ? h / 100 : h; // Handles cm or m
    const bmi = w / (heightInMeters * heightInMeters);
    return Math.round(bmi * 10) / 10;
  }

  toDomain(row) {
    if (!row) return null;
    return {
      id: row.id,
      patientId: row.patient_id,
      appointmentId: row.appointment_id || null,
      systolic: row.systolic,
      diastolic: row.diastolic,
      heartRate: row.heart_rate || null,
      bloodSugar: row.blood_sugar !== null ? Number(row.blood_sugar) : null,
      bloodSugarCondition: row.blood_sugar_condition || 'fasting',
      weight: row.weight !== null ? Number(row.weight) : null,
      height: row.height !== null ? Number(row.height) : null,
      bmi: row.bmi !== null ? Number(row.bmi) : null,
      healthStatus: row.health_status || 'optimal',
      healthNote: row.health_note || '',
      note: row.note || '',
      recordedBy: row.recorded_by || 'patient',
      recordedAt: row.recorded_at,
      createdAt: row.created_at,
    };
  }

  async recordVitals(data) {
    const now = new Date().toISOString();
    const id = data.id || `VIT-${Date.now()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`;

    const systolic = Number(data.systolic);
    const diastolic = Number(data.diastolic);
    if (!systolic || !diastolic || systolic < 50 || systolic > 250 || diastolic < 30 || diastolic > 180) {
      throw new Error('Chỉ số huyết áp không hợp lệ (Tâm thu: 50-250, Tâm trương: 30-180)');
    }

    const bpEval = this.evaluateBloodPressure(systolic, diastolic);
    const bmi = data.bmi !== undefined && data.bmi !== null
      ? Number(data.bmi)
      : this.calculateBmi(data.weight, data.height);

    const recordedAt = data.recordedAt || now;

    await run(
      `INSERT INTO health_vitals (
        id, patient_id, appointment_id, systolic, diastolic, heart_rate,
        blood_sugar, blood_sugar_condition, weight, height, bmi,
        health_status, health_note, note, recorded_by, recorded_at, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        data.patientId,
        data.appointmentId || null,
        systolic,
        diastolic,
        data.heartRate ? Number(data.heartRate) : null,
        data.bloodSugar !== undefined && data.bloodSugar !== null ? Number(data.bloodSugar) : null,
        data.bloodSugarCondition || 'fasting',
        data.weight !== undefined && data.weight !== null ? Number(data.weight) : null,
        data.height !== undefined && data.height !== null ? Number(data.height) : null,
        bmi,
        bpEval.status,
        bpEval.note,
        data.note || '',
        data.recordedBy || 'patient',
        recordedAt,
        now,
      ]
    );

    return this.getVitalById(id);
  }

  async getVitalById(id) {
    const row = await get('SELECT * FROM health_vitals WHERE id = ?', [id]);
    return this.toDomain(row);
  }

  async getVitalsHistory(patientId, { limit = 30, days = 30 } = {}) {
    let sql = 'SELECT * FROM health_vitals WHERE patient_id = ?';
    const params = [patientId];

    if (days) {
      const d = new Date();
      d.setDate(d.getDate() - days);
      sql += ' AND recorded_at >= ?';
      params.push(d.toISOString());
    }

    sql += ' ORDER BY recorded_at ASC LIMIT ?';
    params.push(limit);

    const rows = await all(sql, params);
    return rows.map((r) => this.toDomain(r));
  }

  async getLatestVitals(patientId) {
    const row = await get(
      'SELECT * FROM health_vitals WHERE patient_id = ? ORDER BY recorded_at DESC LIMIT 1',
      [patientId]
    );
    return this.toDomain(row);
  }

  async getVitalsSummary(patientId) {
    const latest = await this.getLatestVitals(patientId);

    const stats = await get(
      `SELECT 
        AVG(systolic) as avg_systolic,
        AVG(diastolic) as avg_diastolic,
        AVG(heart_rate) as avg_heart_rate,
        AVG(blood_sugar) as avg_blood_sugar,
        AVG(bmi) as avg_bmi,
        COUNT(*) as total_records,
        SUM(CASE WHEN health_status = 'danger' THEN 1 ELSE 0 END) as danger_count,
        SUM(CASE WHEN health_status = 'warning' THEN 1 ELSE 0 END) as warning_count
      FROM health_vitals
      WHERE patient_id = ?`,
      [patientId]
    );

    return {
      latest,
      totalRecords: stats?.total_records || 0,
      avgSystolic: stats?.avg_systolic ? Math.round(stats.avg_systolic) : null,
      avgDiastolic: stats?.avg_diastolic ? Math.round(stats.avg_diastolic) : null,
      avgHeartRate: stats?.avg_heart_rate ? Math.round(stats.avg_heart_rate) : null,
      avgBloodSugar: stats?.avg_blood_sugar ? Math.round(stats.avg_blood_sugar * 10) / 10 : null,
      avgBmi: stats?.avg_bmi ? Math.round(stats.avg_bmi * 10) / 10 : null,
      dangerCount: stats?.danger_count || 0,
      warningCount: stats?.warning_count || 0,
    };
  }

  async deleteVital(id) {
    await run('DELETE FROM health_vitals WHERE id = ?', [id]);
    return true;
  }

  /**
   * Seed realistic 10-day history for demo
   */
  async seedDefaultVitals(patientId) {
    const existing = await this.getLatestVitals(patientId);
    if (existing) return;

    const baseDate = new Date();
    // 7 measurements showing improvement
    const samples = [
      { daysAgo: 9, sys: 146, dia: 94, hr: 84, bs: 6.8, w: 68.0, h: 170, by: 'patient' },
      { daysAgo: 7, sys: 142, dia: 90, hr: 80, bs: 6.5, w: 67.8, h: 170, by: 'clinic' },
      { daysAgo: 5, sys: 135, dia: 86, hr: 78, bs: 6.1, w: 67.5, h: 170, by: 'patient' },
      { daysAgo: 4, sys: 130, dia: 84, hr: 76, bs: 5.9, w: 67.4, h: 170, by: 'patient' },
      { daysAgo: 2, sys: 126, dia: 82, hr: 74, bs: 5.7, w: 67.0, h: 170, by: 'patient' },
      { daysAgo: 1, sys: 122, dia: 80, hr: 72, bs: 5.6, w: 66.8, h: 170, by: 'patient' },
      { daysAgo: 0, sys: 118, dia: 78, hr: 70, bs: 5.5, w: 66.5, h: 170, by: 'patient' },
    ];

    for (const s of samples) {
      const d = new Date(baseDate);
      d.setDate(d.getDate() - s.daysAgo);
      d.setHours(7, 30, 0, 0);

      await this.recordVitals({
        patientId,
        systolic: s.sys,
        diastolic: s.dia,
        heartRate: s.hr,
        bloodSugar: s.bs,
        bloodSugarCondition: 'fasting',
        weight: s.w,
        height: s.h,
        recordedBy: s.by,
        recordedAt: d.toISOString(),
        note: s.by === 'clinic' ? 'Đo tại phòng tiếp đón khám' : 'Tự đo tại nhà buổi sáng trước ăn',
      });
    }
  }
}
