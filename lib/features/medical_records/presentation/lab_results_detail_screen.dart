import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../appointments/domain/appointment.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/domain/invoice.dart';
import '../../payments/presentation/vietqr_payment_screen.dart';
import '../data/lab_repository.dart';
import '../domain/lab_result.dart';
import 'medical_imaging_viewer.dart';

enum _MetricFilter { all, abnormal, normal }

/// Màn hình Chi tiết Kết quả Xét nghiệm & Cận lâm sàng (Lab & Imaging Results Portal)
class LabResultsDetailScreen extends StatefulWidget {
  const LabResultsDetailScreen({
    super.key,
    this.appointment,
    this.appointmentId,
    this.repository = const LocalLabRepository(),
    this.requirePayment = false,
  }) : assert(appointment != null || appointmentId != null,
            'Must provide either appointment or appointmentId');

  final Appointment? appointment;
  final String? appointmentId;
  final LabRepository repository;
  final bool requirePayment;

  @override
  State<LabResultsDetailScreen> createState() => _LabResultsDetailScreenState();
}

class _LabResultsDetailScreenState extends State<LabResultsDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _MetricFilter _filter = _MetricFilter.all;
  bool _isLoading = true;
  bool _isPaymentLocked = false;
  Invoice? _labInvoice;
  LabReport? _report;
  String? _errorMessage;

  String get _targetId => widget.appointment?.id ?? widget.appointmentId!;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isPaymentLocked = false;
    });

    try {
      final paymentRepo = LocalPaymentRepository();
      Invoice? labInv = await paymentRepo.getLabInvoice(_targetId);
      if (widget.requirePayment || (labInv != null && !labInv.isPaid)) {
        labInv ??= await paymentRepo.createOrUpdateLabInvoice(_targetId, const [
          'Tổng phân tích tế bào máu (CBC)',
          'Sinh hóa máu (Glucose, mỡ máu)',
        ]);
        if (!labInv.isPaid) {
          if (mounted) {
            setState(() {
              _labInvoice = labInv;
              _isPaymentLocked = true;
              _isLoading = false;
            });
          }
          return;
        }
      }
      _labInvoice = labInv;

      LabReport? report;
      if (widget.appointment != null) {
        report = await widget.repository
            .generateLabReportForAppointment(widget.appointment!);
      } else {
        report = await widget.repository
            .getLabReportForAppointment(_targetId);
      }

      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể tải kết quả xét nghiệm: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<LabTestMetric> _getFilteredMetrics(List<LabTestMetric> all) {
    switch (_filter) {
      case _MetricFilter.all:
        return all;
      case _MetricFilter.abnormal:
        return all
            .where((m) =>
                m.status == LabMetricStatus.high ||
                m.status == LabMetricStatus.low)
            .toList();
      case _MetricFilter.normal:
        return all
            .where((m) => m.status == LabMetricStatus.normal)
            .toList();
    }
  }

  void _shareReportSummary() {
    if (_report == null) return;
    final r = _report!;
    final buffer = StringBuffer();
    buffer.writeln('📋 KẾT QUẢ XÉT NGHIỆM & CĐHA - SMART HOSPITAL');
    buffer.writeln('Bệnh nhân: ${r.patientName} (Mã: ${r.patientId})');
    buffer.writeln('Bác sĩ điều trị: ${r.doctorName} (${r.department})');
    buffer.writeln('Thời gian trả kết quả: ${r.reportDate}');
    buffer.writeln('-----------------------------------');
    buffer.writeln('🔴 Chỉ số vượt ngưỡng: ${r.highMetricCount}');
    buffer.writeln('🟡 Chỉ số dưới ngưỡng: ${r.lowMetricCount}');
    buffer.writeln('🟢 Chỉ số bình thường: ${r.normalMetricCount}');
    buffer.writeln('-----------------------------------');
    for (final m in r.metrics) {
      buffer.writeln(
          '• ${m.name}: ${m.value} ${m.unit} [${m.status.label}] (Chuẩn: ${m.referenceRange})');
    }
    buffer.writeln('-----------------------------------');
    buffer.writeln('Kết luận: ${r.generalConclusion}');
    buffer.writeln('Chẩn đoán bởi: ${r.diagnostician}');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép tóm tắt kết quả xét nghiệm vào bộ nhớ tạm!'),
        backgroundColor: Color(0xFF0D9488),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Kho Kết quả Xét nghiệm & CĐHA',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Chia sẻ tóm tắt',
            onPressed: _report != null ? _shareReportSummary : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
            onPressed: _loadReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('Đang nạp dữ liệu kết quả xét nghiệm...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadReport,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : _isPaymentLocked
                  ? _buildLabPaymentLockedView()
                  : _buildContent(_report!),
    );
  }

  Widget _buildLabPaymentLockedView() {
    final inv = _labInvoice;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  size: 40,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Đợt 2: Chưa thanh toán Phí Xét nghiệm & CLS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF92400E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Theo quy trình bệnh viện, bệnh nhân cần hoàn tất thanh toán phí chỉ định Cận lâm sàng (Đợt 2) trước khi được cấp Mã QR Phòng Xét nghiệm (CLS-QR) và xem kết quả.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF78350F),
                  height: 1.4,
                ),
              ),
              if (inv != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...inv.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.biotech_rounded,
                                size: 16,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Cần thanh toán (BHYT đã trừ):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            Invoice.formatCurrency(inv.patientPayable),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text(
                    'Thanh toán Phí Xét nghiệm (Đợt 2 - VietQR)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final repo = LocalPaymentRepository();
                    final targetInv =
                        inv ??
                        await repo.createOrUpdateLabInvoice(_targetId, const [
                          'Tổng phân tích tế bào máu (CBC)',
                          'Sinh hóa máu (Glucose, mỡ máu)',
                        ]);
                    if (!mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VietQrPaymentScreen(
                          invoice: targetInv,
                          repository: repo,
                        ),
                      ),
                    );
                    await _loadReport();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(LabReport report) {
    return Column(
      children: [
        if (_labInvoice?.isPaid == true)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFECFDF5),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã thanh toán Phí CLS (Đợt 2) • Mã QR Phòng Xét nghiệm: CLS-QR:$_targetId',
                    style: const TextStyle(
                      color: Color(0xFF065F46),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        _buildPatientBanner(report),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMetricsTab(report),
              _buildImagingTab(report),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPatientBanner(LabReport report) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.biotech_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          report.patientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Mã: ${report.patientId}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'BS chỉ định: ${report.doctorName} • ${report.department}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'Lấy mẫu: ${report.sampleDate}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.verified_outlined,
                        size: 14, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(
                      'Trả KQ: ${report.reportDate}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Counters Banner
          Row(
            children: [
              Expanded(
                child: _buildSummaryBadge(
                  label: 'Bình thường',
                  count: report.normalMetricCount,
                  color: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFDCFCE7),
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryBadge(
                  label: 'Cao',
                  count: report.highMetricCount,
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEE2E2),
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryBadge(
                  label: 'Thấp',
                  count: report.lowMetricCount,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: [
          Tab(
            icon: const Icon(Icons.table_chart_rounded, size: 18),
            text: 'Chỉ số Xét nghiệm (${_report?.metrics.length ?? 0})',
          ),
          Tab(
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            text: 'Chẩn đoán Hình ảnh (${_report?.imagingList.length ?? 0})',
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsTab(LabReport report) {
    final filtered = _getFilteredMetrics(report.metrics);
    final abnormalCount = report.highMetricCount + report.lowMetricCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (abnormalCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Phát hiện $abnormalCount chỉ số ngoài khoảng chuẩn (🔴 $abnormalCount bất thường). Vui lòng trao đổi với bác sĩ trong đợt tái khám.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF991B1B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                selected: _filter == _MetricFilter.all,
                label: Text('Tất cả (${report.metrics.length})'),
                onSelected: (_) => setState(() => _filter = _MetricFilter.all),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: _filter == _MetricFilter.all
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _filter == _MetricFilter.all
                      ? AppColors.primary
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: _filter == _MetricFilter.abnormal,
                label: Text('Bất thường ($abnormalCount)'),
                onSelected: (_) =>
                    setState(() => _filter = _MetricFilter.abnormal),
                selectedColor: const Color(0xFFFEE2E2),
                checkmarkColor: const Color(0xFFDC2626),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: _filter == _MetricFilter.abnormal
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _filter == _MetricFilter.abnormal
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: _filter == _MetricFilter.normal,
                label: Text('Bình thường (${report.normalMetricCount})'),
                onSelected: (_) =>
                    setState(() => _filter = _MetricFilter.normal),
                selectedColor: const Color(0xFFDCFCE7),
                checkmarkColor: const Color(0xFF16A34A),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: _filter == _MetricFilter.normal
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _filter == _MetricFilter.normal
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Metric list grouped by category
        for (final category in _extractCategories(filtered)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          ...filtered
              .where((m) => m.category == category)
              .map((m) => _buildMetricCard(m)),
        ],

        const SizedBox(height: 16),
        _buildConclusionCard(report),
      ],
    );
  }

  List<String> _extractCategories(List<LabTestMetric> list) {
    final seen = <String>{};
    final categories = <String>[];
    for (final m in list) {
      if (seen.add(m.category)) {
        categories.add(m.category);
      }
    }
    return categories;
  }

  Widget _buildMetricCard(LabTestMetric metric) {
    final status = metric.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == LabMetricStatus.normal
              ? const Color(0xFFE2E8F0)
              : status.color.withValues(alpha: 0.4),
          width: status == LabMetricStatus.normal ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Name and status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  metric.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status.backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(status.icon, size: 13, color: status.color),
                    const SizedBox(width: 4),
                    Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: status.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Value and Reference range
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${metric.value}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: status == LabMetricStatus.normal
                      ? const Color(0xFF0F172A)
                      : status.color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                metric.unit,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              Text(
                'Khoảng chuẩn: ${metric.referenceRange} ${metric.unit}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Visual Reference Gauge Bar
          _buildRangeGaugeBar(metric),

          if (metric.clinicalInterpretation != null &&
              metric.clinicalInterpretation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      metric.clinicalInterpretation!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF475569),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Thanh biểu thị khoảng chuẩn trực quan (Visual Range Gauge)
  Widget _buildRangeGaugeBar(LabTestMetric metric) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // Marker alignment: -1.0 is low, 0.0 is center of normal, 1.0 is high
        final double markerOffset;
        switch (metric.status) {
          case LabMetricStatus.low:
            markerOffset = totalWidth * 0.15;
            break;
          case LabMetricStatus.normal:
            markerOffset = totalWidth * 0.50;
            break;
          case LabMetricStatus.high:
            markerOffset = totalWidth * 0.85;
            break;
        }

        return Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      // Low zone (Yellow)
                      Container(
                        height: 6,
                        width: totalWidth * 0.28,
                        color: const Color(0xFFFDE68A),
                      ),
                      const SizedBox(width: 2),
                      // Normal zone (Green)
                      Container(
                        height: 6,
                        width: totalWidth * 0.44 - 4,
                        color: const Color(0xFF86EFAC),
                      ),
                      const SizedBox(width: 2),
                      // High zone (Red)
                      Container(
                        height: 6,
                        width: totalWidth * 0.28,
                        color: const Color(0xFFFCA5A5),
                      ),
                    ],
                  ),
                ),
                // Indicator Pin
                Positioned(
                  left: (markerOffset - 4).clamp(0.0, totalWidth - 8),
                  top: -3,
                  child: Container(
                    width: 8,
                    height: 12,
                    decoration: BoxDecoration(
                      color: metric.status.color,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Thấp', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                Text('Chuẩn', style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                Text('Cao', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildImagingTab(LabReport report) {
    if (report.imagingList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined, size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 12),
              Text('Chưa có hình ảnh CĐHA trong lượt khám này.'),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (final item in report.imagingList) _buildImagingCard(item),
        const SizedBox(height: 16),
        _buildConclusionCard(report),
      ],
    );
  }

  Widget _buildImagingCard(ImagingItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.modality,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.performingDoctor} • ${item.capturedDate}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Embedded Preview Box
          GestureDetector(
            onTap: () => MedicalImagingViewer.showFullScreen(context, item),
            child: Container(
              height: 200,
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MedicalImagingViewer(
                      item: item,
                      initialInvert: false,
                      isThumbnail: true,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in_rounded,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Chạm để Phóng to / Thu nhỏ',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Findings section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.description_outlined,
                        size: 15, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Mô tả hình ảnh & Kết luận chuyên khoa:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    item.findings,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.fullscreen_rounded, size: 18),
                    label: const Text(
                      'Xem Toàn màn hình & Tương tác PACS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () =>
                        MedicalImagingViewer.showFullScreen(context, item),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConclusionCard(LabReport report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.assignment_turned_in_outlined,
                  color: Color(0xFF0284C7), size: 18),
              SizedBox(width: 8),
              Text(
                'KẾT LUẬN CẬN LÂM SÀNG TỔNG HỢP',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0284C7),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Text(
              report.generalConclusion,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0C4A6E),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bác sĩ Cận lâm sàng ký số:',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.diagnostician,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text(
                      'PKI Đã xác thực',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
