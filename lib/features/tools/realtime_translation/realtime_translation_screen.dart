import 'package:flutter/material.dart';

import '../ocr/ocr_screen.dart';

/// Entry point for the optional camera-to-translation experience.
class RealtimeTranslationScreen extends StatelessWidget {
  const RealtimeTranslationScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dịch qua camera')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Chụp ảnh để nhận diện và dịch ngay',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Luồng Camera → ML Kit Text Recognition → Google ML Kit Translate được thực hiện qua công cụ quét ảnh.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const OcrScreen())),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Mở camera'),
            ),
          ],
        ),
      ),
    ),
  );
}
