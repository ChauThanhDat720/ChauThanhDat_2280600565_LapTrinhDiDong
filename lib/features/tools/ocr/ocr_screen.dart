import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../translation/translation_screen.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _recognizedText = TextEditingController();
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  XFile? _image;
  bool _processing = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _recognizedText.addListener(_refreshActions);
  }

  void _refreshActions() {
    if (mounted) setState(() {});
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_processing) return;

    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image == null) return;

      final imageFile = File(image.path);
      if (!await imageFile.exists()) {
        if (mounted) {
          _showMessage('Không thể nhận diện văn bản. Vui lòng thử lại.');
        }
        return;
      }
      if (!mounted) return;

      _recognizedText.clear();
      setState(() {
        _image = image;
        _processing = true;
        _status = 'Đang nhận diện văn bản...';
      });

      final result = await _textRecognizer.processImage(
        InputImage.fromFilePath(image.path),
      );
      if (!mounted) return;

      _recognizedText.text = result.text.trim();
      setState(() {
        _status = _recognizedText.text.isEmpty
            ? 'Không tìm thấy văn bản trong hình ảnh.'
            : 'Đã nhận diện văn bản';
      });

      if (_recognizedText.text.isEmpty) {
        _showMessage('Không tìm thấy văn bản trong hình ảnh.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = 'Có lỗi khi nhận diện văn bản');
      _showMessage('Không thể nhận diện văn bản. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _copyText() async {
    final text = _recognizedText.text.trim();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showMessage('Đã sao chép văn bản.');
  }

  void _clearResult() {
    _recognizedText.clear();
    setState(() {
      _image = null;
      _status = '';
    });
  }

  void _openTranslation() {
    final text = _recognizedText.text.trim();
    if (text.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TranslationScreen(initialText: text)),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _recognizedText.removeListener(_refreshActions);
    _recognizedText.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _recognizedText.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quét văn bản',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      Icons.document_scanner_rounded,
                      size: 56,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Nhận diện văn bản từ hình ảnh',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Chụp ảnh hoặc chọn ảnh để Smart Hospital nhận diện nội dung bằng Google ML Kit.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _processing
                          ? null
                          : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Chụp ảnh'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _processing
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Chọn từ thư viện'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    File(_image!.path),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          height: 160,
                          child: Center(child: Text('Không thể hiển thị ảnh.')),
                        ),
                  ),
                ),
              if (_image != null) const SizedBox(height: 16),
              if (_processing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'Đang nhận diện văn bản...',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Văn bản nhận diện',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: hasText ? _copyText : null,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Sao chép'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _recognizedText,
                minLines: 6,
                maxLines: 12,
                readOnly: _processing,
                decoration: const InputDecoration(
                  hintText: 'Văn bản nhận diện sẽ hiển thị ở đây.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: hasText && !_processing ? _openTranslation : null,
                icon: const Icon(Icons.translate_rounded),
                label: const Text('Dịch văn bản'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: (_image != null || hasText) && !_processing
                    ? _clearResult
                    : null,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Xóa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
