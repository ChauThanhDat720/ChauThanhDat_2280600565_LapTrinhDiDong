import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../doctors/domain/doctor.dart';
import '../../doctors/presentation/doctor_screens.dart';
import '../data/teleconsultation_repository.dart';
import '../domain/teleconsultation.dart';

class PostCareChatScreen extends StatefulWidget {
  const PostCareChatScreen({
    super.key,
    required this.appointmentId,
    this.sessionId,
    this.isDoctorView = false,
    this.currentUserId,
    this.currentUserName,
    this.repository = const LocalTeleconsultationRepository(),
  });

  final String appointmentId;
  final String? sessionId;
  final bool isDoctorView;
  final String? currentUserId;
  final String? currentUserName;
  final TeleconsultationRepository repository;

  @override
  State<PostCareChatScreen> createState() => _PostCareChatScreenState();
}

class _PostCareChatScreenState extends State<PostCareChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  TeleconsultationSession? _session;
  bool _showPrescriptionSummary = true;
  String? _selectedAttachmentUrl;
  String? _selectedAttachmentName;

  static const List<String> _patientQuickPrompts = [
    '💊 Thuốc này uống trước hay sau bữa ăn ạ?',
    '🤢 Em bị choáng váng nhẹ sau uống, có sao không ạ?',
    '🌿 Em có cần kiêng đồ cay nóng/rượu bia không BS?',
    '🩺 Vết thương hơi ngứa nhẹ có bình thường không ạ?',
  ];

  static const List<String> _doctorQuickPrompts = [
    '👍 Triệu chứng này bình thường khi mới làm quen thuốc, bạn tiếp tục uống đúng liều nhé.',
    '⚠️ Hãy tạm dừng thuốc và đến bệnh viện tái khám sớm để kiểm tra lại.',
    '💧 Bạn nên uống nhiều nước và uống thuốc sau bữa ăn no 30 phút nhé.',
    '🩺 Tiến triển rất tốt, bạn duy trì theo đúng chỉ dẫn của toa thuốc nhé.',
  ];

  static const List<Map<String, String>> _sampleImages = [
    {
      'name': 'Ảnh mẩn ngứa / phát ban da',
      'url': 'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?w=500&auto=format&fit=crop&q=60',
      'icon': '🔴',
    },
    {
      'name': 'Ảnh vỉ thuốc đang sử dụng',
      'url': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=500&auto=format&fit=crop&q=60',
      'icon': '💊',
    },
    {
      'name': 'Ảnh nhiệt kế / máy đo huyết áp',
      'url': 'https://images.unsplash.com/photo-1628771065518-0d82f1938462?w=500&auto=format&fit=crop&q=60',
      'icon': '🩺',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSession();
    TeleconsultationStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    TeleconsultationStore.instance.removeListener(_onStoreChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted || _session == null) return;
    final updated = TeleconsultationStore.instance.findById(_session!.id);
    if (updated != null && mounted) {
      setState(() => _session = updated);
    }
  }

  Future<void> _loadSession() async {
    setState(() => _loading = true);
    try {
      final session = await widget.repository.getOrCreateSession(widget.appointmentId);
      if (mounted) {
        setState(() {
          _session = session;
          _loading = false;
        });
        // Mark messages as read
        widget.repository.markAsRead(
          session.id,
          widget.isDoctorView ? MessageSenderType.doctor : MessageSenderType.patient,
        );
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải phiên tư vấn: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = quickText ?? _textController.text;
    final imgUrl = _selectedAttachmentUrl;
    if (text.trim().isEmpty && imgUrl == null) return;
    if (_session == null || !_session!.canChat) return;

    _textController.clear();
    setState(() {
      _selectedAttachmentUrl = null;
      _selectedAttachmentName = null;
    });

    final senderType = widget.isDoctorView ? MessageSenderType.doctor : MessageSenderType.patient;
    final senderId = widget.currentUserId ?? (widget.isDoctorView ? _session!.doctorId : _session!.patientId);
    final senderName = widget.currentUserName ?? (widget.isDoctorView ? _session!.doctorName : _session!.patientName);

    try {
      await widget.repository.sendMessage(
        _session!.id,
        senderType: senderType,
        senderId: senderId,
        senderName: senderName,
        message: text.trim().isEmpty ? '[Đã gửi hình ảnh triệu chứng]' : text.trim(),
        imageUrl: imgUrl,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gửi tin nhắn: $e')),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Đính kèm hình ảnh triệu chứng',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ..._sampleImages.map(
                (item) => ListTile(
                  leading: Text(item['icon']!, style: const TextStyle(fontSize: 22)),
                  title: Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Hình ảnh mẫu lâm sàng thực tế'),
                  trailing: const Icon(Icons.check_circle_outline, color: AppColors.primary),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedAttachmentUrl = item['url'];
                      _selectedAttachmentName = item['name'];
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _closeSessionByDoctor() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đóng phiên tư vấn hậu khám?'),
        content: const Text(
          'Bạn có chắc chắn muốn kết thúc phiên tư vấn này? Bệnh nhân sẽ không thể gửi thêm câu hỏi sau khi phiên đóng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận kết thúc'),
          ),
        ],
      ),
    );

    if (confirmed == true && _session != null) {
      try {
        await widget.repository.closeSession(
          _session!.id,
          closedByName: widget.currentUserName ?? _session!.doctorName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã đóng phiên tư vấn thành công.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tư vấn y tế hậu khám')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tư vấn y tế hậu khám')),
        body: const Center(child: Text('Không tìm thấy thông tin ca tư vấn.')),
      );
    }

    final session = _session!;
    final isDoctor = widget.isDoctorView;
    final partnerName = isDoctor ? session.patientName : session.doctorName;
    final partnerSubtitle = isDoctor ? 'Bệnh nhân' : session.department;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isDoctor ? const Color(0xFFE0F2FE) : const Color(0xFFCCFBF1),
              child: Icon(
                isDoctor ? Icons.person_rounded : Icons.medical_services_rounded,
                color: isDoctor ? const Color(0xFF0284C7) : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partnerName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    partnerSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          _buildStatusBadge(session),
          if (isDoctor && session.canChat)
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded),
              tooltip: 'Kết thúc tư vấn',
              onPressed: _closeSessionByDoctor,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Sticky Medical Prescription & Diagnosis Accordion
          _buildMedicalSummaryAccordion(session),

          // Chat messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: session.messages.length,
              itemBuilder: (ctx, index) {
                final message = session.messages[index];
                return _buildMessageItem(message);
              },
            ),
          ),

          // Attachment preview thumbnail if chosen
          if (_selectedAttachmentUrl != null) _buildAttachmentPreviewBar(),

          // Quick prompts chips carousel
          if (session.canChat) _buildQuickPromptsBar(isDoctor),

          // Bottom input bar or Closed/Expired notice
          session.canChat
              ? _buildChatInputBar()
              : _buildSessionClosedBanner(session),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TeleconsultationSession session) {
    Color bg;
    Color fg;
    IconData icon;
    if (session.isClosed) {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
      icon = Icons.lock_outline;
    } else if (session.isExpired) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
      icon = Icons.timer_off_outlined;
    } else {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF059669);
      icon = Icons.timelapse_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            session.remainingLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalSummaryAccordion(TeleconsultationSession session) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showPrescriptionSummary = !_showPrescriptionSummary),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined, size: 18, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tóm tắt Bệnh án & Đơn thuốc điều trị',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                  Icon(
                    _showPrescriptionSummary
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: const Color(0xFF16A34A),
                  ),
                ],
              ),
            ),
          ),
          if (_showPrescriptionSummary) ...[
            const Divider(height: 1, color: Color(0xFFBBF7D0)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (session.diagnosis?.isNotEmpty == true) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🩺 Chẩn đoán: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Expanded(
                          child: Text(session.diagnosis!, style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (session.prescription?.isNotEmpty == true) ...[
                    const Text('💊 Toa thuốc:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      session.prescription!,
                      style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF1E293B)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageItem(TeleconsultationMessage message) {
    if (message.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.message,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Determine bubble placement:
    // If viewing as patient: patient on right, doctor on left.
    // If viewing as doctor: doctor on right, patient on left.
    final bool isMyMessage = widget.isDoctorView ? message.isDoctor : message.isPatient;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: message.isDoctor ? const Color(0xFFCCFBF1) : const Color(0xFFE2E8F0),
              child: Icon(
                message.isDoctor ? Icons.medical_services_rounded : Icons.person_rounded,
                size: 16,
                color: message.isDoctor ? AppColors.primary : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMyMessage
                    ? AppColors.primary
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMyMessage ? 16 : 4),
                  bottomRight: Radius.circular(isMyMessage ? 4 : 16),
                ),
                border: Border.all(
                  color: isMyMessage ? AppColors.primary : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMyMessage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.senderName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: message.isDoctor ? AppColors.primary : const Color(0xFF334155),
                            ),
                          ),
                          if (message.isDoctor) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, size: 12, color: AppColors.primary),
                          ],
                        ],
                      ),
                    ),
                  if (message.imageUrl != null) ...[
                    GestureDetector(
                      onTap: () => _showEnlargedImage(message.imageUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 180, maxWidth: 220),
                          color: Colors.grey.shade200,
                          child: Image.network(
                            message.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              height: 120,
                              width: 180,
                              color: const Color(0xFFE2E8F0),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_rounded, color: Colors.grey),
                                  SizedBox(height: 4),
                                  Text('Hình ảnh lâm sàng', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMyMessage ? Colors.white : const Color(0xFF1E293B),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.formattedTime,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMyMessage
                              ? Colors.white.withValues(alpha: 0.75)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      if (isMyMessage) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 13,
                          color: message.isRead ? const Color(0xFF67E8F9) : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEnlargedImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 200,
                  color: Colors.white,
                  child: const Center(child: Text('Không thể tải hình ảnh.')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreviewBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFF1F5F9),
      child: Row(
        children: [
          const Icon(Icons.attachment_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedAttachmentName ?? 'Đã chọn hình ảnh đính kèm',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() {
              _selectedAttachmentUrl = null;
              _selectedAttachmentName = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPromptsBar(bool isDoctor) {
    final prompts = isDoctor ? _doctorQuickPrompts : _patientQuickPrompts;
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, index) {
          final prompt = prompts[index];
          return ActionChip(
            label: Text(prompt, style: const TextStyle(fontSize: 11)),
            backgroundColor: const Color(0xFFF8FAFC),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            onPressed: () => _sendMessage(prompt),
          );
        },
      ),
    );
  }

  Widget _buildChatInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
              tooltip: 'Đính kèm hình ảnh triệu chứng',
              onPressed: _showImagePickerSheet,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.isDoctorView
                      ? 'Nhập lời khuyên hoặc hướng dẫn y khoa...'
                      : 'Hỏi bác sĩ về phản ứng thuốc, triệu chứng...',
                  hintStyle: const TextStyle(fontSize: 13),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              icon: const Icon(Icons.send_rounded, size: 18),
              onPressed: () => _sendMessage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionClosedBanner(TeleconsultationSession session) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.lock_clock_rounded, color: Color(0xFF64748B), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.isClosed
                        ? 'Phiên tư vấn hậu khám này đã được kết thúc.'
                        : 'Thời hạn theo dõi 7 ngày sau khám đã kết thúc.',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Nếu triệu chứng của bạn vẫn tiếp diễn hoặc cần điều chỉnh phác đồ, vui lòng đặt lịch tái khám mới tại bệnh viện hoặc gọi 115 khi khẩn cấp.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: const Text('Đặt lịch tái khám với Bác sĩ'),
                onPressed: () {
                  final doc = doctors.firstWhere(
                    (d) => d.id == session.doctorId,
                    orElse: () => Doctor(
                      id: session.doctorId,
                      name: session.doctorName,
                      departmentId: 'general',
                      department: session.department,
                      specialty: session.department,
                      experience: 'Bác sĩ chuyên khoa',
                      color: const Color(0xFFBDE5E9),
                    ),
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookAppointmentScreen(
                        doctor: doc,
                        isFollowUp: true,
                        parentAppointmentId: session.appointmentId,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
