import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../appointments/data/appointment_repository.dart';
import '../../doctors/domain/doctor.dart';
import '../../doctors/presentation/doctor_screens.dart';
import '../../family/presentation/family_profile_manager.dart';
import '../data/vaccination_repository.dart';
import '../domain/vaccination_record.dart';
import 'add_vaccination_screen.dart';
import 'widgets/vaccine_passport_card.dart';

class VaccinationPassportScreen extends StatefulWidget {
  const VaccinationPassportScreen({
    super.key,
    this.repository = const RemoteVaccinationRepository(),
    this.appointmentRepository = const LocalAppointmentRepository(),
  });

  final VaccinationRepository repository;
  final AppointmentRepository appointmentRepository;

  @override
  State<VaccinationPassportScreen> createState() => _VaccinationPassportScreenState();
}

class _VaccinationPassportScreenState extends State<VaccinationPassportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedFamilyMemberId = 'all';
  List<VaccineProtocolGroup> _protocols = [];
  bool _loadingProtocols = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    VaccinationStore.instance.seedIfEmpty();
    _loadProtocols();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProtocols() async {
    try {
      final list = await widget.repository.getProtocols();
      if (mounted) {
        setState(() {
          _protocols = list;
          _loadingProtocols = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProtocols = false);
    }
  }

  List<VaccinationRecord> _getFilteredRecords(List<VaccinationRecord> allRecords) {
    if (_selectedFamilyMemberId == 'all') {
      return allRecords;
    }
    return allRecords.where((r) => r.familyMemberId == _selectedFamilyMemberId).toList();
  }

  void _openAddVaccination() async {
    final activeMember = FamilyProfileManager.instance.activeMember;
    final patientName = activeMember?.fullName ?? 'Nguyễn Văn An';
    final familyMemberId = activeMember?.id ?? 'fam-self';

    final res = await Navigator.of(context).push<VaccinationRecord>(
      MaterialPageRoute(
        builder: (_) => AddVaccinationScreen(
          patientName: patientName,
          familyMemberId: familyMemberId,
          repository: widget.repository,
        ),
      ),
    );
    if (res != null && mounted) {
      setState(() {});
    }
  }

  void _bookVaccineAppointment(String vaccineName) {
    final doc = doctors.firstWhere(
      (d) => d.department.contains('Nhi') || d.department.contains('Tổng quát'),
      orElse: () => doctors.first,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookAppointmentScreen(
          doctor: doc,
          initialReason: 'Tiêm chủng vắc-xin: $vaccineName (Theo phác đồ)',
          repository: widget.appointmentRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VaccinationStore.instance,
      builder: (context, _) {
        final allRecords = VaccinationStore.instance.records;
        final filteredRecords = _getFilteredRecords(allRecords);
        final upcomingList = filteredRecords.where((r) => r.nextDoseDate != null).toList()
          ..sort((a, b) => a.nextDoseDate!.compareTo(b.nextDoseDate!));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sổ Tiêm Chủng & Hộ Chiếu Vắc-Xin'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                tooltip: 'Thêm mũi tiêm',
                onPressed: _openAddVaccination,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: false,
              tabs: [
                Tab(
                  icon: const Icon(Icons.menu_book_rounded),
                  text: 'Sổ tiêm (${filteredRecords.length})',
                ),
                const Tab(
                  icon: Icon(Icons.verified_user_rounded),
                  text: 'Hộ chiếu vắc-xin',
                ),
                const Tab(
                  icon: Icon(Icons.fact_check_outlined),
                  text: 'Phác đồ chuẩn',
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              // Family Member Filter Chips
              _buildFamilyFilterBar(),

              // Tabs Body
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Immunization Records
                    _buildRecordsTab(filteredRecords, upcomingList),

                    // Tab 2: Vaccine Passport View
                    _buildPassportTab(filteredRecords),

                    // Tab 3: Official Protocols
                    _buildProtocolsTab(filteredRecords),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF0D9488),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Thêm Mũi Tiêm'),
            onPressed: _openAddVaccination,
          ),
        );
      },
    );
  }

  Widget _buildFamilyFilterBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.family_restroom_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            _filterChip('all', 'Tất cả thành viên'),
            const SizedBox(width: 6),
            _filterChip('fam-self', 'Nguyễn Văn An (Bản thân)'),
            const SizedBox(width: 6),
            _filterChip('fam-mother', 'Trần Thị Mai (Mẹ)'),
            const SizedBox(width: 6),
            _filterChip('fam-child', 'Nguyễn Minh Khang (Con)'),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String id, String label) {
    final isSelected = _selectedFamilyMemberId == id;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : AppColors.text,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedFamilyMemberId = id);
      },
    );
  }

  Widget _buildRecordsTab(List<VaccinationRecord> records, List<VaccinationRecord> upcomingList) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.vaccines_outlined, size: 64, color: AppColors.mutedText),
            const SizedBox(height: 12),
            const Text(
              'Chưa có dữ liệu mũi tiêm cho thành viên này',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.mutedText),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Thêm mũi tiêm ngay'),
              onPressed: _openAddVaccination,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // Urgent Reminder Card for Due Soon / Overdue doses
        if (upcomingList.isNotEmpty) ...[
          _buildUpcomingDoseBanner(upcomingList.first),
          const SizedBox(height: 14),
        ],

        // Overview Summary Statistics
        _buildSummaryStatsCard(records),
        const SizedBox(height: 16),

        const Text(
          'Lịch sử các mũi vắc-xin đã tiêm:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),

        ...records.map((r) => _buildRecordCard(r)),
      ],
    );
  }

  Widget _buildUpcomingDoseBanner(VaccinationRecord upcoming) {
    final days = upcoming.daysUntilNextDose ?? 0;
    final isOverdue = upcoming.isOverdue;

    final String countdownText;
    final Color badgeColor;
    final Color bgColor;

    if (isOverdue) {
      countdownText = 'ĐÃ QUÁ HẠN ${days.abs()} NGÀY';
      badgeColor = const Color(0xFFDC2626);
      bgColor = const Color(0xFFFEF2F2);
    } else if (days == 0) {
      countdownText = 'ĐẾN HẠN HÔM NAY';
      badgeColor = const Color(0xFFD97706);
      bgColor = const Color(0xFFFFFBEB);
    } else {
      countdownText = 'CÒN $days NGÀY NỮA';
      badgeColor = const Color(0xFFD97706);
      bgColor = const Color(0xFFFFFBEB);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alarm_on_rounded, color: badgeColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LỊCH HẸN TIÊM CHỦNG SẮP TỚI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  countdownText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mũi ${upcoming.doseNumber + 1}/${upcoming.totalDoses}: ${upcoming.vaccineName}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            'Ngày hẹn tiêm: ${upcoming.nextDoseDateLabel} • Bệnh nhân: ${upcoming.patientName}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: badgeColor,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.calendar_month_rounded, size: 16),
              label: const Text('1 chạm Đặt lịch tiêm chủng tại viện'),
              onPressed: () => _bookVaccineAppointment(upcoming.vaccineName),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatsCard(List<VaccinationRecord> records) {
    final completedCount = records.where((r) => r.isCompleted).length;
    final totalDoses = records.fold<int>(0, (sum, r) => sum + r.doseNumber);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Tổng loại vắc-xin', '${records.length}', Icons.vaccines_rounded, AppColors.primary),
          Container(width: 1, height: 36, color: Colors.grey.shade200),
          _statItem('Số liều đã tiêm', '$totalDoses', Icons.done_all_rounded, const Color(0xFF2563EB)),
          Container(width: 1, height: 36, color: Colors.grey.shade200),
          _statItem('Đủ phác đồ', '$completedCount', Icons.verified_rounded, const Color(0xFF16A34A)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildRecordCard(VaccinationRecord r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.vaccines_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.vaccineName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      Text(
                        'Phòng bệnh: ${r.targetDisease}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: r.isCompleted
                        ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                        : const Color(0xFFD97706).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    r.isCompleted ? 'Hoàn tất' : r.doseProgressLabel,
                    style: TextStyle(
                      color: r.isCompleted ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: r.doseProgressFraction,
                minHeight: 5,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(
                  r.isCompleted ? const Color(0xFF16A34A) : const Color(0xFF0D9488),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                _iconLabel(Icons.calendar_today_rounded, 'Ngày: ${r.administeredDateLabel}'),
                const SizedBox(width: 14),
                _iconLabel(Icons.tag_rounded, 'Lô: ${r.batchNumber}'),
              ],
            ),
            const SizedBox(height: 4),
            _iconLabel(Icons.local_hospital_outlined, r.facilityName),
            const SizedBox(height: 4),
            _iconLabel(Icons.person_outline_rounded, 'Bác sĩ: ${r.doctorName}'),
            const SizedBox(height: 8),

            // Reaction status banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Phản ứng sau 30p: ${r.reactionStatus}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconLabel(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
          ),
        ),
      ],
    );
  }

  Widget _buildPassportTab(List<VaccinationRecord> records) {
    if (records.isEmpty) {
      return const Center(child: Text('Chưa có chứng nhận tiêm chủng nào.'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hộ chiếu tiêm chủng điện tử được xác thực và bảo mật bằng chữ ký số của Bệnh viện Đa khoa Quốc tế Smart Hospital.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF166534), height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ...records.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: VaccinePassportCard(record: r),
            )),
      ],
    );
  }

  Widget _buildProtocolsTab(List<VaccinationRecord> records) {
    if (_loadingProtocols) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF93C5FD)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Phác đồ tiêm chủng quốc gia được khuyến nghị theo từng độ tuổi và nhóm nguy cơ của Bộ Y tế & WHO.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        ..._protocols.map((group) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          group.ageGroup,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),

                // Vaccine items
                ...group.vaccines.map((item) {
                  final existing = records.where((r) => r.vaccineName.toLowerCase().contains(item.name.toLowerCase().split(' ').first)).firstOrNull;
                  final hasDone = existing != null && existing.isCompleted;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text('Phòng ngừa: ${item.target}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                              Text('Phác đồ: ${item.schedule}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF0D9488))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (hasDone)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Đã tiêm đủ', style: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                        else
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () => _bookVaccineAppointment(item.name),
                            child: const Text('Đặt lịch tiêm', style: TextStyle(fontSize: 11)),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}
