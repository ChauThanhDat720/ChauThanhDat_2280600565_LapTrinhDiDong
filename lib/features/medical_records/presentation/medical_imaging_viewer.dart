import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/lab_result.dart';

/// Trình xem Chẩn đoán Hình ảnh Y tế (Interactive Medical Imaging Viewer)
/// Hỗ trợ Zoom, Pan, Đảo màu âm bản X-quang và xem kết luận chi tiết
class MedicalImagingViewer extends StatefulWidget {
  const MedicalImagingViewer({
    super.key,
    required this.item,
    this.initialInvert = false,
    this.isThumbnail = false,
  });

  final ImagingItem item;
  final bool initialInvert;
  final bool isThumbnail;

  static void showFullScreen(BuildContext context, ImagingItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            title: Text(item.title, style: const TextStyle(fontSize: 15)),
          ),
          body: MedicalImagingViewer(item: item),
        ),
      ),
    );
  }

  @override
  State<MedicalImagingViewer> createState() => _MedicalImagingViewerState();
}

class _MedicalImagingViewerState extends State<MedicalImagingViewer> {
  late bool _isInverted;
  final TransformationController _controller = TransformationController();
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _isInverted = widget.initialInvert;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetZoom() {
    setState(() {
      _controller.value = Matrix4.identity();
      _currentScale = 1.0;
    });
  }

  void _toggleInvert() {
    setState(() {
      _isInverted = !_isInverted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    if (widget.isThumbnail) {
      return Container(
        color: _isInverted ? Colors.white : const Color(0xFF020617),
        child: Center(
          child: CustomPaint(
            size: const Size(double.infinity, 180),
            painter: _MedicalScanPainter(
              type: item.svgPathType,
              isInverted: _isInverted,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1E293B),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.modality,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.capturedDate,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isInverted ? Icons.invert_colors_off : Icons.invert_colors,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: 'Đảo màu âm bản X-quang',
                onPressed: _toggleInvert,
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                tooltip: 'Khôi phục thu phóng',
                onPressed: _resetZoom,
              ),
            ],
          ),
        ),

        // Interactive Scan Canvas (Pinch-to-zoom / Pan)
        Expanded(
          child: Container(
            color: _isInverted ? Colors.white : const Color(0xFF020617),
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _controller,
                  minScale: 0.8,
                  maxScale: 4.0,
                  onInteractionUpdate: (details) {
                    setState(() {
                      _currentScale = _controller.value.getMaxScaleOnAxis();
                    });
                  },
                  child: Center(
                    child: CustomPaint(
                      size: const Size(double.infinity, 360),
                      painter: _MedicalScanPainter(
                        type: item.svgPathType,
                        isInverted: _isInverted,
                      ),
                    ),
                  ),
                ),

                // DICOM Calibration Watermark Overlay
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MOD: ${item.modality} • 12-BIT DIGITAL',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'BS THỰC HIỆN: ${item.performingDoctor.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 9.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          'ZOOM: ${(_currentScale * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Zoom hint
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pinch_rounded, color: Colors.white70, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Dùng 2 ngón tay phóng to / xoay ảnh',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Findings Description Sheet
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF0F172A),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_turned_in, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.findings,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bác sĩ chẩn đoán hình ảnh: ${item.performingDoctor}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// CustomPainter vẽ mô phỏng các dạng bản chụp y tế chuẩn PACS:
/// 1. X-quang lồng ngực (Chest X-ray)
/// 2. Bản ghi điện tim ECG 12 chuyển đạo (ECG Strip with rhythmic QRS waves)
/// 3. Siêu âm tim Doppler (Echocardiogram with color flow Doppler sector)
class _MedicalScanPainter extends CustomPainter {
  const _MedicalScanPainter({
    required this.type,
    required this.isInverted,
  });

  final String type;
  final bool isInverted;

  @override
  void paint(Canvas canvas, Size size) {
    if (type == 'ecg_strip') {
      _paintEcgStrip(canvas, size);
    } else if (type == 'echocardiogram') {
      _paintEchocardiogram(canvas, size);
    } else {
      _paintChestXray(canvas, size);
    }
  }

  void _paintChestXray(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = isInverted ? Colors.white : const Color(0xFF030712);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final bonePaint = Paint()
      ..color = (isInverted ? Colors.black87 : Colors.white.withValues(alpha: 0.85))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final lungSoftTissue = Paint()
      ..color = (isInverted ? Colors.grey.shade300 : const Color(0xFF111827))
      ..style = PaintingStyle.fill;

    final heartTissue = Paint()
      ..color = (isInverted ? Colors.grey.shade400 : Colors.white.withValues(alpha: 0.45))
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw lung cavities
    final leftLung = Path()
      ..moveTo(cx - 20, cy - 100)
      ..quadraticBezierTo(cx - 130, cy - 80, cx - 110, cy + 60)
      ..quadraticBezierTo(cx - 70, cy + 90, cx - 15, cy + 70)
      ..close();

    final rightLung = Path()
      ..moveTo(cx + 20, cy - 100)
      ..quadraticBezierTo(cx + 130, cy - 80, cx + 110, cy + 60)
      ..quadraticBezierTo(cx + 70, cy + 90, cx + 15, cy + 70)
      ..close();

    canvas.drawPath(leftLung, lungSoftTissue);
    canvas.drawPath(rightLung, lungSoftTissue);
    canvas.drawPath(leftLung, bonePaint..strokeWidth = 1.5);
    canvas.drawPath(rightLung, bonePaint..strokeWidth = 1.5);

    // Draw spine vertebrae down the center
    final spinePaint = Paint()
      ..color = isInverted ? Colors.grey.shade600 : Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawLine(Offset(cx, cy - 130), Offset(cx, cy + 120), spinePaint);

    // Draw Ribs
    final ribPaint = Paint()
      ..color = isInverted ? Colors.grey.shade500 : Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    for (int i = 0; i < 6; i++) {
      final yOffset = cy - 70 + (i * 26.0);
      // Left ribs
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx - 60, yOffset), width: 110, height: 40),
        math.pi * 0.1,
        math.pi * 0.8,
        false,
        ribPaint,
      );
      // Right ribs
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx + 60, yOffset), width: 110, height: 40),
        math.pi * 0.1,
        math.pi * 0.8,
        false,
        ribPaint,
      );
    }

    // Clavicles (xương đòn)
    canvas.drawLine(Offset(cx - 15, cy - 105), Offset(cx - 120, cy - 115), ribPaint..strokeWidth = 4);
    canvas.drawLine(Offset(cx + 15, cy - 105), Offset(cx + 120, cy - 115), ribPaint..strokeWidth = 4);

    // Heart silhouette (bóng tim, hơi lệch sang trái theo giải phẫu)
    final heartPath = Path()
      ..moveTo(cx - 10, cy - 20)
      ..quadraticBezierTo(cx + 25, cy + 10, cx + 10, cy + 55)
      ..quadraticBezierTo(cx - 40, cy + 85, cx - 75, cy + 60)
      ..quadraticBezierTo(cx - 80, cy + 10, cx - 10, cy - 20)
      ..close();

    canvas.drawPath(heartPath, heartTissue);
    canvas.drawPath(heartPath, bonePaint..strokeWidth = 1.5);

    // Diaphragm (cơ hoành)
    final diaphragmPaint = Paint()
      ..color = isInverted ? Colors.grey.shade400 : Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawArc(Rect.fromCenter(center: Offset(cx - 65, cy + 90), width: 110, height: 40), math.pi, math.pi, false, diaphragmPaint);
    canvas.drawArc(Rect.fromCenter(center: Offset(cx + 65, cy + 85), width: 110, height: 40), math.pi, math.pi, false, diaphragmPaint);
  }

  void _paintEcgStrip(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = isInverted ? const Color(0xFFFFFBEB) : const Color(0xFF064E3B);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // ECG Medical Grid (1mm & 5mm pink/green lines)
    final gridPaint = Paint()
      ..color = isInverted
          ? Colors.orange.withValues(alpha: 0.25)
          : const Color(0xFF047857).withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    const gridSize = 16.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Lead ECG Waveform (P - Q - R - S - T)
    final wavePaint = Paint()
      ..color = isInverted ? const Color(0xFFB91C1C) : const Color(0xFF34D399)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final baseline = size.height / 2;
    path.moveTo(0, baseline);

    const cycleWidth = 85.0;

    for (double x = 0; x < size.width; x += cycleWidth) {
      // Isoelectric baseline
      path.lineTo(x + 15, baseline);
      // P wave
      path.quadraticBezierTo(x + 22, baseline - 12, x + 30, baseline);
      // PR segment
      path.lineTo(x + 40, baseline);
      // Q wave (nhỏ xuống)
      path.lineTo(x + 43, baseline + 8);
      // R peak (cao vọt lên)
      path.lineTo(x + 48, baseline - 75);
      // S wave (sâu xuống)
      path.lineTo(x + 53, baseline + 22);
      // ST segment
      path.lineTo(x + 60, baseline);
      // T wave
      path.quadraticBezierTo(x + 72, baseline - 24, x + 82, baseline);
      // Isoelectric
      path.lineTo(x + cycleWidth, baseline);
    }

    canvas.drawPath(path, wavePaint);

    // Lead II label & speed calibration
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'CHUYỂN ĐẠO DII • 25mm/s • 10mm/mV • HR: 78 BPM (NHỊP XOANG ĐỀU)',
        style: TextStyle(
          color: isInverted ? const Color(0xFF92400E) : const Color(0xFF6EE7B7),
          fontSize: 10,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, const Offset(12, 12));
  }

  void _paintEchocardiogram(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = isInverted ? Colors.white : Colors.black;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final cx = size.width / 2;
    const topY = 25.0;

    // Sector probe beam (hình quạt siêu âm)
    final sectorPath = Path()
      ..moveTo(cx, topY)
      ..arcTo(
        Rect.fromCenter(center: Offset(cx, topY), width: 340, height: 340),
        math.pi * 0.25,
        math.pi * 0.5,
        false,
      )
      ..close();

    final sectorPaint = Paint()
      ..color = isInverted ? Colors.grey.shade100 : const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawPath(sectorPath, sectorPaint);

    final sectorBorder = Paint()
      ..color = isInverted ? Colors.grey.shade400 : Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(sectorPath, sectorBorder);

    // Echocardiogram chambers (thất trái, nhĩ trái)
    final tissuePaint = Paint()
      ..color = isInverted ? Colors.grey.shade400 : Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    // Left Ventricle (LV)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 15, topY + 110), width: 80, height: 110),
      tissuePaint,
    );
    // Left Atrium (LA)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 15, topY + 190), width: 60, height: 60),
      tissuePaint,
    );

    // Color Doppler Jet (Dòng máu qua van 2 lá: Đỏ & Xanh)
    final dopplerRed = Paint()
      ..color = Colors.red.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    final dopplerBlue = Paint()
      ..color = Colors.blue.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 20, topY + 145), width: 22, height: 35),
      dopplerRed,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 10, topY + 155), width: 14, height: 25),
      dopplerBlue,
    );

    // Depth markers & Velocity Scale
    final markerPaint = Paint()
      ..color = isInverted ? Colors.black45 : Colors.white54
      ..strokeWidth = 1.0;

    for (int d = 1; d <= 4; d++) {
      final y = topY + (d * 45.0);
      canvas.drawLine(Offset(cx - 155 + (d * 18), y), Offset(cx - 140 + (d * 18), y), markerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MedicalScanPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.isInverted != isInverted;
}
