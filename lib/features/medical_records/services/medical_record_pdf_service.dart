import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../appointments/domain/appointment.dart';

class MedicalRecordPdfService {
  /// Generate a formal Vietnamese Hospital Medical Record & Prescription PDF document.
  static Future<Uint8List> generateMedicalRecordPdf(Appointment appointment) async {
    final pdf = pw.Document();

    pw.Font? regularFont;
    pw.Font? boldFont;

    try {
      final fileReg = File('assets/fonts/arial.ttf');
      final fileBold = File('assets/fonts/arialbd.ttf');

      if (fileReg.existsSync() && fileBold.existsSync()) {
        final regBytes = fileReg.readAsBytesSync();
        final boldBytes = fileBold.readAsBytesSync();
        regularFont = pw.Font.ttf(ByteData.sublistView(regBytes));
        boldFont = pw.Font.ttf(ByteData.sublistView(boldBytes));
      } else {
        final regularData = await rootBundle.load('assets/fonts/arial.ttf');
        final boldData = await rootBundle.load('assets/fonts/arialbd.ttf');
        regularFont = pw.Font.ttf(regularData);
        boldFont = pw.Font.ttf(boldData);
      }
    } catch (_) {
      try {
        regularFont = await PdfGoogleFonts.robotoRegular();
        boldFont = await PdfGoogleFonts.robotoBold();
      } catch (_) {
        regularFont = pw.Font.helvetica();
        boldFont = pw.Font.helveticaBold();
      }
    }

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
      italic: regularFont,
      boldItalic: boldFont,
    );

    // Parse prescription lines into structured items
    final rawPrescription = appointment.prescription ?? 'Chưa có đơn thuốc';
    final prescriptionLines = rawPrescription
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final examDate = appointment.date;
    final dayStr = examDate.day.toString().padLeft(2, '0');
    final monthStr = examDate.month.toString().padLeft(2, '0');
    final yearStr = examDate.year.toString();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BỆNH VIỆN ĐA KHOA QUỐC TẾ SMART HOSPITAL',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Địa chỉ: 123 Đường Y Dược, P. Bến Nghé, Quận 1, TP. Hồ Chí Minh',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          'Hotline: 1900 1122  •  Cấp cứu: 115  •  Website: smarthospital.vn',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'https://smarthospital.vn/records/${appointment.id}',
                        width: 52,
                        height: 52,
                        drawText: false,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Xác thực điện tử',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.2, color: PdfColors.blue800),
              pw.SizedBox(height: 8),

              // Title
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PHIẾU KHÁM BỆNH VÀ ĐƠN THUỐC ĐIỆN TỬ',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Mã ca khám: ${appointment.id}   |   Ngày khám: $dayStr/$monthStr/$yearStr lúc ${appointment.time}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Section 1: Patient Information
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Họ và tên BN:', appointment.patientName, boldFont),
                          pw.SizedBox(height: 4),
                          _buildInfoRow('Mã hồ sơ y tế:', appointment.patientId, boldFont),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Khoa khám:', appointment.department, boldFont),
                          pw.SizedBox(height: 4),
                          _buildInfoRow('Bác sĩ phụ trách:', appointment.doctorName, boldFont),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Section 2: Clinical Examination & Diagnosis
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Lý do khám ban đầu:', appointment.reason, boldFont),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CHẨN ĐOÁN XÁC ĐỊNH: ',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            appointment.diagnosis ?? 'Đang theo dõi lâm sàng',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Section 3: Prescription
              pw.Text(
                'CHỈ ĐỊNH DÙNG THUỐC (ĐƠN THUỐC)',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('STT', isHeader: true),
                      _buildTableCell('Tên thuốc & Liều lượng', isHeader: true),
                      _buildTableCell('Cách dùng & Thời điểm', isHeader: true),
                    ],
                  ),
                  ...prescriptionLines.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final text = entry.value;
                    return pw.TableRow(
                      children: [
                        _buildTableCell('$idx', alignCenter: true),
                        _buildTableCell(text),
                        _buildTableCell('Theo chỉ dẫn của bác sĩ'),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 10),

              // Doctor's Note
              if (appointment.statusNote != null && appointment.statusNote!.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.amber300),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Lời dặn của bác sĩ: ',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.brown800,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          appointment.statusNote!,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),
              ],

              pw.Spacer(),

              // Footer & Signatures
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Lưu ý quan trọng:',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '• Đơn thuốc có giá trị sử dụng trong 05 ngày kể từ ngày kê.',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        '• Tái khám mang theo phiếu này và các kết quả xét nghiệm.',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        '• Khám cấp cứu liên hệ ngay tổng đài 115.',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'TP. Hồ Chí Minh, ngày $dayStr tháng $monthStr năm $yearStr',
                        style: const pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'BÁC SĨ ĐIỀU TRỊ',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.red800, width: 1.5),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'ĐÃ KÝ ĐIỆN TỬ',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red800,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        appointment.doctorName,
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoRow(String label, String value, pw.Font? boldFont) {
    return pw.Row(
      children: [
        pw.Text(
          '$label ',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 9),
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool alignCenter = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: alignCenter ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
