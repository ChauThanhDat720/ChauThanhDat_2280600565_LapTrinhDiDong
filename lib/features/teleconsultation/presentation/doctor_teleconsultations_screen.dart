import '../../../core/repositories/application_backend.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/teleconsultation_repository.dart';
import '../domain/teleconsultation.dart';
import 'post_care_chat_screen.dart';

class DoctorTeleconsultationsScreen extends StatefulWidget {
  const DoctorTeleconsultationsScreen({
    super.key,
    this.doctorId = 'dr-linh',
    this.doctorName = 'BS. Trần Thảo Linh',
    TeleconsultationRepository? repository,
  }) : _providedRepository = repository;

  final String doctorId;
  final String doctorName;
  final TeleconsultationRepository? _providedRepository;
  TeleconsultationRepository get repository =>
      _providedRepository ?? ApplicationBackend.repositories.teleconsultations;

  @override
  State<DoctorTeleconsultationsScreen> createState() =>
      _DoctorTeleconsultationsScreenState();
}

class _DoctorTeleconsultationsScreenState
    extends State<DoctorTeleconsultationsScreen> {
  bool _loading = true;
  List<TeleconsultationSession> _sessions = [];
  String _selectedFilter = 'all'; // 'all', 'needs_reply', 'active', 'closed'

  @override
  void initState() {
    super.initState();
    _loadSessions();
    TeleconsultationStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    TeleconsultationStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    try {
      final items = await widget.repository.getDoctorSessions(widget.doctorId);
      if (mounted) {
        setState(() {
          _sessions = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TeleconsultationSession> get _filteredSessions {
    switch (_selectedFilter) {
      case 'needs_reply':
        return _sessions.where((s) => s.unreadCount > 0 && s.canChat).toList();
      case 'active':
        return _sessions.where((s) => s.canChat).toList();
      case 'closed':
        return _sessions.where((s) => !s.canChat).toList();
      default:
        return _sessions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSessions;

    return Scaffold(
      appBar: AppBar(title: const Text('Tư vấn Y tế Hậu khám (7 ngày)')),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'Tất cả (${_sessions.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'needs_reply',
                  'Chờ phản hồi (${_sessions.where((s) => s.unreadCount > 0 && s.canChat).length})',
                  icon: Icons.mark_chat_unread_rounded,
                  color: const Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'active',
                  'Đang mở (${_sessions.where((s) => s.canChat).length})',
                  icon: Icons.timelapse_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'closed',
                  'Đã đóng (${_sessions.where((s) => !s.canChat).length})',
                  icon: Icons.lock_outline,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Không có ca tư vấn hậu khám nào trong mục này.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadSessions,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (ctx, index) {
                        final session = filtered[index];
                        return _buildSessionCard(session);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String key,
    String label, {
    IconData? icon,
    Color? color,
  }) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = key),
      avatar: icon != null
          ? Icon(icon, size: 16, color: isSelected ? Colors.white : color)
          : null,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSessionCard(TeleconsultationSession session) {
    final hasUnread = session.unreadCount > 0 && session.canChat;

    return Card(
      elevation: hasUnread ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: hasUnread
              ? AppColors.primary.withValues(alpha: 0.6)
              : const Color(0xFFE2E8F0),
          width: hasUnread ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostCareChatScreen(
                appointmentId: session.appointmentId,
                sessionId: session.id,
                isDoctorView: true,
                currentUserId: widget.doctorId,
                currentUserName: widget.doctorName,
                repository: widget.repository,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE0F2FE),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              session.patientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            if (hasUnread) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${session.unreadCount} tin mới',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Mã ca khám: ${session.appointmentId} • ${session.department}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildRemainingChip(session),
                ],
              ),
              const SizedBox(height: 10),
              if (session.diagnosis?.isNotEmpty == true) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.medical_information_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Chẩn đoán: ${session.diagnosis}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (session.lastMessage?.isNotEmpty == true) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                      color: hasUnread
                          ? AppColors.primary
                          : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${session.lastMessageSender != null ? "${session.lastMessageSender}: " : ""}${session.lastMessage}',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread
                              ? Colors.black87
                              : Colors.grey.shade700,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Chạm để mở hội thoại ➔',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemainingChip(TeleconsultationSession session) {
    Color bg;
    Color fg;
    if (session.isClosed) {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
    } else if (session.isExpired) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
    } else {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF059669);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        session.remainingLabel,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
