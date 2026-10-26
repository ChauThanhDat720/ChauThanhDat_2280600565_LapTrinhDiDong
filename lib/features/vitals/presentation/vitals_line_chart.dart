import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/health_vital.dart';

enum ChartMetric {
  bloodPressure('Huyết áp (mmHg)'),
  bloodSugar('Đường huyết (mmol/L)'),
  weight('Cân nặng (kg)');

  const ChartMetric(this.label);
  final String label;
}

class VitalsLineChart extends StatefulWidget {
  const VitalsLineChart({
    super.key,
    required this.vitals,
    this.metric = ChartMetric.bloodPressure,
    this.height = 200,
  });

  final List<HealthVital> vitals;
  final ChartMetric metric;
  final double height;

  @override
  State<VitalsLineChart> createState() => _VitalsLineChartState();
}

class _VitalsLineChartState extends State<VitalsLineChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.vitals.isEmpty) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        child: const Text('Chưa có dữ liệu để vẽ biểu đồ', style: TextStyle(color: Colors.grey)),
      );
    }

    final selected = _selectedIndex != null && _selectedIndex! < widget.vitals.length
        ? widget.vitals[_selectedIndex!]
        : widget.vitals.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Highlighted point banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: selected.statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected.statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: selected.statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.metric == ChartMetric.bloodPressure
                      ? 'Ngày ${selected.recordedAt.day}/${selected.recordedAt.month}: HA ${selected.systolic}/${selected.diastolic} mmHg • ${selected.bpCategory.label}'
                      : (widget.metric == ChartMetric.bloodSugar
                          ? 'Ngày ${selected.recordedAt.day}/${selected.recordedAt.month}: ${selected.bloodSugar ?? 0.0} mmol/L (${selected.bloodSugarCondition == 'fasting' ? 'Lúc đói' : 'Sau ăn'})'
                          : 'Ngày ${selected.recordedAt.day}/${selected.recordedAt.month}: Cân nặng ${selected.weight ?? 0.0} kg (BMI: ${selected.bmi ?? '--'})'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected.statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Custom Paint Chart Area
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: GestureDetector(
            onTapDown: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final width = box.size.width;
              final count = widget.vitals.length;
              if (count <= 1) return;
              final step = width / (count - 1);
              final idx = (details.localPosition.dx / step).round().clamp(0, count - 1);
              setState(() => _selectedIndex = idx);
            },
            child: CustomPaint(
              painter: _VitalsChartPainter(
                vitals: widget.vitals,
                metric: widget.metric,
                selectedIndex: _selectedIndex ?? (widget.vitals.length - 1),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.metric == ChartMetric.bloodPressure) ...[
              _legendItem('Tâm thu (Systolic)', const Color(0xFF0D9488)),
              const SizedBox(width: 16),
              _legendItem('Tâm trương (Diastolic)', const Color(0xFF2563EB)),
              const SizedBox(width: 16),
              _legendItem('Chuẩn 120/80', Colors.grey.shade400, isDashed: true),
            ] else if (widget.metric == ChartMetric.bloodSugar) ...[
              _legendItem('Đường huyết (mmol/L)', const Color(0xFFD97706)),
              const SizedBox(width: 16),
              _legendItem('Ngưỡng chuẩn < 7.0', Colors.grey.shade400, isDashed: true),
            ] else ...[
              _legendItem('Cân nặng (kg)', const Color(0xFF4F46E5)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _legendItem(String label, Color color, {bool isDashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: isDashed ? 2 : 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }
}

class _VitalsChartPainter extends CustomPainter {
  _VitalsChartPainter({
    required this.vitals,
    required this.metric,
    required this.selectedIndex,
  });

  final List<HealthVital> vitals;
  final ChartMetric metric;
  final int selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (vitals.isEmpty) return;

    final paddingLeft = 36.0;
    final paddingBottom = 24.0;
    final paddingTop = 12.0;
    final paddingRight = 16.0;

    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;

    // Calculate Min & Max for scale
    double minY = 50.0;
    double maxY = 180.0;

    if (metric == ChartMetric.bloodPressure) {
      final allSys = vitals.map((v) => v.systolic.toDouble());
      final allDia = vitals.map((v) => v.diastolic.toDouble());
      minY = max(40.0, (allDia.reduce(min) - 15).floorToDouble());
      maxY = min(220.0, (allSys.reduce(max) + 15).ceilToDouble());
    } else if (metric == ChartMetric.bloodSugar) {
      final allBs = vitals.map((v) => v.bloodSugar ?? 5.5);
      minY = max(3.0, (allBs.reduce(min) - 1.0));
      maxY = (allBs.reduce(max) + 2.0);
    } else {
      final allW = vitals.map((v) => v.weight ?? 60.0);
      minY = max(40.0, (allW.reduce(min) - 3.0));
      maxY = (allW.reduce(max) + 3.0);
    }

    final yRange = (maxY - minY) > 0 ? (maxY - minY) : 1.0;

    double getY(double val) {
      final ratio = (val - minY) / yRange;
      return size.height - paddingBottom - (ratio * chartHeight);
    }

    double getX(int index) {
      if (vitals.length == 1) return paddingLeft + chartWidth / 2;
      return paddingLeft + (index / (vitals.length - 1)) * chartWidth;
    }

    // Grid lines & Y-axis labels
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final steps = 4;
    for (int i = 0; i <= steps; i++) {
      final val = minY + (yRange / steps) * i;
      final y = getY(val);

      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      textPainter.text = TextSpan(
        text: val.toInt().toString(),
        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 6, y - textPainter.height / 2));
    }

    // Baseline guidelines (e.g. 120 and 80 for BP, or 7.0 for glucose)
    if (metric == ChartMetric.bloodPressure) {
      final guidePaint = Paint()
        ..color = Colors.teal.withValues(alpha: 0.3)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(paddingLeft, getY(120)), Offset(size.width - paddingRight, getY(120)), guidePaint);
      canvas.drawLine(Offset(paddingLeft, getY(80)), Offset(size.width - paddingRight, getY(80)), guidePaint);
    }

    // Draw Lines
    void drawDataLine(List<double> values, Color color, {bool fillGradient = false}) {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      for (int i = 0; i < values.length; i++) {
        final x = getX(i);
        final y = getY(values[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linePaint);

      // Points
      final pointPaint = Paint()..color = color;
      final whitePaint = Paint()..color = Colors.white;

      for (int i = 0; i < values.length; i++) {
        final x = getX(i);
        final y = getY(values[i]);
        final isSelected = i == selectedIndex;

        canvas.drawCircle(Offset(x, y), isSelected ? 5.5 : 3.5, pointPaint);
        canvas.drawCircle(Offset(x, y), isSelected ? 3.0 : 1.5, whitePaint);
      }
    }

    if (metric == ChartMetric.bloodPressure) {
      final sysValues = vitals.map((v) => v.systolic.toDouble()).toList();
      final diaValues = vitals.map((v) => v.diastolic.toDouble()).toList();
      drawDataLine(sysValues, const Color(0xFF0D9488));
      drawDataLine(diaValues, const Color(0xFF2563EB));
    } else if (metric == ChartMetric.bloodSugar) {
      final bsValues = vitals.map((v) => v.bloodSugar ?? 5.5).toList();
      drawDataLine(bsValues, const Color(0xFFD97706));
    } else {
      final wValues = vitals.map((v) => v.weight ?? 60.0).toList();
      drawDataLine(wValues, const Color(0xFF4F46E5));
    }

    // X-axis Dates Labels
    for (int i = 0; i < vitals.length; i++) {
      if (vitals.length > 7 && i % 2 != 0 && i != vitals.length - 1) continue;
      final x = getX(i);
      final date = vitals[i].recordedAt;
      textPainter.text = TextSpan(
        text: '${date.day}/${date.month}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: i == selectedIndex ? FontWeight.bold : FontWeight.normal,
          color: i == selectedIndex ? const Color(0xFF0D9488) : Colors.grey.shade600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - paddingBottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _VitalsChartPainter oldDelegate) => true;
}
