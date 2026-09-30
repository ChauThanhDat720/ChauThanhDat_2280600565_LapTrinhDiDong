import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../../../core/theme/app_theme.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key, this.initialText});

  final String? initialText;

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();
  late final TextEditingController _input;

  OnDeviceTranslator? _translator;
  bool _viToEn = true;
  bool _preparingModel = true;
  bool _translating = false;
  String _modelStatus = 'Đang kiểm tra mô hình ngôn ngữ...';
  String _result = '';

  TranslateLanguage get _sourceLanguage =>
      _viToEn ? TranslateLanguage.vietnamese : TranslateLanguage.english;

  TranslateLanguage get _targetLanguage =>
      _viToEn ? TranslateLanguage.english : TranslateLanguage.vietnamese;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.initialText ?? '');
    _input.addListener(_refreshInputActions);
    _prepareModels();
  }

  void _refreshInputActions() {
    if (mounted) setState(() {});
  }

  Future<void> _prepareModels() async {
    if (mounted) {
      setState(() {
        _preparingModel = true;
        _modelStatus = 'Đang kiểm tra mô hình ngôn ngữ...';
      });
    }

    try {
      final sourceCode = _sourceLanguage.bcpCode;
      final targetCode = _targetLanguage.bcpCode;
      final downloaded = await Future.wait([
        _modelManager.isModelDownloaded(sourceCode),
        _modelManager.isModelDownloaded(targetCode),
      ]);
      if (!mounted) return;

      if (!downloaded[0] || !downloaded[1]) {
        setState(() => _modelStatus = 'Đang chuẩn bị mô hình ngôn ngữ...');
        if (!downloaded[0]) {
          await _modelManager.downloadModel(sourceCode, isWifiRequired: false);
        }
        if (!downloaded[1]) {
          await _modelManager.downloadModel(targetCode, isWifiRequired: false);
        }
      }

      if (!mounted) return;
      await _translator?.close();
      if (!mounted) return;
      _translator = OnDeviceTranslator(
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
      );
      if (!mounted) return;

      setState(() {
        _preparingModel = false;
        _modelStatus = 'Sẵn sàng';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _preparingModel = false;
        _modelStatus = 'Có lỗi khi chuẩn bị mô hình';
      });
      _showMessage(
        'Không thể tải mô hình ngôn ngữ. Vui lòng kiểm tra kết nối mạng.',
      );
    }
  }

  Future<void> _translate() async {
    final text = _input.text.trim();
    if (text.isEmpty) {
      _showMessage('Vui lòng nhập văn bản cần dịch.');
      return;
    }
    if (_preparingModel || _translating) return;

    if (_translator == null) {
      await _prepareModels();
      if (!mounted || _translator == null) return;
    }

    setState(() {
      _translating = true;
      _modelStatus = 'Đang dịch...';
    });

    try {
      final translated = await _translator!.translateText(text);
      if (!mounted) return;
      setState(() => _result = translated);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Không thể dịch văn bản. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() {
          _translating = false;
          _modelStatus = _translator == null ? 'Có lỗi' : 'Sẵn sàng';
        });
      }
    }
  }

  Future<void> _swapLanguages() async {
    if (_preparingModel || _translating) return;

    setState(() {
      _viToEn = !_viToEn;
      _result = '';
    });
    await _prepareModels();
  }

  Future<void> _copyResult() async {
    if (_result.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _result));
    if (!mounted) return;
    _showMessage('Đã sao chép bản dịch.');
  }

  void _clearInput() {
    _input.clear();
    setState(() => _result = '');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _input.removeListener(_refreshInputActions);
    _input.dispose();
    _translator?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _preparingModel || _translating;
    final sourceName = _viToEn ? 'Tiếng Việt' : 'Tiếng Anh';
    final targetName = _viToEn ? 'Tiếng Anh' : 'Tiếng Việt';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dịch văn bản',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFE4F4F5),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.translate_rounded,
                    size: 52,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Dịch thuật thông minh',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Dịch văn bản giữa tiếng Việt và tiếng Anh bằng Google ML Kit.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _LanguageLabel(
                    label: sourceName,
                    icon: Icons.language_rounded,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: busy ? null : _swapLanguages,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  tooltip: 'Đổi ngôn ngữ',
                ),
                Expanded(
                  child: _LanguageLabel(
                    label: targetName,
                    icon: Icons.translate_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _input,
              minLines: 5,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Văn bản cần dịch',
                hintText: 'Nhập nội dung...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _input.text.isEmpty ? null : _clearInput,
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Xóa'),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F8F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  if (busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.primary,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _modelStatus,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : _translate,
              icon: _translating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.translate_rounded),
              label: Text(_translating ? 'Đang dịch...' : 'Dịch'),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kết quả dịch',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: _result.isEmpty ? null : _copyResult,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Sao chép'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 130),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _result.isEmpty ? 'Bản dịch sẽ hiển thị ở đây.' : _result,
                style: TextStyle(
                  color: _result.isEmpty ? AppColors.mutedText : AppColors.text,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mô hình ML Kit được xử lý trực tiếp trên thiết bị sau khi tải xuống.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageLabel extends StatelessWidget {
  const _LanguageLabel({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: AppColors.primary),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}
