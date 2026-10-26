import 'package:flutter/material.dart';

/// Trạng thái cờ đánh dấu chỉ số xét nghiệm theo khoảng tham chiếu
enum LabMetricStatus {
  normal, // Bình thường (Xanh lá)
  high,   // Cao hơn bình thường (Đỏ)
  low,    // Thấp hơn bình thường (Vàng)
}

extension LabMetricStatusX on LabMetricStatus {
  String get label => switch (this) {
        LabMetricStatus.normal => 'Bình thường',
        LabMetricStatus.high => 'Cao',
        LabMetricStatus.low => 'Thấp',
      };

  Color get color => switch (this) {
        LabMetricStatus.normal => const Color(0xFF16A34A), // Xanh lá
        LabMetricStatus.high => const Color(0xFFDC2626),   // Đỏ
        LabMetricStatus.low => const Color(0xFFD97706),    // Vàng cam
      };

  Color get backgroundColor => switch (this) {
        LabMetricStatus.normal => const Color(0xFFDCFCE7),
        LabMetricStatus.high => const Color(0xFFFEE2E2),
        LabMetricStatus.low => const Color(0xFFFEF3C7),
      };

  IconData get icon => switch (this) {
        LabMetricStatus.normal => Icons.check_circle_outline_rounded,
        LabMetricStatus.high => Icons.arrow_upward_rounded,
        LabMetricStatus.low => Icons.arrow_downward_rounded,
      };
}

/// Một chỉ số xét nghiệm cụ thể trong bảng kết quả
class LabTestMetric {
  const LabTestMetric({
    required this.id,
    required this.name,
    required this.category, // 'Sinh hóa máu', 'Huyết học', 'Miễn dịch', 'Nước tiểu'
    required this.value,
    required this.unit,
    required this.referenceRange,
    required this.status,
    this.clinicalInterpretation,
  });

  final String id;
  final String name;
  final String category;
  final double value;
  final String unit;
  final String referenceRange;
  final LabMetricStatus status;
  final String? clinicalInterpretation;

  factory LabTestMetric.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] as String? ?? 'normal').toLowerCase();
    final status = switch (statusStr) {
      'high' => LabMetricStatus.high,
      'low' => LabMetricStatus.low,
      _ => LabMetricStatus.normal,
    };

    return LabTestMetric(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'Sinh hóa máu',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      referenceRange: json['referenceRange'] as String? ?? '',
      status: status,
      clinicalInterpretation: json['clinicalInterpretation'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'value': value,
        'unit': unit,
        'referenceRange': referenceRange,
        'status': status.name,
        'clinicalInterpretation': clinicalInterpretation,
      };
}

/// Một hình ảnh Chẩn đoán hình ảnh (X-quang, ECG, Siêu âm, CT, Nội soi)
class ImagingItem {
  const ImagingItem({
    required this.id,
    required this.modality, // 'X-Ray', 'ECG', 'Ultrasound', 'CT-Scan', 'Endoscopy'
    required this.title,
    required this.description,
    required this.findings,
    required this.capturedDate,
    required this.performingDoctor,
    this.imageUrl,
    this.svgPathType = 'chest_xray', // 'chest_xray', 'ecg_strip', 'echocardiogram'
  });

  final String id;
  final String modality;
  final String title;
  final String description;
  final String findings;
  final String capturedDate;
  final String performingDoctor;
  final String? imageUrl;
  final String svgPathType;

  factory ImagingItem.fromJson(Map<String, dynamic> json) => ImagingItem(
        id: json['id'] as String? ?? '',
        modality: json['modality'] as String? ?? 'X-Ray',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        findings: json['findings'] as String? ?? '',
        capturedDate: json['capturedDate'] as String? ?? '',
        performingDoctor: json['performingDoctor'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        svgPathType: json['svgPathType'] as String? ?? 'chest_xray',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'modality': modality,
        'title': title,
        'description': description,
        'findings': findings,
        'capturedDate': capturedDate,
        'performingDoctor': performingDoctor,
        'imageUrl': imageUrl,
        'svgPathType': svgPathType,
      };
}

/// Báo cáo tổng thể kết quả Cận lâm sàng & Chẩn đoán hình ảnh
class LabReport {
  const LabReport({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.doctorName,
    required this.department,
    required this.sampleDate,
    required this.reportDate,
    required this.diagnostician,
    required this.generalConclusion,
    required this.metrics,
    required this.imagingList,
  });

  final String id;
  final String appointmentId;
  final String patientId;
  final String patientName;
  final String doctorName;
  final String department;
  final String sampleDate;
  final String reportDate;
  final String diagnostician; // Bác sĩ Cận lâm sàng đọc kết quả
  final String generalConclusion;
  final List<LabTestMetric> metrics;
  final List<ImagingItem> imagingList;

  int get highMetricCount =>
      metrics.where((m) => m.status == LabMetricStatus.high).length;
  int get lowMetricCount =>
      metrics.where((m) => m.status == LabMetricStatus.low).length;
  int get normalMetricCount =>
      metrics.where((m) => m.status == LabMetricStatus.normal).length;

  factory LabReport.fromJson(Map<String, dynamic> json) => LabReport(
        id: json['id'] as String? ?? '',
        appointmentId: json['appointmentId'] as String? ?? '',
        patientId: json['patientId'] as String? ?? '',
        patientName: json['patientName'] as String? ?? '',
        doctorName: json['doctorName'] as String? ?? '',
        department: json['department'] as String? ?? '',
        sampleDate: json['sampleDate'] as String? ?? '',
        reportDate: json['reportDate'] as String? ?? '',
        diagnostician: json['diagnostician'] as String? ?? '',
        generalConclusion: json['generalConclusion'] as String? ?? '',
        metrics: (json['metrics'] as List<dynamic>? ?? [])
            .map((e) => LabTestMetric.fromJson(e as Map<String, dynamic>))
            .toList(),
        imagingList: (json['imagingList'] as List<dynamic>? ?? [])
            .map((e) => ImagingItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'appointmentId': appointmentId,
        'patientId': patientId,
        'patientName': patientName,
        'doctorName': doctorName,
        'department': department,
        'sampleDate': sampleDate,
        'reportDate': reportDate,
        'diagnostician': diagnostician,
        'generalConclusion': generalConclusion,
        'metrics': metrics.map((e) => e.toJson()).toList(),
        'imagingList': imagingList.map((e) => e.toJson()).toList(),
      };
}
