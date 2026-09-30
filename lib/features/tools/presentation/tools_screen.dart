import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../alarm/alarm_screen.dart';
import '../ocr/ocr_screen.dart';
import '../../patient_tracking/presentation/patient_tracking_screen.dart';
import '../realtime_translation/realtime_translation_screen.dart';
import '../speech/speech_screen.dart';
import '../translation/translation_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = <ToolDefinition>[
      const ToolDefinition(
        icon: Icons.mic_rounded,
        title: 'Giọng nói thành văn bản',
        description: 'Chuyển giọng nói tiếng Việt thành văn bản',
        screen: SpeechScreen(),
      ),
      const ToolDefinition(
        icon: Icons.translate_rounded,
        title: 'Dịch văn bản',
        description: 'Dịch nội dung giữa tiếng Việt và tiếng Anh',
        screen: TranslationScreen(),
      ),
      const ToolDefinition(
        icon: Icons.document_scanner_rounded,
        title: 'Quét văn bản',
        description: 'Nhận diện văn bản từ hình ảnh',
        screen: OcrScreen(),
      ),
      const ToolDefinition(
        icon: Icons.camera_alt_rounded,
        title: 'Dịch bằng camera',
        description: 'Nhận diện và dịch nội dung từ camera',
        screen: RealtimeTranslationScreen(),
      ),
      const ToolDefinition(
        icon: Icons.alarm_rounded,
        title: 'Báo thức',
        description: 'Đặt thời gian nhắc nhở',
        screen: AlarmScreen(),
      ),
      const ToolDefinition(
        icon: Icons.center_focus_strong_rounded,
        title: 'Theo dõi đối tượng',
        description: 'Theo dõi tạm thời đối tượng qua camera đã được đồng ý',
        screen: PatientTrackingScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Công cụ')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 900
              ? 4
              : constraints.maxWidth >= 600
              ? 3
              : 2;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Công cụ thông minh',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Các tiện ích hỗ trợ người dùng trong quá trình sử dụng Smart Hospital.',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ToolCard(tool: tools[index]),
                    childCount: tools.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 178,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ToolCard extends StatelessWidget {
  const ToolCard({super.key, required this.tool});

  final ToolDefinition tool;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => tool.screen)),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE4F4F5),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(tool.icon, color: AppColors.primary),
            ),
            const Spacer(),
            Text(
              tool.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              tool.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.mutedText,
                height: 1.25,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ToolDefinition {
  const ToolDefinition({
    required this.icon,
    required this.title,
    required this.description,
    required this.screen,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget screen;
}
