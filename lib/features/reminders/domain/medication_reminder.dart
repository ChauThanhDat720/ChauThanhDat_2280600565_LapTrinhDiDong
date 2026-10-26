enum DoseStatus {
  pending('Chưa uống'),
  taken('Đã uống'),
  skipped('Bỏ qua');

  const DoseStatus(this.label);
  final String label;

  static DoseStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'taken':
        return DoseStatus.taken;
      case 'skipped':
        return DoseStatus.skipped;
      default:
        return DoseStatus.pending;
    }
  }

  String toServerString() {
    switch (this) {
      case DoseStatus.taken:
        return 'taken';
      case DoseStatus.skipped:
        return 'skipped';
      case DoseStatus.pending:
        return 'pending';
    }
  }
}

class MedicationReminder {
  const MedicationReminder({
    required this.id,
    required this.patientId,
    this.appointmentId,
    required this.medicineName,
    this.dosage = '1 viên',
    this.instructions = '',
    this.timesPerDay = 2,
    this.reminderTimes = const ['08:00', '20:00'],
    required this.startDate,
    this.daysCount = 5,
    required this.endDate,
    this.colorCode = '#0D9488',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String patientId;
  final String? appointmentId;
  final String medicineName;
  final String dosage;
  final String instructions;
  final int timesPerDay;
  final List<String> reminderTimes;
  final DateTime startDate;
  final int daysCount;
  final DateTime endDate;
  final String colorCode;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MedicationReminder copyWith({
    String? id,
    String? patientId,
    String? appointmentId,
    String? medicineName,
    String? dosage,
    String? instructions,
    int? timesPerDay,
    List<String>? reminderTimes,
    DateTime? startDate,
    int? daysCount,
    DateTime? endDate,
    String? colorCode,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicationReminder(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      appointmentId: appointmentId ?? this.appointmentId,
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      instructions: instructions ?? this.instructions,
      timesPerDay: timesPerDay ?? this.timesPerDay,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      startDate: startDate ?? this.startDate,
      daysCount: daysCount ?? this.daysCount,
      endDate: endDate ?? this.endDate,
      colorCode: colorCode ?? this.colorCode,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MedicationReminder.fromJson(Map<String, dynamic> json) {
    List<String> times = [];
    if (json['reminderTimes'] is List) {
      times = (json['reminderTimes'] as List).map((e) => e.toString()).toList();
    } else if (json['reminder_times'] != null) {
      if (json['reminder_times'] is List) {
        times = (json['reminder_times'] as List).map((e) => e.toString()).toList();
      }
    }
    if (times.isEmpty) times = ['08:00', '20:00'];

    return MedicationReminder(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patientId'] ?? json['patient_id'] ?? '').toString(),
      appointmentId: json['appointmentId'] != null ? json['appointmentId'].toString() : (json['appointment_id']?.toString()),
      medicineName: (json['medicineName'] ?? json['medicine_name'] ?? '').toString(),
      dosage: (json['dosage'] ?? '1 viên').toString(),
      instructions: (json['instructions'] ?? '').toString(),
      timesPerDay: json['timesPerDay'] is int ? json['timesPerDay'] as int : (json['times_per_day'] is int ? json['times_per_day'] as int : 2),
      reminderTimes: times,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate'].toString()) : (json['start_date'] != null ? DateTime.parse(json['start_date'].toString()) : DateTime.now()),
      daysCount: json['daysCount'] is int ? json['daysCount'] as int : (json['days_count'] is int ? json['days_count'] as int : 5),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'].toString()) : (json['end_date'] != null ? DateTime.parse(json['end_date'].toString()) : DateTime.now().add(const Duration(days: 5))),
      colorCode: (json['colorCode'] ?? json['color_code'] ?? '#0D9488').toString(),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : (json['is_active'] == 1 || json['is_active'] == true),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'appointmentId': appointmentId,
        'medicineName': medicineName,
        'dosage': dosage,
        'instructions': instructions,
        'timesPerDay': timesPerDay,
        'reminderTimes': reminderTimes,
        'startDate': startDate.toIso8601String().substring(0, 10),
        'daysCount': daysCount,
        'endDate': endDate.toIso8601String().substring(0, 10),
        'colorCode': colorCode,
        'isActive': isActive,
      };
}

class MedicationDoseLog {
  const MedicationDoseLog({
    required this.id,
    required this.reminderId,
    required this.medicineName,
    required this.dosage,
    this.instructions = '',
    required this.date,
    required this.time,
    this.status = DoseStatus.pending,
    this.takenAt,
    this.note,
    this.colorCode = '#0D9488',
  });

  final String id;
  final String reminderId;
  final String medicineName;
  final String dosage;
  final String instructions;
  final String date;
  final String time;
  final DoseStatus status;
  final DateTime? takenAt;
  final String? note;
  final String colorCode;

  MedicationDoseLog copyWith({
    String? id,
    String? reminderId,
    String? medicineName,
    String? dosage,
    String? instructions,
    String? date,
    String? time,
    DoseStatus? status,
    DateTime? takenAt,
    String? note,
    String? colorCode,
  }) {
    return MedicationDoseLog(
      id: id ?? this.id,
      reminderId: reminderId ?? this.reminderId,
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      instructions: instructions ?? this.instructions,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      takenAt: takenAt ?? this.takenAt,
      note: note ?? this.note,
      colorCode: colorCode ?? this.colorCode,
    );
  }

  factory MedicationDoseLog.fromJson(Map<String, dynamic> json) {
    return MedicationDoseLog(
      id: (json['id'] ?? json['log_id'] ?? '').toString(),
      reminderId: (json['reminderId'] ?? json['reminder_id'] ?? '').toString(),
      medicineName: (json['medicineName'] ?? json['medicine_name'] ?? '').toString(),
      dosage: (json['dosage'] ?? '1 viên').toString(),
      instructions: (json['instructions'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      time: (json['time'] ?? '08:00').toString(),
      status: DoseStatus.fromString(json['status']?.toString()),
      takenAt: json['takenAt'] != null ? DateTime.tryParse(json['takenAt'].toString()) : (json['taken_at'] != null ? DateTime.tryParse(json['taken_at'].toString()) : null),
      note: json['note']?.toString(),
      colorCode: (json['colorCode'] ?? json['color_code'] ?? '#0D9488').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reminderId': reminderId,
        'medicineName': medicineName,
        'dosage': dosage,
        'instructions': instructions,
        'date': date,
        'time': time,
        'status': status.toServerString(),
        'takenAt': takenAt?.toIso8601String(),
        'note': note,
        'colorCode': colorCode,
      };
}

class ComplianceStats {
  const ComplianceStats({
    this.days = 7,
    this.total = 0,
    this.taken = 0,
    this.skipped = 0,
    this.pending = 0,
    this.complianceRate = 100,
  });

  final int days;
  final int total;
  final int taken;
  final int skipped;
  final int pending;
  final int complianceRate;

  factory ComplianceStats.fromJson(Map<String, dynamic> json) {
    return ComplianceStats(
      days: json['days'] is int ? json['days'] as int : 7,
      total: json['total'] is int ? json['total'] as int : 0,
      taken: json['taken'] is int ? json['taken'] as int : 0,
      skipped: json['skipped'] is int ? json['skipped'] as int : 0,
      pending: json['pending'] is int ? json['pending'] as int : 0,
      complianceRate: json['complianceRate'] is int ? json['complianceRate'] as int : 100,
    );
  }
}
