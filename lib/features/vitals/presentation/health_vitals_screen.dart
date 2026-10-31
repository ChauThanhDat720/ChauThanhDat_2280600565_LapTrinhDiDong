import 'dart:async';
import '../../../core/realtime/hospital_realtime_service.dart';
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

class _HealthVitalsScreenState extends State<HealthVitalsScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<HealthVital> _history = [];
  VitalsSummary _summary = const VitalsSummary();
  ChartMetric _currentMetric = ChartMetric.bloodPressure;

  // Live Telemetry Stream state
  bool _isLiveMonitoring = false;
  Timer? _liveTelemetryTimer;
  int _liveHeartRate = 76;
  int _liveSystolic = 120;
  int _liveDiastolic = 80;
  int _liveSpo2 = 98;
  bool _liveAlertActive = false;
  String? _liveAlertMsg;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final List<double> _ecgHistory = [0.0, 0.2, -0.1, 0.0, 1.8, -0.6, 0.3, 0.0, 0.1, 0.0, 0.0, 0.2, -0.1, 0.0, 1.8, -0.6, 0.3, 0.0, 0.1, 0.0];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadVitals();
  }

  @override
  void dispose() {
    _liveTelemetryTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleLiveMonitoring() {
    setState(() {
      _isLiveMonitoring = !_isLiveMonitoring;
      if (_isLiveMonitoring) {
        _liveTelemetryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          if (!mounted) return;
          setState(() {
            _liveHeartRate = 72 + (_liveAlertActive ? 45 : (DateTime.now().second % 10 - 5));
            _liveSystolic = 118 + (_liveAlertActive ? 35 : (DateTime.now().second % 8 - 4));
            _liveDiastolic = 78 + (_liveAlertActive ? 15 : (DateTime.now().second % 6 - 3));
            _liveSpo2 = _liveAlertActive ? 92 : 98;
          });
        });
      } else {
        _liveTelemetryTimer?.cancel();
        _liveAlertActive = false;
        _liveAlertMsg = null;
      }
    });
  }

  void _triggerSimulatedAlert() {
    setState(() {
      _liveAlertActive = !_liveAlertActive;
      if (_liveAlertActive) {
        _liveAlertMsg = 'Cảnh báo: Nhịp tim tăng cao bất thường (117 BPM) & Huyết áp 153/93 mmHg!';
        _liveHeartRate = 117;
        _liveSystolic = 153;
        _liveDiastolic = 93;
        _liveSpo2 = 93;
      } else {
        _liveAlertMsg = null;
        _liveHeartRate = 76;
        _liveSystolic = 120;
        _liveDiastolic = 80;
        _liveSpo2 = 98;
      }
    });
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
  Widget _buildLiveTelemetryCard() {
    return Container(
      decoration: BoxDecoration(
        color: _liveAlertActive ? const Color(0xFFFEF2F2) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _liveAlertActive ? Colors.red : (_isLiveMonitoring ? const Color(0xFF10B981) : const Color(0xFF334155)),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (_liveAlertActive ? Colors.red : Colors.black).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isLiveMonitoring ? const Color(0xFF10B981) : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sensors_rounded,
                      size: 14,
                      color: _isLiveMonitoring ? Colors.white : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isLiveMonitoring ? 'LIVE TELEMETRY' : 'OFFLINE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Switch(
                value: _isLiveMonitoring,
                activeColor: const Color(0xFF10B981),
                onChanged: (_) => _toggleLiveMonitoring(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isLiveMonitoring) ...[
            Text(
              'Giám Sát Sinh Tồn Thời Gian Thực',
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bật để kết nối trực tiếp với thiết bị đeo/monitor theo dõi nhịp tim (BPM), SpO2 và huyết áp liên tục.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12.5, height: 1.3),
            ),
          ] else ...[
            if (_liveAlertActive)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _liveAlertMsg ?? 'Phát hiện chỉ số sinh tồn bất thường!',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
                            ),
                            const SizedBox(width: 6),
                            Text('NHỊP TIM', style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$_liveHeartRate',
                              style: TextStyle(
                                color: _liveAlertActive ? Colors.redAccent : const Color(0xFF38BDF8),
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('bpm', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.water_drop_rounded, color: Colors.cyanAccent, size: 18),
                            const SizedBox(width: 6),
                            Text('OXY SpO2', style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$_liveSpo2',
                              style: TextStyle(
                                color: _liveSpo2 < 95 ? Colors.redAccent : const Color(0xFF34D399),
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('%', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.speed_rounded, color: Colors.orangeAccent, size: 18),
                            const SizedBox(width: 6),
                            Text('HUYẾT ÁP', style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$_liveSystolic/$_liveDiastolic',
                              style: TextStyle(
                                color: _liveSystolic >= 140 ? Colors.redAccent : Colors.orangeAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ECG Mini wave line
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: CustomPaint(
                      painter: _EcgWavePainter(_ecgHistory, _liveAlertActive ? Colors.redAccent : const Color(0xFF10B981)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _liveAlertActive ? Colors.redAccent : Colors.white70,
                    side: BorderSide(color: _liveAlertActive ? Colors.redAccent : Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _triggerSimulatedAlert,
                  icon: Icon(_liveAlertActive ? Icons.healing_rounded : Icons.crisis_alert_rounded, size: 16),
                  label: Text(_liveAlertActive ? 'Tắt cảnh báo' : 'Thử cảnh báo', style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EcgWavePainter extends CustomPainter {
  _EcgWavePainter(this.points, this.color);
  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final dx = size.width / (points.length - 1);
    final midY = size.height / 2;

    path.moveTo(0, midY);
    for (int i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = midY - (points[i] * (size.height / 3));
      path.lineTo(x, y.clamp(2.0, size.height - 2.0));
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EcgWavePainter oldDelegate) => true;
}
