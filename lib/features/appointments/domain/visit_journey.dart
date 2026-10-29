/// Progress reported by the doctor and patient, independently of booking status.
class VisitJourney {
  const VisitJourney({
    this.stage = 'waiting',
    this.message = '',
    this.labOrder,
    this.labResultNote,
    this.paymentSimulatedAt,
    this.medicinesReceivedAt,
  });

  final String stage, message;
  final String? labOrder,
      labResultNote,
      paymentSimulatedAt,
      medicinesReceivedAt;
  bool get hasLabOrder => labOrder?.isNotEmpty == true;
  bool get labReviewed =>
      ['lab_completed', 'prescribed', 'finished'].contains(stage) &&
      hasLabOrder;
  bool get prescribed => ['prescribed', 'finished'].contains(stage);
  bool get paymentSimulated => paymentSimulatedAt != null;
  bool get medicinesReceived => medicinesReceivedAt != null;
  String get label => switch (stage) {
    'consulting' => 'Bác sĩ đang khám',
    'lab_ordered' => 'Đã có chỉ định cận lâm sàng',
    'lab_reported' => 'Chờ bác sĩ xem kết quả',
    'lab_completed' => 'Bác sĩ đã xem kết quả',
    'prescribed' => 'Đã có đơn thuốc',
    'finished' => 'Đã nhận thuốc',
    _ => 'Đang chờ bác sĩ gọi',
  };

  factory VisitJourney.fromJson(Map<String, dynamic> json) => VisitJourney(
    stage: json['stage'] as String? ?? 'waiting',
    message: json['message'] as String? ?? '',
    labOrder: json['labOrder'] as String?,
    labResultNote: json['labResultNote'] as String?,
    paymentSimulatedAt: json['paymentSimulatedAt'] as String?,
    medicinesReceivedAt: json['medicinesReceivedAt'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'stage': stage,
    'message': message,
    'labOrder': labOrder,
    'labResultNote': labResultNote,
    'paymentSimulatedAt': paymentSimulatedAt,
    'medicinesReceivedAt': medicinesReceivedAt,
  };
}
