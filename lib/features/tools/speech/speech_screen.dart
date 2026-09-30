import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechScreen extends StatefulWidget {
  const SpeechScreen({super.key});

  @override
  State<SpeechScreen> createState() => _SpeechScreenState();
}

class _SpeechScreenState extends State<SpeechScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _available = false;
  bool _listening = false;
  List<stt.LocaleName> _locales = const [];
  String? _localeId;
  String _recognizedText = '';
  String _status = 'Đang khởi tạo...';

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    if (mounted) {
      setState(() => _status = 'Đang khởi tạo...');
    }

    try {
      final available = await _speech.initialize(
        options: [
          stt.SpeechToText.androidIntentLookup,
          stt.SpeechToText.androidNoBluetooth,
        ],
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );
      final locales = available ? await _speech.locales() : <stt.LocaleName>[];
      final hasPermission = await _speech.hasPermission;
      if (!mounted) return;

      final vietnameseLocale = _findVietnameseLocale(locales);
      setState(() {
        _available = available;
        _locales = locales;
        _localeId = vietnameseLocale?.localeId;
        _status = available
            ? vietnameseLocale == null
                  ? 'Sẵn sàng (dùng ngôn ngữ mặc định)'
                  : 'Sẵn sàng'
            : hasPermission
            ? 'Không hỗ trợ nhận diện giọng nói'
            : 'Ứng dụng cần quyền micro để nhận diện giọng nói.';
      });

      if (!available && !hasPermission) {
        _showMessage('Hãy mở Cài đặt ứng dụng để cấp quyền micro rồi thử lại.');
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _available = false;
        _status = 'Có lỗi khi nhận diện giọng nói';
      });
      _showMessage('Không thể khởi tạo nhận diện giọng nói. Vui lòng thử lại.');
    }
  }

  stt.LocaleName? _findVietnameseLocale(List<stt.LocaleName> locales) {
    return _findLocale(locales, _isVietnameseLocale, preferredId: 'vi_vn');
  }

  stt.LocaleName? _findEnglishLocale(List<stt.LocaleName> locales) {
    return _findLocale(locales, _isEnglishLocale, preferredId: 'en_us');
  }

  stt.LocaleName? _findSimplifiedChineseLocale(List<stt.LocaleName> locales) {
    return _findLocale(
      locales,
      _isSimplifiedChineseLocale,
      preferredId: 'zh_cn',
    );
  }

  stt.LocaleName? _findLocale(
    List<stt.LocaleName> locales,
    bool Function(stt.LocaleName locale) matches, {
    required String preferredId,
  }) {
    for (final locale in locales) {
      if (_normalizeLocaleId(locale.localeId) == preferredId) return locale;
    }
    for (final locale in locales) {
      if (matches(locale)) return locale;
    }
    return null;
  }

  List<stt.LocaleName> get _supportedLocales {
    final locales = <stt.LocaleName>[];

    void add(stt.LocaleName? locale) {
      if (locale != null &&
          !locales.any((item) => item.localeId == locale.localeId)) {
        locales.add(locale);
      }
    }

    add(_findVietnameseLocale(_locales));
    add(_findEnglishLocale(_locales));
    add(_findSimplifiedChineseLocale(_locales));
    return locales;
  }

  bool _isVietnameseLocale(stt.LocaleName locale) =>
      _normalizeLocaleId(locale.localeId).startsWith('vi');

  bool _isEnglishLocale(stt.LocaleName locale) =>
      _normalizeLocaleId(locale.localeId).startsWith('en');

  bool _isSimplifiedChineseLocale(stt.LocaleName locale) {
    final localeId = _normalizeLocaleId(locale.localeId);
    return localeId.startsWith('zh_cn') ||
        localeId.startsWith('cmn_cn') ||
        localeId.contains('hans');
  }

  String _normalizeLocaleId(String localeId) =>
      localeId.toLowerCase().replaceAll('-', '_');

  String _languageLabel(String? localeId) {
    final locale = _locales.where((item) => item.localeId == localeId);
    if (locale.isEmpty) return 'ngôn ngữ mặc định';

    final selectedLocale = locale.first;
    if (_isVietnameseLocale(selectedLocale)) return 'tiếng Việt';
    if (_isEnglishLocale(selectedLocale)) return 'tiếng Anh';
    if (_isSimplifiedChineseLocale(selectedLocale)) {
      return 'tiếng Trung giản thể';
    }
    return selectedLocale.name;
  }

  String _localeDisplayName(stt.LocaleName locale) {
    if (_isVietnameseLocale(locale)) return 'Tiếng Việt';
    if (_isEnglishLocale(locale)) return 'Tiếng Anh';
    if (_isSimplifiedChineseLocale(locale)) return 'Tiếng Trung (Giản thể)';
    return locale.name;
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) return;

    if (status == 'listening') {
      setState(() {
        _listening = true;
        _status = 'Đang nghe...';
      });
      return;
    }

    if (status == 'done' || status == 'notListening') {
      setState(() {
        _listening = false;
        if (_status == 'Đang nghe...') _status = 'Đã dừng';
      });
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;

    final permissionError = error.errorMsg.toLowerCase().contains('permission');
    final message = permissionError
        ? 'Ứng dụng cần quyền micro để nhận diện giọng nói.'
        : 'Có lỗi khi nhận diện giọng nói';

    setState(() {
      _listening = false;
      _available = permissionError ? false : _available;
      _status = message;
    });

    _showMessage(
      error.permanent || permissionError
          ? '$message Hãy mở Cài đặt ứng dụng để cấp quyền micro.'
          : 'Không thể nhận diện giọng nói. Vui lòng thử lại.',
    );
  }

  Future<void> _startListening() async {
    if (!_available) {
      await _initializeSpeech();
    }
    if (!mounted || !_available) {
      if (mounted &&
          _status != 'Ứng dụng cần quyền micro để nhận diện giọng nói.') {
        _showMessage('Thiết bị không hỗ trợ nhận diện giọng nói.');
      }
      return;
    }

    setState(() {
      _listening = true;
      _status = 'Đang nghe...';
    });

    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: _localeId,
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 5),
        ),
        onResult: (result) {
          if (!mounted) return;
          setState(() => _recognizedText = result.recognizedWords);
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _status = 'Có lỗi khi nhận diện giọng nói';
      });
      _showMessage('Không thể bắt đầu nhận diện giọng nói. Vui lòng thử lại.');
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;

    setState(() {
      _listening = false;
      _status = 'Đã dừng';
    });
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  void _clearText() {
    setState(() => _recognizedText = '');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supportedLocales = _supportedLocales;
    final usesSystemLocale = _localeId == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Giọng nói thành văn bản',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _clearText,
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Xóa nội dung',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.record_voice_over_rounded,
                  size: 64,
                  color: Color(0xFF0F8B8D),
                ),
                const SizedBox(height: 14),
                Text(
                  'Nhấn micro và nói ${_languageLabel(_localeId)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nội dung được nhận diện trực tiếp từ dịch vụ giọng nói trên thiết bị.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (supportedLocales.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              key: ValueKey(_localeId),
              initialValue: _localeId,
              decoration: const InputDecoration(
                labelText: 'Ngôn ngữ nhận diện',
                prefixIcon: Icon(Icons.language_rounded),
              ),
              items: supportedLocales
                  .map(
                    (locale) => DropdownMenuItem(
                      value: locale.localeId,
                      child: Text(_localeDisplayName(locale)),
                    ),
                  )
                  .toList(),
              onChanged: _listening
                  ? null
                  : (value) => setState(() => _localeId = value),
            ),
            const SizedBox(height: 8),
          ],
          if (_available && usesSystemLocale)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Thiết bị chưa có ngôn ngữ được hỗ trợ, ứng dụng sẽ dùng ngôn ngữ mặc định của hệ thống.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          if (supportedLocales.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Chỉ hiển thị các ngôn ngữ mà dịch vụ nhận diện giọng nói trên thiết bị hỗ trợ.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          Container(
            constraints: const BoxConstraints(minHeight: 180),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              _recognizedText.isEmpty
                  ? 'Nội dung nhận diện sẽ xuất hiện ở đây...'
                  : _recognizedText,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.5,
                color: _recognizedText.isEmpty
                    ? Colors.black45
                    : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0F8B8D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_listening) ...[
            const SizedBox(height: 8),
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.graphic_eq_rounded, color: Color(0xFF0F8B8D)),
                  SizedBox(width: 6),
                  Text(
                    'Đang nghe...',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: FloatingActionButton.large(
              onPressed: _toggleListening,
              backgroundColor: _listening
                  ? Colors.redAccent
                  : const Color(0xFF0F8B8D),
              child: Icon(
                _listening ? Icons.stop_rounded : Icons.mic_rounded,
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _listening ? 'Đang nghe...' : 'Nhấn để bắt đầu',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hãy cấp quyền Microphone. Nếu thiết bị chưa hỗ trợ, hãy bật Google Speech Services hoặc Voice typing trong phần cài đặt.',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
