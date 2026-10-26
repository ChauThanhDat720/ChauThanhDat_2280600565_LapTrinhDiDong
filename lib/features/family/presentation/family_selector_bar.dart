import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/family_repository.dart';
import '../domain/family_member.dart';
import 'family_members_screen.dart';
import 'family_profile_manager.dart';

class FamilySelectorBar extends StatefulWidget {
  const FamilySelectorBar({
    super.key,
    this.repository,
    this.onMemberChanged,
  });

  final FamilyRepository? repository;
  final ValueChanged<FamilyMember>? onMemberChanged;

  @override
  State<FamilySelectorBar> createState() => _FamilySelectorBarState();
}

class _FamilySelectorBarState extends State<FamilySelectorBar> {
  late FamilyRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalFamilyRepository();
    FamilyProfileManager.instance.loadMembers(_repository);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: FamilyProfileManager.instance,
      builder: (context, _) {
        final members = FamilyProfileManager.instance.members;
        final active = FamilyProfileManager.instance.activeMember;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.family_restroom_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Đang xem hồ sơ: ${active?.fullName ?? "Bản thân"}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FamilyMembersScreen(repository: _repository),
                        ),
                      );
                    },
                    child: const Text(
                      'Quản lý gia đình',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...members.map((member) {
                      final isSelected = active?.id == member.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            FamilyProfileManager.instance.switchMember(member);
                            widget.onMemberChanged?.call(member);
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: isSelected
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : member.avatarColor.withValues(alpha: 0.15),
                                  child: Icon(
                                    member.relationshipIcon,
                                    size: 14,
                                    color: isSelected ? Colors.white : member.avatarColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  member.isSelf ? 'Bản thân' : member.fullName,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    // Button Thêm thành viên nhanh
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FamilyMembersScreen(repository: _repository),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text(
                              'Thêm',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
