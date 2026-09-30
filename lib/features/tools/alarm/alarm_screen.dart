import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/theme/app_theme.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});
  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final _speech = stt.SpeechToText();
  String _phrase = 'Nhấn micro rồi nói, ví dụ: đặt báo thức lúc 7 giờ 30';
  String _status = 'Chưa đặt báo thức';
  bool _listening = false;
  bool _english = false;
  bool _demoOffline = false;
  TimeOfDay? _alarm;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _listen() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if (mounted) setState(() => _listening = status == 'listening');
      },
    );
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thiết bị chưa sẵn sàng nhận giọng nói.'),
          ),
        );
      }
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: _english ? 'en_US' : 'vi_VN',
      ),
      onResult: (result) {
        if (mounted) setState(() => _phrase = result.recognizedWords);
      },
    );
  }

  void _setAlarm() {
    final matches = RegExp(r'(\d{1,2})\s*(?:giờ|h|:)\s*(\d{0,2})')
        .firstMatch(_phrase.toLowerCase());
    if (matches == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy nói dạng: đặt báo thức lúc 7 giờ 30.'),
        ),
      );
      return;
    }
    final hour = int.parse(matches.group(1)!);
    final minute = matches.group(2)!.isEmpty ? 0 : int.parse(matches.group(2)!);
    if (hour > 23 || minute > 59) {
      return;
    }
    _timer?.cancel();
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    _timer = Timer(when.difference(now), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('⏰ Báo thức'),
            content: const Text('Đã đến giờ hẹn.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tắt'),
              ),
            ],
          ),
        );
      }
    });
    setState(() {
      _alarm = TimeOfDay(hour: hour, minute: minute);
      _status =
          'Đã đặt báo thức lúc ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    });
  }

  void _showDemoPhrase() => setState(() {
    _phrase = _english ? 'set alarm at 7:30' : 'đặt báo thức lúc 7 giờ 30';
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Báo thức bằng giọng nói')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Tiếng Việt')),
            ButtonSegment(value: true, label: Text('English')),
          ],
          selected: {_english},
          onSelectionChanged: (value) => setState(() => _english = value.first),
        ),
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _demoOffline,
          onChanged: (value) => setState(() => _demoOffline = value),
          title: const Text('Chế độ demo offline'),
          subtitle: const Text('Tạo câu lệnh báo thức mẫu, không cần mạng.'),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFE4F4F5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.alarm_rounded,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 10),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_alarm != null)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Báo thức hoạt động khi ứng dụng đang mở.',
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(_phrase, style: const TextStyle(fontSize: 16, height: 1.5)),
        const SizedBox(height: 24),
        Center(
          child: FloatingActionButton.large(
            onPressed: _demoOffline ? _showDemoPhrase : _listen,
            backgroundColor: _listening ? Colors.redAccent : AppColors.primary,
            child: Icon(
              _demoOffline
                  ? Icons.auto_awesome
                  : _listening
                  ? Icons.stop
                  : Icons.mic,
              size: 35,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _listening
                ? 'Đang nghe...'
                : _english
                ? 'Tap to speak English'
                : 'Nhấn để nói tiếng Việt',
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _setAlarm,
          icon: const Icon(Icons.alarm_add),
          label: const Text('Xác nhận báo thức'),
        ),
        const SizedBox(height: 18),
        const Text(
          'Hỗ trợ ví dụ: “đặt báo thức lúc 7 giờ 30”. Màn này dùng Speech-to-Text và bộ hẹn giờ trong ứng dụng; báo thức nền/hệ thống là phần mở rộng tùy chọn.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedText, height: 1.4),
        ),
      ],
    ),
  );
}
