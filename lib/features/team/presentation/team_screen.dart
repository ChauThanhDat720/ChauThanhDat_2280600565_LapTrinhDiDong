import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _controller = PageController(viewportFraction: .82);
  int _page = 0;
  final _members = const [
    ('Nguyễn Minh Anh', 'UI/UX & Flutter', Icons.palette_outlined),
    ('Trần Thảo Linh', 'ML Kit & OCR', Icons.document_scanner_outlined),
    ('Lê Anh Tuấn', 'Speech & Integration', Icons.record_voice_over_outlined),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thông tin nhóm')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Text(
            'Vuốt ngang để xem thông tin từng thành viên.',
            style: TextStyle(color: AppColors.mutedText),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: _members.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (_, index) {
              final member = _members[index];
              return Padding(
                padding: const EdgeInsets.all(14),
                child: Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 58,
                          backgroundColor: const Color(0xFFE4F4F5),
                          child: Icon(
                            member.$3,
                            size: 58,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          member.$1,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          member.$2,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Smart Hospital project team',
                          style: TextStyle(color: AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _members.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: index == _page ? AppColors.primary : AppColors.border,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}
