import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/health_vitals_repository.dart';
import '../domain/health_vital.dart';
import 'record_vital_dialog.dart';
import 'vitals_line_chart.dart';

class HealthVitalsScreen extends StatefulWidget {
  const HealthVitalsScreen({
    super.key,
    this.repository = const RemoteHealthVitalsRepository(),
    this.patientId = 'patient-1',
    this.isDoctorView = false,
  });

  final HealthVitalsRepository repository;
  final String patientId;
  final bool isDoctorView;

  @override
  State<HealthVitalsScreen> createState() => _HealthVitalsScreenState();
}

class _HealthVitalsScreenState extends State<HealthVitalsScreen> {
  bool _loading = true;
  List<HealthVital> _history = [];
  VitalsSummary _summary = const VitalsSummary();
  ChartMetric _currentMetric = ChartMetric.bloodPressure;

  @override
  void initState() {
    super.initState();
    _loadVitals();
  }

  Future<void> _loadVitals() async {
    setState(() => _loading = true);
    try {
      final historyFuture = widget.repository.getVitalsHistory(
        patientId: widget.patientId,
        days: 30,
      );
      final summaryFuture = widget.repository.getVitalsSummary(
        patientId: widget.patientId,
      );

      final results = await Future.wait([historyFuture, summaryFuture]);
      if (mounted) {
        setState(() {
          _history = results[0] as List<HealthVital>;
          _summary = results[1] as VitalsSummary;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRecordDialog() async {
    final recorded = await RecordVitalDialog.show(
      context,
      repository: widget.repository,
      patientId: widget.patientId,
    );
    if (recorded != null) {
      _loadVitals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: recorded.statusColor,
            content: Text('Đã lưu chỉ số sinh hiệu: ${recorded.bpLabel}'),
          ),
        );
      }
    }
  }

  Future<void> _deleteVital(HealthVital vital) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa Bản ghi Sinh hiệu'),
        content: Text('Bạn có chắc muốn xóa bản ghi ngày ${vital.recordedAt.day}/${vital.recordedAt.month}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.repository.deleteVital(vital.id);
      _loadVitals();
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _summary.latest ?? (_history.isNotEmpty ? _history.last : null);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDoctorView ? 'Sinh hiệu Bệnh nhân' : 'Chỉ số Sinh hiệu & Sức khỏe'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadVitals,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadVitals,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Overview Banner
                    if (latest != null)
                      _buildOverviewBanner(latest)
                    else
                      _buildEmptyOverview(),

                    const SizedBox(height: 20),

                    // Chart Section Header & Toggle
                    Row(
                      children: [
                        const Text(
                          'Biểu đồ theo dõi xu hướng',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButton<ChartMetric>(
                            value: _currentMetric,
                            underline: const SizedBox(),
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: ChartMetric.bloodPressure, child: Text('Huyết áp', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: ChartMetric.bloodSugar, child: Text('Đường huyết', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: ChartMetric.weight, child: Text('Cân nặng / BMI', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _currentMetric = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Chart Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: VitalsLineChart(
                        vitals: _history,
                        metric: _currentMetric,
                        height: 190,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // History Timeline Header
                    Row(
                      children: [
                        const Text(
                          'Lịch sử đo gần đây',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_history.length} lần đo',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // History list
                    if (_history.isEmpty)
                      _buildEmptyHistory()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _history.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          // Show reverse order (most recent first)
                          final item = _history[_history.length - 1 - idx];
                          return _buildHistoryCard(item);
                        },
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D9488),
        icon: const Icon(Icons.favorite_rounded, color: Colors.white),
        label: const Text('Ghi nhận chỉ số', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _openRecordDialog,
      ),
    );
  }

  Widget _buildOverviewBanner(HealthVital latest) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            latest.statusColor,
            latest.statusColor.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: latest.statusColor.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'Chỉ số sinh hiệu mới nhất',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${latest.recordedAt.day}/${latest.recordedAt.month}/${latest.recordedAt.year}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Blood Pressure Display
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${latest.systolic}/${latest.diastolic}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'mmHg (Huyết áp)',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Text(
            latest.bpCategory.label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),

          // Other metrics row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricPill(
                icon: Icons.monitor_heart_outlined,
                label: 'Nhịp tim',
                value: '${latest.heartRate ?? 75} bpm',
              ),
              _metricPill(
                icon: Icons.water_drop_outlined,
                label: 'Đường huyết',
                value: '${latest.bloodSugar ?? 5.6} mmol/L',
              ),
              _metricPill(
                icon: Icons.scale_outlined,
                label: 'BMI',
                value: '${latest.bmi ?? 22.5}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(HealthVital item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.recordedAt.hour.toString().padLeft(2, '0')}:${item.recordedAt.minute.toString().padLeft(2, '0')} • ${item.recordedAt.day}/${item.recordedAt.month}/${item.recordedAt.year}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.recordedBy == 'clinic'
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.recordedBy == 'clinic' ? 'Phòng khám đo' : 'Tự đo tại nhà',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: item.recordedBy == 'clinic' ? Colors.blue.shade700 : AppColors.mutedText,
                  ),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.mutedText),
                onSelected: (val) {
                  if (val == 'delete') _deleteVital(item);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Xóa bản ghi này'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Huyết áp: ${item.bpLabel}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: item.statusColor,
                ),
              ),
              const SizedBox(width: 12),
              if (item.heartRate != null) ...[
                Text('Tim: ${item.heartRate} bpm', style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 12),
              ],
              if (item.bloodSugar != null)
                Text('Đường: ${item.bloodSugar} mmol/L', style: const TextStyle(fontSize: 13)),
            ],
          ),
          if (item.weight != null || item.bmi != null) ...[
            const SizedBox(height: 4),
            Text(
              'Cân nặng: ${item.weight ?? "--"} kg • BMI: ${item.bmi ?? "--"} (${item.bmiCategory?.label ?? "Chuẩn"})',
              style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
            ),
          ],
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ghi chú: ${item.note}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.mutedText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Text('Chưa có chỉ số sinh hiệu nào được ghi nhận.'),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.favorite_border_rounded, size: 48, color: AppColors.mutedText),
          SizedBox(height: 12),
          Text(
            'Chưa có lịch sử đo sinh hiệu',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          SizedBox(height: 4),
          Text(
            'Nhấn nút "Ghi nhận chỉ số" bên dưới để lưu chỉ số huyết áp đầu tiên.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
