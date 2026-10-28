import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/theme/app_theme.dart';
import '../../doctors/domain/doctor.dart';
import '../../doctors/presentation/doctor_screens.dart';
import '../domain/symptom_triage.dart';
import '../services/ai_triage_service.dart';

class AiVoiceTriageScreen extends StatefulWidget {
  const AiVoiceTriageScreen({super.key});

  @override
  State<AiVoiceTriageScreen> createState() => _AiVoiceTriageScreenState();
}

class _AiVoiceTriageScreenState extends State<AiVoiceTriageScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final AiTriageService _triageService = const AiTriageService();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isSpeechAvailable = false;
  bool _isListening = false;
  bool _isAnalyzing = false;
  TriageResult? _result;
  late AnimationController _waveController;

  static const List<String> _samplePrompts = [
    '🚨 Tức ngực dữ dội, khó thở lan sang vai trái',
    '⚠️ Sốt cao 39.5 độ, đau họng và ho khan nhiều',
    'Đau vùng thượng vị dạ dày, ợ chua buồn nôn',
    'Sưng đau khớp gối và cứng khớp buổi sáng',
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (_) => setState(() => _isListening = false),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
            _waveController.stop();
          }
        },
      );
      if (mounted) setState(() => _isSpeechAvailable = available);
    } catch (_) {}
  }

  @override
  void dispose() {
    _waveController.dispose();
    _textController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      _waveController.stop();
      setState(() => _isListening = false);
      if (_textController.text.trim().isNotEmpty) {
        _runAnalysis();
      }
      return;
    }

    if (!_isSpeechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chức năng nhận diện giọng nói chưa sẵn sàng. Bạn có thể nhập văn bản trực tiếp.')),
      );
      return;
    }

    setState(() => _isListening = true);
    _waveController.repeat(reverse: true);

    await _speech.listen(
      localeId: 'vi_VN',
      onResult: (result) {
        if (mounted) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _runAnalysis();
          }
        }
      },
    );
  }

  void _runAnalysis() async {
    final query = _textController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nói hoặc nhập triệu chứng của bạn.')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(milliseconds: 600));

    final res = _triageService.analyzeSymptoms(query);
    if (mounted) {
      setState(() {
        _result = res;
        _isAnalyzing = false;
      });
    }
  }

  void _bookDoctor() {
    if (_result == null) return;
    // Bác sĩ mẫu phù hợp với gợi ý
    final doctor = Doctor(
      id: _result!.suggestedDoctorId,
      name: _result!.suggestedDoctorName,
      specialty: _result!.suggestedDepartment,
      department: _result!.suggestedDepartment,
      rating: 4.9,
      reviewCount: 128,
      consultationFee: 150000,
      bio: 'Bác sĩ chuyên khoa giàu kinh nghiệm trong chẩn đoán và điều trị.',
      workingHours: '08:00 - 17:00 (Thứ 2 - Thứ 7)',
      avatarUrl: '',
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorBookingScreen(
          doctor: doctor,
          initialReason: _textController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bác Sĩ AI - Đánh Giá Triệu Chứng'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Hero Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.psychology_rounded, size: 36, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'AI Clinical Triage',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            Chip(
                              label: Text('EDGE AI', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                              backgroundColor: Color(0xFF047857),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Mô tả triệu chứng bằng giọng nói để AI phân loại mức độ khẩn cấp & gợi ý chuyên khoa.',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Voice Mic Button & Input Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Đang lắng nghe giọng nói của bạn...'
                          : 'Nhấn vào Micro để nói hoặc nhập triệu chứng tại đây...',
                      hintStyle: TextStyle(
                        color: _isListening ? const Color(0xFF0D9488) : Colors.grey,
                        fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      // Voice Mic
                      GestureDetector(
                        onTap: _toggleListening,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _isListening ? Colors.redAccent : const Color(0xFF0D9488),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isListening ? 'Đang ghi âm...' : 'Nói triệu chứng',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isAnalyzing ? null : _runAnalysis,
                        icon: _isAnalyzing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('Phân tích AI'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Samples
            const Text(
              'Thử nhanh các tình huống lâm sàng:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.mutedText),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _samplePrompts.map((prompt) {
                return ActionChip(
                  label: Text(prompt, style: const TextStyle(fontSize: 12)),
                  backgroundColor: const Color(0xFFF1F5F9),
                  onPressed: () {
                    _textController.text = prompt;
                    _runAnalysis();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // AI Result View
            if (_result != null) ...[
              _buildResultCard(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(TriageResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: result.urgency.color, width: 2),
        boxShadow: [
          BoxShadow(
            color: result.urgency.color.withOpacity(0.15),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Urgency Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: result.urgency.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  result.urgency.label,
                  style: TextStyle(
                    color: result.urgency.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.urgency.description,
            style: TextStyle(color: result.urgency.color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const Divider(height: 24),

          // Suggested Department & Doctor
          const Text(
            'Chuyên khoa đề xuất phù hợp:',
            style: TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.suggestedDepartment,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Bác sĩ phụ trách: ${result.suggestedDoctorName}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Possible conditions
          const Text(
            'Bệnh lý nghi ngờ tiềm ẩn:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          ...result.possibleConditions.map(
            (c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(c, style: const TextStyle(fontSize: 13.5))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Clinical Advice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.advice,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Book Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: result.urgency == TriageUrgency.emergency
                    ? Colors.redAccent
                    : AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _bookDoctor,
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(
                result.urgency == TriageUrgency.emergency
                    ? 'Đăng ký Khám Cấp cứu Ngay'
                    : 'Đặt lịch với ${result.suggestedDoctorName} Ngay',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
