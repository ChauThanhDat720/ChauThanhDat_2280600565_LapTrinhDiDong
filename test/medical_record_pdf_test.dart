import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/medical_records/presentation/medical_record_pdf_preview_screen.dart';
import 'package:smart_hospital/features/medical_records/services/medical_record_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleCompletedAppointment = Appointment(
    id: 'APT-TEST-001',
    patientId: 'BN-123456',
    patientName: 'Nguyễn Văn Bệnh Nhân',
    doctorId: 'dr-linh',
    doctorName: 'BS. Trần Thảo Linh',
    department: 'Tim mạch',
    specialty: 'Tim mạch can thiệp',
    date: DateTime(2026, 11, 20),
    time: '09:00',
    reason: 'Hồi hộp đánh trống ngực',
    status: AppointmentStatus.completed,
    diagnosis: 'Rối loạn thần kinh tim nhẹ',
    prescription: 'Magnesium B6 x 20 viên\nConcor 2.5mg x 14 viên',
    statusNote: 'Uống thuốc đều đặn sau ăn, tránh cà phê.',
  );

  test('MedicalRecordPdfService generates valid PDF bytes starting with %PDF', () async {
    final Uint8List pdfBytes =
        await MedicalRecordPdfService.generateMedicalRecordPdf(sampleCompletedAppointment);

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(100));

    // Verify PDF magic header bytes: %PDF-
    final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
    expect(header, equals('%PDF-'));
  });

  testWidgets('MedicalRecordPdfPreviewScreen renders PdfPreview widget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MedicalRecordPdfPreviewScreen(
          appointment: sampleCompletedAppointment,
        ),
      ),
    );

    expect(find.text('Phiếu khám & Đơn thuốc PDF'), findsOneWidget);
    expect(find.byType(PdfPreview), findsOneWidget);
  });
}
