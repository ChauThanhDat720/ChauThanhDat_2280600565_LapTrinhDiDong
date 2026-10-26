import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../../domain/vaccination_record.dart';

class VaccinePassportCard extends StatelessWidget {
  const VaccinePassportCard({
    super.key,
    required this.record,
    this.onTapDetail,
  });

  final VaccinationRecord record;
  final VoidCallback? onTapDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A), // Dark Navy
            Color(0xFF0D9488), // Smart Hospital Teal
            Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFCD34D).withValues(alpha: 0.6), // Gold border
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Golden Emblems
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCD34D).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFCD34D), width: 1.2),
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFFFCD34D), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHỨNG NHẬN TIÊM CHỦNG ĐIỆN TỬ',
                        style: TextStyle(
                          color: Color(0xFFFDE68A),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'DIGITAL CERTIFICATE OF VACCINATION',
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: record.isCompleted
                        ? const Color(0xFF10B981).withValues(alpha: 0.25)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: record.isCompleted ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                    ),
                  ),
                  child: Text(
                    record.isCompleted ? 'HOÀN TẤT / VERIFIED' : 'ĐANG THEO DÕI',
                    style: TextStyle(
                      color: record.isCompleted ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body Content: Patient & Vaccine Info + QR
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _passportField('CHỦ HỘ CHIẾU / HOLDER', record.patientName.toUpperCase(), isPrimary: true),
                          const SizedBox(height: 10),
                          _passportField('MÃ CHỨNG NHẬN / CERTIFICATE ID', record.certificateCode, isMonospace: true),
                          const SizedBox(height: 10),
                          _passportField('VẮC-XIN / VACCINE', record.vaccineName),
                          const SizedBox(height: 10),
                          _passportField('PHÒNG BỆNH / TARGET', record.targetDisease),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _passportField('LIỀU TIÊM / DOSE', record.doseProgressLabel),
                              ),
                              Expanded(
                                child: _passportField('NGÀY TIÊM / DATE', record.administeredDateLabel),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // QR Code Box
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: _VaccineQrCanvasView(
                              data: record.verificationQrData,
                              size: 110,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Quét xác thực',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 12),

                // Footer with Issuer Info
                Row(
                  children: [
                    const Icon(Icons.local_hospital_rounded, color: Color(0xFFFCD34D), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        record.facilityName,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (onTapDetail != null)
                      InkWell(
                        onTap: onTapDetail,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                'Chi tiết',
                                style: TextStyle(
                                  color: Color(0xFFFCD34D),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 14, color: Color(0xFFFCD34D)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _passportField(String label, String value, {bool isPrimary = false, bool isMonospace = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isPrimary ? Colors.white : const Color(0xFFF1F5F9),
            fontSize: isPrimary ? 15 : 12,
            fontWeight: isPrimary ? FontWeight.w900 : FontWeight.w600,
            fontFamily: isMonospace ? 'monospace' : null,
            letterSpacing: isMonospace ? 0.6 : 0,
          ),
        ),
      ],
    );
  }
}

class _VaccineQrCanvasView extends StatelessWidget {
  const _VaccineQrCanvasView({required this.data, this.size = 110});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    try {
      final qrCode = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final qrImage = QrImage(qrCode);

      return CustomPaint(
        size: Size(size, size),
        painter: _VaccineQrCanvasPainter(qrImage),
      );
    } catch (_) {
      // Fallback for edge cases where data payload exceeds QR size
      return Container(
        width: size,
        height: size,
        color: Colors.white,
        child: const Icon(Icons.qr_code_2_rounded, size: 48, color: Colors.black87),
      );
    }
  }
}

class _VaccineQrCanvasPainter extends CustomPainter {
  _VaccineQrCanvasPainter(this.qrImage);

  final QrImage qrImage;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final moduleCount = qrImage.moduleCount;
    final pixelSize = size.width / moduleCount;

    for (int x = 0; x < moduleCount; x++) {
      for (int y = 0; y < moduleCount; y++) {
        if (qrImage.isDark(y, x)) {
          final rect = Rect.fromLTWH(
            x * pixelSize,
            y * pixelSize,
            pixelSize,
            pixelSize,
          );
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
