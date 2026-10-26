import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/medical_records/data/lab_repository.dart';
import 'package:smart_hospital/features/medical_records/domain/lab_result.dart';
import 'package:smart_hospital/features/medical_records/presentation/lab_results_detail_screen.dart';
import 'package:smart_hospital/features/medical_records/presentation/medical_imaging_viewer.dart';

void main() {
  group('Lab & Imaging Domain Models', () {
    test('LabMetricStatus maps colors, badges, and icons correctly', () {
      expect(LabMetricStatus.normal.label, 'Bình thường');
      expect(LabMetricStatus.normal.color, const Color(0xFF16A34A));

      expect(LabMetricStatus.high.label, 'Cao');
      expect(LabMetricStatus.high.color, const Color(0xFFDC2626));

      expect(LabMetricStatus.low.label, 'Thấp');
      expect(LabMetricStatus.low.color, const Color(0xFFD97706));
    });

    test('LabTestMetric json serialization and flag parsing', () {
      final jsonHigh = {
        'id': 'M-01',
        'name': 'Glucose máu lúc đói',
        'category': 'Sinh hóa máu',
        'value': 7.2,
        'unit': 'mmol/L',
        'referenceRange': '3.9 - 6.4',
        'status': 'high',
        'clinicalInterpretation': 'Tăng đường huyết lúc đói nhẹ',
      };

      final metric = LabTestMetric.fromJson(jsonHigh);
      expect(metric.name, 'Glucose máu lúc đói');
      expect(metric.value, 7.2);
      expect(metric.status, LabMetricStatus.high);
      expect(metric.clinicalInterpretation, contains('Tăng đường huyết'));

      final jsonOut = metric.toJson();
      expect(jsonOut['status'], 'high');
      expect(jsonOut['value'], 7.2);
    });

    test('LabReport aggregates high, low, and normal metric counters accurately', () {
      const report = LabReport(
        id: 'LAB-TEST',
        appointmentId: 'apt-001',
        patientId: 'patient-test',
        patientName: 'Nguyễn Văn Test',
        doctorName: 'BS. Trần Thảo Linh',
        department: 'Tim mạch',
        sampleDate: '26/10/2026 08:30',
        reportDate: '26/10/2026 10:00',
        diagnostician: 'BS. CĐHA Hoàng Minh Quân',
        generalConclusion: 'Tăng glucose và ALT nhẹ.',
        metrics: [
          LabTestMetric(
            id: '1',
            name: 'Glucose lúc đói',
            category: 'Sinh hóa máu',
            value: 7.2,
            unit: 'mmol/L',
            referenceRange: '3.9 - 6.4',
            status: LabMetricStatus.high,
          ),
          LabTestMetric(
            id: '2',
            name: 'Men gan ALT',
            category: 'Sinh hóa máu',
            value: 65.0,
            unit: 'U/L',
            referenceRange: '< 40.0',
            status: LabMetricStatus.high,
          ),
          LabTestMetric(
            id: '3',
            name: 'Creatinine',
            category: 'Sinh hóa máu',
            value: 76.0,
            unit: 'umol/L',
            referenceRange: '53 - 106',
            status: LabMetricStatus.normal,
          ),
          LabTestMetric(
            id: '4',
            name: 'WBC',
            category: 'Huyết học',
            value: 6.8,
            unit: 'G/L',
            referenceRange: '4.0 - 10.0',
            status: LabMetricStatus.normal,
          ),
          LabTestMetric(
            id: '5',
            name: 'Hemoglobin Hb',
            category: 'Huyết học',
            value: 105.0,
            unit: 'g/L',
            referenceRange: '120 - 165',
            status: LabMetricStatus.low,
          ),
        ],
        imagingList: [
          ImagingItem(
            id: 'IMG-1',
            modality: 'ECG',
            title: 'Điện tâm đồ ECG 12 chuyển đạo',
            description: 'Khảo sát nhịp',
            findings: 'Nhịp xoang đều tần số 78 bpm',
            capturedDate: '26/10/2026 lúc 09:00',
            performingDoctor: 'BS. CĐHA Đỗ Quốc Bảo',
            svgPathType: 'ecg_strip',
          ),
        ],
      );

      expect(report.highMetricCount, 2); // Glucose (7.2), ALT (65)
      expect(report.lowMetricCount, 1);  // Hb (105)
      expect(report.normalMetricCount, 2); // Creatinine (76), WBC (6.8)
    });
  });

  group('LabRepository Tests', () {
    test('LocalLabRepository generates expected cardiology & general metrics', () async {
      const repo = LocalLabRepository();
      final apt = Appointment(
        id: 'apt-cardio',
        patientId: 'patient-c',
        patientName: 'Lê Văn An',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        specialty: 'Tim mạch can thiệp',
        department: 'Tim mạch',
        date: DateTime(2026, 10, 26),
        time: '08:30',
        reason: 'Đau thắt ngực khi gắng sức',
        status: AppointmentStatus.completed,
      );

      final report = await repo.generateLabReportForAppointment(apt);
      expect(report.appointmentId, 'apt-cardio');
      expect(report.patientName, 'Lê Văn An');

      // Check for exact requested metrics
      final glucose = report.metrics.firstWhere((m) => m.name.contains('Glucose'));
      expect(glucose.value, 7.2);
      expect(glucose.status, LabMetricStatus.high);

      final alt = report.metrics.firstWhere((m) => m.name.contains('ALT'));
      expect(alt.value, 65.0);
      expect(alt.status, LabMetricStatus.high);

      final creat = report.metrics.firstWhere((m) => m.name.contains('Creatinine'));
      expect(creat.value, 76.0);
      expect(creat.status, LabMetricStatus.normal);

      final wbc = report.metrics.firstWhere((m) => m.name.contains('Bạch cầu'));
      expect(wbc.value, 6.8);
      expect(wbc.status, LabMetricStatus.normal);

      final hb = report.metrics.firstWhere((m) => m.name.contains('Hemoglobin'));
      expect(hb.value, 105.0);
      expect(hb.status, LabMetricStatus.low);

      // Check imaging items (ECG, X-Ray, Ultrasound)
      expect(report.imagingList.length, 3);
      final modalities = report.imagingList.map((i) => i.modality).toList();
      expect(modalities, containsAll(['ECG', 'X-Ray', 'Ultrasound']));
    });
  });

  group('LabResultsDetailScreen & Imaging Viewer Widget Tests', () {
    final sampleApt = Appointment(
      id: 'apt-test-widget',
      patientId: 'BN-8899',
      patientName: 'Phạm Minh Đức',
      doctorId: 'dr-linh',
      doctorName: 'BS. Trần Thảo Linh',
      specialty: 'Tim mạch',
      department: 'Tim mạch',
      date: DateTime(2026, 10, 26),
      time: '09:00',
      reason: 'Khám kiểm tra chỉ số',
      status: AppointmentStatus.completed,
    );

    testWidgets('renders patient details, biomarker table, and gauges', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: LabResultsDetailScreen(
            appointment: sampleApt,
            repository: const LocalLabRepository(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header details
      expect(find.text('Kho Kết quả Xét nghiệm & CĐHA'), findsOneWidget);
      expect(find.text('Phạm Minh Đức'), findsOneWidget);
      expect(find.text('Mã: BN-8899'), findsOneWidget);
      expect(find.textContaining('BS chỉ định: BS. Trần Thảo Linh'), findsOneWidget);

      // Verify Summary Badges
      expect(find.textContaining('Bình thường'), findsWidgets);
      expect(find.textContaining('Cao'), findsWidgets);
      expect(find.textContaining('Thấp'), findsWidgets);

      // Verify exact metrics appear
      expect(find.text('Glucose máu lúc đói'), findsOneWidget);
      expect(find.text('7.2'), findsOneWidget);
      expect(find.text('Men gan ALT (GPT)'), findsOneWidget);
      expect(find.text('65.0'), findsOneWidget);
      expect(find.text('Creatinine huyết thanh'), findsOneWidget);
      expect(find.text('76.0'), findsOneWidget);
      expect(find.text('Bạch cầu tổng số (WBC)'), findsOneWidget);
      expect(find.text('6.8'), findsOneWidget);
      expect(find.text('Huyết sắc tố (Hemoglobin Hb)'), findsOneWidget);
      expect(find.text('105.0'), findsOneWidget);

      // Verify Range Gauge markers
      expect(find.text('Chuẩn'), findsWidgets);

      // Test Filter Chip: Filter by "Bất thường"
      final abnormalChip = find.textContaining('Bất thường');
      expect(abnormalChip, findsWidgets);
      await tester.tap(abnormalChip.first);
      await tester.pumpAndSettle();

      // Only abnormal metrics remain
      expect(find.text('Glucose máu lúc đói'), findsOneWidget);
      expect(find.text('Men gan ALT (GPT)'), findsOneWidget);
      expect(find.text('Creatinine huyết thanh'), findsNothing); // Normal metric is hidden
    });

    testWidgets('switches to Imaging tab and opens interactive viewer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: LabResultsDetailScreen(
            appointment: sampleApt,
            repository: const LocalLabRepository(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Tab 2: Chẩn đoán Hình ảnh
      final imagingTab = find.textContaining('Chẩn đoán Hình ảnh');
      expect(imagingTab, findsOneWidget);
      await tester.tap(imagingTab);
      await tester.pumpAndSettle();

      // Should display ECG, X-Ray, Ultrasound cards
      expect(find.textContaining('Điện tâm đồ ECG 12 chuyển đạo'), findsOneWidget);
      expect(find.textContaining('Chụp X-quang Ngực thẳng'), findsOneWidget);
      expect(find.textContaining('Siêu âm Tim Doppler'), findsOneWidget);

      // Tap full screen button on first scan
      final fullScreenBtn = find.text('Xem Toàn màn hình & Tương tác PACS').first;
      await tester.tap(fullScreenBtn);
      await tester.pumpAndSettle();

      // Verify MedicalImagingViewer is opened
      expect(find.byType(MedicalImagingViewer), findsWidgets);
      expect(find.byType(InteractiveViewer), findsOneWidget);

      // Toggle Invert Colors
      final invertBtn = find.byTooltip('Đảo màu âm bản X-quang');
      expect(invertBtn, findsOneWidget);
      await tester.tap(invertBtn);
      await tester.pumpAndSettle();

      // Zoom reset button exists
      final resetBtn = find.byTooltip('Khôi phục thu phóng');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();
    });
  });
}
