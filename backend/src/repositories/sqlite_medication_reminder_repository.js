import { run, get, all } from '../database/db.js';

export class SqliteMedicationReminderRepository {
  /**
   * Helper to format Date to YYYY-MM-DD
   */
  _formatDate(date) {
    const d = new Date(date);
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${d.getFullYear()}-${month}-${day}`;
  }

  /**
   * Add days to YYYY-MM-DD string
   */
  _addDays(dateStr, days) {
    const d = new Date(dateStr);
    d.setDate(d.getDate() + days);
    return this._formatDate(d);
  }

  /**
   * Convert DB row to domain reminder
   */
  toDomain(row) {
    if (!row) return null;
    let reminderTimes = [];
    try {
      reminderTimes = typeof row.reminder_times === 'string'
        ? JSON.parse(row.reminder_times)
        : (row.reminder_times || []);
    } catch (_) {
      reminderTimes = ['08:00', '20:00'];
    }

    return {
      id: row.id,
      patientId: row.patient_id,
      appointmentId: row.appointment_id || null,
      medicineName: row.medicine_name,
      dosage: row.dosage,
      instructions: row.instructions || '',
      timesPerDay: row.times_per_day,
      reminderTimes,
      startDate: row.start_date,
      daysCount: row.days_count,
      endDate: row.end_date,
      colorCode: row.color_code || '#0D9488',
      isActive: Boolean(row.is_active),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  /**
   * Create a new medication reminder and generate daily schedule logs
   */
  async createReminder(data) {
    const now = new Date().toISOString();
    const id = data.id || `REM-${Date.now()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`;
    const timesPerDay = Number(data.timesPerDay) || 2;
    
    let reminderTimes = data.reminderTimes;
    if (!reminderTimes || !Array.isArray(reminderTimes) || reminderTimes.length === 0) {
      if (timesPerDay === 1) reminderTimes = ['08:00'];
      else if (timesPerDay === 2) reminderTimes = ['08:00', '20:00'];
      else if (timesPerDay === 3) reminderTimes = ['08:00', '13:00', '20:00'];
      else if (timesPerDay === 4) reminderTimes = ['07:00', '12:00', '17:00', '21:00'];
      else reminderTimes = ['08:00', '20:00'];
    }

    const startDate = data.startDate || this._formatDate(new Date());
    const daysCount = Number(data.daysCount) || 5;
    const endDate = data.endDate || this._addDays(startDate, daysCount - 1);
    const colorCode = data.colorCode || '#0D9488';
    const isActive = data.isActive !== undefined ? (data.isActive ? 1 : 0) : 1;

    await run(
      `INSERT INTO medication_reminders (
        id, patient_id, appointment_id, medicine_name, dosage, instructions,
        times_per_day, reminder_times, start_date, days_count, end_date,
        color_code, is_active, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        data.patientId,
        data.appointmentId || null,
        data.medicineName,
        data.dosage || '1 viên',
        data.instructions || '',
        timesPerDay,
        JSON.stringify(reminderTimes),
        startDate,
        daysCount,
        endDate,
        colorCode,
        isActive,
        now,
        now,
      ]
    );

    // Populate medication logs for each day and time
    for (let day = 0; day < daysCount; day++) {
      const curDate = this._addDays(startDate, day);
      for (const time of reminderTimes) {
        const logId = `LOG-${id}-${curDate}-${time.replace(':', '')}`;
        await run(
          `INSERT OR IGNORE INTO medication_logs (
            id, reminder_id, patient_id, date, time, status, created_at
          ) VALUES (?, ?, ?, ?, ?, 'pending', ?)`,
          [logId, id, data.patientId, curDate, time, now]
        );
      }
    }

    return this.getReminderById(id);
  }

  /**
   * 1-Click Parse from prescription text and create reminders
   */
  async createFromPrescription({ patientId, appointmentId, prescription, daysCount = 7 }) {
    if (!prescription || typeof prescription !== 'string') {
      return [];
    }

    // Split prescription by newlines or semicolons or commas
    const lines = prescription
      .split(/[\n;]+/)
      .map((l) => l.trim())
      .filter((l) => l.length > 2);

    const createdReminders = [];
    const colors = ['#0D9488', '#2563EB', '#7C3AED', '#DB2777', '#EA580C', '#059669'];

    let colorIdx = 0;
    for (const line of lines) {
      // Example line: "1. Paracetamol 500mg: 1 viên x 2 lần/ngày sau ăn"
      // or "Amoxicillin 500mg (1 viên x 3 lần/ngày)"
      const cleanLine = line.replace(/^\d+[\.\-\)]\s*/, '').trim();

      // Extract medicine name
      let medicineName = cleanLine;
      let extra = '';

      if (cleanLine.includes(':')) {
        const parts = cleanLine.split(':');
        medicineName = parts[0].trim();
        extra = parts.slice(1).join(':').trim();
      } else if (cleanLine.includes('(') && cleanLine.includes(')')) {
        const match = cleanLine.match(/^(.*?)\((.*?)\)/);
        if (match) {
          medicineName = match[1].trim();
          extra = match[2].trim();
        }
      } else if (cleanLine.includes('-')) {
        const parts = cleanLine.split('-');
        medicineName = parts[0].trim();
        extra = parts.slice(1).join('-').trim();
      }

      // Detect frequency
      let timesPerDay = 2;
      let reminderTimes = ['08:00', '20:00'];
      const extraLower = (extra + ' ' + cleanLine).toLowerCase();

      if (extraLower.includes('3 lần') || extraLower.includes('ba lần') || extraLower.includes('sáng, trưa, tối')) {
        timesPerDay = 3;
        reminderTimes = ['08:00', '13:00', '20:00'];
      } else if (extraLower.includes('4 lần') || extraLower.includes('bốn lần')) {
        timesPerDay = 4;
        reminderTimes = ['07:00', '12:00', '17:00', '21:00'];
      } else if (extraLower.includes('1 lần') || extraLower.includes('một lần')) {
        timesPerDay = 1;
        reminderTimes = ['08:00'];
      }

      // Extract dosage
      let dosage = '1 viên';
      const doseMatch = extraLower.match(/(\d+\s*(?:viên|gói|ml|giọt|ống))/);
      if (doseMatch) {
        dosage = doseMatch[1];
      }

      // Extract instruction (before/after meal)
      let instructions = 'Uống sau bữa ăn 30 phút';
      if (extraLower.includes('trước ăn') || extraLower.includes('trước bữa')) {
        instructions = 'Uống trước bữa ăn 30 phút';
      } else if (extraLower.includes('sau ăn') || extraLower.includes('sau bữa')) {
        instructions = 'Uống sau bữa ăn 30 phút';
      } else if (extraLower.includes('khi đói')) {
        instructions = 'Uống khi bụng đói với nhiều nước';
      } else if (extra.length > 0) {
        instructions = extra;
      }

      const reminder = await this.createReminder({
        patientId,
        appointmentId,
        medicineName,
        dosage,
        instructions,
        timesPerDay,
        reminderTimes,
        daysCount,
        colorCode: colors[colorIdx % colors.length],
      });

      createdReminders.push(reminder);
      colorIdx++;
    }

    return createdReminders;
  }

  async getReminderById(id) {
    const row = await get('SELECT * FROM medication_reminders WHERE id = ?', [id]);
    return this.toDomain(row);
  }

  async getReminders(patientId, { isActive } = {}) {
    let sql = 'SELECT * FROM medication_reminders WHERE patient_id = ?';
    const params = [patientId];

    if (isActive !== undefined) {
      sql += ' AND is_active = ?';
      params.push(isActive ? 1 : 0);
    }

    sql += ' ORDER BY created_at DESC';
    const rows = await all(sql, params);
    return rows.map((r) => this.toDomain(r));
  }

  async getTodayDoses(patientId, dateStr = this._formatDate(new Date())) {
    const sql = `
      SELECT 
        l.id AS log_id,
        l.reminder_id,
        l.date,
        l.time,
        l.status,
        l.taken_at,
        l.note,
        r.medicine_name,
        r.dosage,
        r.instructions,
        r.color_code,
        r.is_active
      FROM medication_logs l
      JOIN medication_reminders r ON l.reminder_id = r.id
      WHERE l.patient_id = ? AND l.date = ? AND r.is_active = 1
      ORDER BY l.time ASC, r.medicine_name ASC
    `;
    const rows = await all(sql, [patientId, dateStr]);

    return rows.map((row) => ({
      id: row.log_id,
      reminderId: row.reminder_id,
      medicineName: row.medicine_name,
      dosage: row.dosage,
      instructions: row.instructions || '',
      date: row.date,
      time: row.time,
      status: row.status, // 'pending' | 'taken' | 'skipped'
      takenAt: row.taken_at,
      note: row.note,
      colorCode: row.color_code || '#0D9488',
    }));
  }

  async updateDoseStatus(logId, { status, takenAt = new Date().toISOString(), note }) {
    await run(
      `UPDATE medication_logs
       SET status = ?, taken_at = ?, note = ?
       WHERE id = ?`,
      [status, status === 'taken' ? takenAt : null, note || null, logId]
    );

    const row = await get(
      `SELECT 
        l.id AS log_id,
        l.reminder_id,
        l.date,
        l.time,
        l.status,
        l.taken_at,
        l.note,
        r.medicine_name,
        r.dosage,
        r.instructions,
        r.color_code
      FROM medication_logs l
      JOIN medication_reminders r ON l.reminder_id = r.id
      WHERE l.id = ?`,
      [logId]
    );

    if (!row) return null;
    return {
      id: row.log_id,
      reminderId: row.reminder_id,
      medicineName: row.medicine_name,
      dosage: row.dosage,
      instructions: row.instructions || '',
      date: row.date,
      time: row.time,
      status: row.status,
      takenAt: row.taken_at,
      note: row.note,
      colorCode: row.color_code,
    };
  }

  async toggleReminder(reminderId, isActive) {
    const now = new Date().toISOString();
    await run(
      'UPDATE medication_reminders SET is_active = ?, updated_at = ? WHERE id = ?',
      [isActive ? 1 : 0, now, reminderId]
    );
    return this.getReminderById(reminderId);
  }

  async deleteReminder(reminderId) {
    await run('DELETE FROM medication_logs WHERE reminder_id = ?', [reminderId]);
    await run('DELETE FROM medication_reminders WHERE id = ?', [reminderId]);
    return true;
  }

  async getComplianceStats(patientId, { days = 7 } = {}) {
    const today = this._formatDate(new Date());
    const startDate = this._addDays(today, -days);

    const rows = await all(
      `SELECT status, COUNT(*) as count
       FROM medication_logs
       WHERE patient_id = ? AND date >= ? AND date <= ?
       GROUP BY status`,
      [patientId, startDate, today]
    );

    let taken = 0;
    let skipped = 0;
    let pending = 0;

    for (const r of rows) {
      if (r.status === 'taken') taken = r.count;
      else if (r.status === 'skipped') skipped = r.count;
      else if (r.status === 'pending') pending = r.count;
    }

    const total = taken + skipped + pending;
    const answered = taken + skipped;
    const complianceRate = answered > 0 ? Math.round((taken / answered) * 100) : 100;

    return {
      days,
      total,
      taken,
      skipped,
      pending,
      complianceRate,
    };
  }
}
