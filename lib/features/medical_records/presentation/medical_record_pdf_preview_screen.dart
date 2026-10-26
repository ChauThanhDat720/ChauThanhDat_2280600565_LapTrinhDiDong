import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../appointments/domain/appointment.dart';
import '../services/medical_record_pdf_service.dart';

class MedicalRecordPdfPreviewScreen extends StatelessWidget {
  const MedicalRecordPdfPreviewScreen({
    super.key,
    required this.appointment,
  });

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phiếu khám & Đơn thuốc PDF'),
        centerTitle: true,
      ),
      body: PdfPreview(
        build: (format) => MedicalRecordPdfService.generateMedicalRecordPdf(appointment),
        initialPageFormat: PdfPageFormat.a4,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: 'Phieu_kham_${appointment.id}.pdf',
        loadingWidget: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Đang tạo phiếu khám và đơn thuốc điện tử...'),
            ],
          ),
        ),
      ),
    );
  }
}
