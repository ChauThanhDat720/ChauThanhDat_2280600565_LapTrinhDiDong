import '../../../core/repositories/application_backend.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/family_repository.dart';
import '../domain/family_member.dart';
import 'family_profile_manager.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key, this.repository});

  final FamilyRepository? repository;

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  late FamilyRepository _repository;
  bool _isLoading = true;
  List<FamilyMember> _members = [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApplicationBackend.repositories.family;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await _repository.getMembers();
      if (mounted) {
        setState(() {
          _members = items;
          _isLoading = false;
        });
        FamilyProfileManager.instance.updateMemberList(items);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh sách người thân: $e')),
        );
      }
    }
  }

  Future<void> _openAddEditDialog([FamilyMember? memberToEdit]) async {
    final result = await showDialog<FamilyMember>(
      context: context,
      builder: (ctx) => _AddEditFamilyMemberDialog(
        member: memberToEdit,
        repository: _repository,
      ),
    );

    if (result != null && mounted) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu hồ sơ gia đình trên thiết bị.')),
      );
    }
  }

  Future<void> _confirmDelete(FamilyMember member) async {
    if (member.isSelf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa hồ sơ chính của Bản thân.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa thành viên'),
        content: Text(
          'Bạn có chắc chắn muốn xóa hồ sơ của "${member.fullName}" khỏi danh sách gia đình không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteMember(member.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa "${member.fullName}" thành công.'),
              backgroundColor: AppColors.primary,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  Future<void> _setActiveMember(FamilyMember member) async {
    try {
      final saved = await _repository.setDefaultMember(member.id);
      FamilyProfileManager.instance.switchMember(saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lưu hồ sơ mặc định: $e')),
        );
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chọn "${member.fullName}" làm hồ sơ đang xem.'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 2),
        ),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = FamilyProfileManager.instance.activeMember;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Hồ sơ Sức khỏe Gia đình'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Thêm người thân',
            onPressed: () => _openAddEditDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card giới thiệu
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            child: const Icon(
                              Icons.family_restroom_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chăm sóc cả gia đình',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Dễ dàng đặt lịch khám, quản lý đơn thuốc và theo dõi huyết áp cho Bố Mẹ và Con nhỏ.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Danh sách thành viên (${_members.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _openAddEditDialog(),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Thêm người thân',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Danh sách thành viên
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _members.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (ctx, index) {
                        final member = _members[index];
                        final isSelected = active?.id == member.id;

                        return _FamilyMemberCard(
                          member: member,
                          isSelected: isSelected,
                          onSelect: () => _setActiveMember(member),
                          onEdit: () => _openAddEditDialog(member),
                          onDelete: () => _confirmDelete(member),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  const _FamilyMemberCard({
    required this.member,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final FamilyMember member;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Avatar, Info & Options
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: member.avatarColor.withValues(alpha: 0.15),
                  child: Icon(
                    member.relationshipIcon,
                    color: member.avatarColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              member.fullName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: member.avatarColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              member.relationshipLabel,
                              style: TextStyle(
                                color: member.avatarColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${member.gender} • ${member.formattedAge} ${member.phone != null ? "• ${member.phone}" : ""}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // Thông tin BHYT & Nhóm máu
            if (member.bhytCode != null && member.bhytCode!.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.credit_card_rounded,
                      color: Color(0xFF16A34A),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Thẻ BHYT: ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                    ),
                    Text(
                      member.bhytCode!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    if (member.bloodType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Máu: ${member.bloodType}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Tiền sử bệnh lý
            if (member.medicalHistory != null &&
                member.medicalHistory!.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 15,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tiền sử: ${member.medicalHistory!}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Bottom actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: Color(0xFF16A34A),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Hồ sơ đang xem',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                    onPressed: onSelect,
                    icon: const Icon(Icons.visibility_rounded, size: 14),
                    label: const Text(
                      'Xem hồ sơ này',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      tooltip: 'Chỉnh sửa',
                      onPressed: onEdit,
                    ),
                    if (!member.isSelf)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Color(0xFFDC2626),
                        ),
                        tooltip: 'Xóa thành viên',
                        onPressed: onDelete,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEditFamilyMemberDialog extends StatefulWidget {
  const _AddEditFamilyMemberDialog({this.member, required this.repository});

  final FamilyMember? member;
  final FamilyRepository repository;

  @override
  State<_AddEditFamilyMemberDialog> createState() =>
      _AddEditFamilyMemberDialogState();
}

class _AddEditFamilyMemberDialogState
    extends State<_AddEditFamilyMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _bhytController;
  late TextEditingController _cccdController;
  late TextEditingController _historyController;

  late FamilyRelationship _relationship;
  DateTime? _dateOfBirth;
  String _gender = 'Nam';
  String? _bloodType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _nameController = TextEditingController(text: m?.fullName ?? '');
    _phoneController = TextEditingController(text: m?.phone ?? '');
    _bhytController = TextEditingController(text: m?.bhytCode ?? '');
    _cccdController = TextEditingController(text: m?.identityCard ?? '');
    _historyController = TextEditingController(text: m?.medicalHistory ?? '');
    _relationship = m?.relationship ?? FamilyRelationship.mother;
    _dateOfBirth = m?.dateOfBirth;
    _gender = m?.gender ?? 'Nam';
    _bloodType = m?.bloodType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bhytController.dispose();
    _cccdController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1985, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final isEdit = widget.member != null;
      final member = FamilyMember(
        id: widget.member?.id ?? '',
        primaryPatientId:
            widget.member?.primaryPatientId ?? 'test-patient-sub-123',
        fullName: _nameController.text.trim(),
        relationship: _relationship,
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        bhytCode: _bhytController.text.trim().isNotEmpty
            ? _bhytController.text.trim()
            : null,
        identityCard: _cccdController.text.trim().isNotEmpty
            ? _cccdController.text.trim()
            : null,
        bloodType: _bloodType,
        medicalHistory: _historyController.text.trim().isNotEmpty
            ? _historyController.text.trim()
            : null,
        isDefault: widget.member?.isDefault ?? false,
        avatar: widget.member?.avatar,
        createdAt: widget.member?.createdAt,
      );

      FamilyMember saved;
      if (isEdit) {
        saved = await widget.repository.updateMember(member);
      } else {
        saved = await widget.repository.createMember(member);
      }

      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi lưu thông tin: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.member != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isEdit
                            ? 'Sửa thông tin người thân'
                            : 'Thêm người thân vào gia đình',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Họ và tên
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên *',
                    hintText: 'Ví dụ: Trần Thị Mai',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Vui lòng nhập họ tên'
                      : null,
                ),
                const SizedBox(height: 12),

                // Mối quan hệ
                DropdownButtonFormField<FamilyRelationship>(
                  initialValue: _relationship,
                  decoration: const InputDecoration(
                    labelText: 'Mối quan hệ *',
                    prefixIcon: Icon(Icons.family_restroom_outlined),
                  ),
                  items: FamilyRelationship.values
                      .where(
                        (r) => widget.member?.isSelf == true
                            ? r == FamilyRelationship.self
                            : r != FamilyRelationship.self,
                      )
                      .map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Row(
                            children: [
                              Icon(r.icon, size: 18, color: r.color),
                              const SizedBox(width: 8),
                              Text(r.label),
                            ],
                          ),
                        );
                      })
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _relationship = val);
                  },
                ),
                const SizedBox(height: 12),

                // Ngày sinh & Giới tính
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDateOfBirth,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Ngày sinh',
                            prefixIcon: Icon(Icons.cake_outlined),
                          ),
                          child: Text(
                            _dateOfBirth != null
                                ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                                : 'Chọn ngày',
                            style: TextStyle(
                              color: _dateOfBirth != null
                                  ? Colors.black
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Giới tính',
                          prefixIcon: Icon(Icons.wc_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                          DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                          DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _gender = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Số điện thoại & Nhóm máu
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _bloodType,
                        decoration: const InputDecoration(
                          labelText: 'Nhóm máu',
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Chưa rõ')),
                          DropdownMenuItem(value: 'A+', child: Text('A+')),
                          DropdownMenuItem(value: 'B+', child: Text('B+')),
                          DropdownMenuItem(value: 'O+', child: Text('O+')),
                          DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                          DropdownMenuItem(value: 'A-', child: Text('A-')),
                          DropdownMenuItem(value: 'B-', child: Text('B-')),
                          DropdownMenuItem(value: 'O-', child: Text('O-')),
                          DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                        ],
                        onChanged: (v) => setState(() => _bloodType = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _cccdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số CCCD / Giấy tờ tùy thân (nếu có)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // Thẻ BHYT
                TextFormField(
                  controller: _bhytController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Mã số thẻ BHYT (nếu có)',
                    hintText: 'Ví dụ: GD4798765432100',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // Tiền sử bệnh lý / dị ứng
                TextFormField(
                  controller: _historyController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Tiền sử bệnh lý & Dị ứng thuốc',
                    hintText:
                        'Ví dụ: Tăng huyết áp 5 năm, dị ứng Penicillin...',
                    prefixIcon: Icon(Icons.medical_information_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                // Nút lưu
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isEdit ? 'Cập nhật hồ sơ' : 'Lưu hồ sơ người thân',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
