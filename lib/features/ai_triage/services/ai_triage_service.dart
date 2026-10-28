import '../domain/symptom_triage.dart';

class AiTriageService {
  const AiTriageService();

  TriageResult analyzeSymptoms(String rawInput) {
    final text = rawInput.toLowerCase().trim();

    // 1. Kiểm tra dấu hiệu Cấp cứu Khẩn cấp (Emergency Red Flags)
    final emergencyTriggers = [
      'đau ngực dữ dội',
      'tức ngực lan',
      'khó thở cấp',
      'ngưng thở',
      'yếu nửa người',
      'méo miệng',
      'co giật',
      'nôn ra máu',
      'hôn mê',
      'bất tỉnh',
      'đột quỵ',
    ];

    for (final trigger in emergencyTriggers) {
      if (text.contains(trigger)) {
        return const TriageResult(
          symptoms: 'Triệu chứng cấp cứu nguy kịch',
          urgency: TriageUrgency.emergency,
          suggestedDepartment: 'Khoa Cấp cứu & Can thiệp Tim mạch',
          departmentId: 'dept-emergency',
          suggestedDoctorId: 'dr-linh',
          suggestedDoctorName: 'BS. Trần Thảo Linh',
          possibleConditions: [
            'Hội chứng vành cấp / Nhồi máu cơ tim',
            'Đột quỵ não cấp tính (Tai biến)',
            'Suy hô hấp cấp',
          ],
          advice: 'Vui lòng gọi ngay cấp cứu 115 hoặc di chuyển đến Khoa Cấp cứu bệnh viện gần nhất ngay lập tức! Không tự ý lái xe.',
          warningFlags: [
            'Dấu hiệu nguy kịch tính mạng',
            'Cần đo điện tim ECG và can thiệp trong giờ vàng',
          ],
        );
      }
    }

    // 2. Chuyên khoa Tim mạch (Cardiology)
    if (text.contains('ngực') ||
        text.contains('tim') ||
        text.contains('hồi hộp') ||
        text.contains('đánh trống ngực') ||
        text.contains('huyết áp') ||
        text.contains('nhịp tim')) {
      return const TriageResult(
        symptoms: 'Tim mạch - Tuần hoàn',
        urgency: TriageUrgency.urgent,
        suggestedDepartment: 'Khoa Tim mạch',
        departmentId: 'dept-cardio',
        suggestedDoctorId: 'dr-linh',
        suggestedDoctorName: 'BS. Trần Thảo Linh',
        possibleConditions: [
          'Tăng huyết áp / Cơn tăng huyết áp',
          'Rối loạn nhịp tim',
          'Bệnh mạch vành thiếu máu cơ tim',
        ],
        advice: 'Nên đo huyết áp, giữ tư thế nghỉ ngơi thả lỏng, tránh vận động gắng sức và đến khám tại chuyên khoa Tim mạch trong ngày.',
        warningFlags: [
          'Nếu đau ngực kéo dài trên 15 phút hãy đến phòng cấp cứu',
        ],
      );
    }

    // 3. Chuyên khoa Hô hấp (Pulmonology / Internal Medicine)
    if (text.contains('ho') ||
        text.contains('sốt') ||
        text.contains('khó thở') ||
        text.contains('đờm') ||
        text.contains('đau họng') ||
        text.contains('sổ mũi') ||
        text.contains('viêm xoang') ||
        text.contains('phổi')) {
      final isHighFever = text.contains('sốt cao') || text.contains('39') || text.contains('40');
      return TriageResult(
        symptoms: 'Hô hấp & Nhiễm trùng',
        urgency: isHighFever ? TriageUrgency.urgent : TriageUrgency.routine,
        suggestedDepartment: 'Khoa Hô hấp & Nội tổng quát',
        departmentId: 'dept-pulmo',
        suggestedDoctorId: 'dr-linh',
        suggestedDoctorName: 'BS. Trần Thảo Linh',
        possibleConditions: const [
          'Nhiễm siêu vi đường hô hấp trên',
          'Viêm phế quản / Viêm amidan cấp',
          'Viêm phổi',
        ],
        advice: isHighFever
            ? 'Cần hạ sốt bằng Paracetamol, uống nhiều nước điện giải và đến khám sớm trong ngày.'
            : 'Uống nước ấm, súc họng bằng nước muối sinh lý và đặt lịch khám trong 24-48 giờ tới.',
        warningFlags: [
          if (isHighFever) 'Sốt cao kéo dài cần xét nghiệm công thức máu kiểm tra sốt xuất huyết hoặc nhiễm khuẩn',
        ],
      );
    }

    // 4. Chuyên khoa Tiêu hóa (Gastroenterology)
    if (text.contains('bụng') ||
        text.contains('dạ dày') ||
        text.contains('buồn nôn') ||
        text.contains('nôn') ||
        text.contains('tiêu chảy') ||
        text.contains('ợ chua') ||
        text.contains('khó tiêu')) {
      return const TriageResult(
        symptoms: 'Tiêu hóa - Gan mật',
        urgency: TriageUrgency.routine,
        suggestedDepartment: 'Khoa Tiêu hóa',
        departmentId: 'dept-gastro',
        suggestedDoctorId: 'dr-linh',
        suggestedDoctorName: 'BS. Trần Thảo Linh',
        possibleConditions: [
          'Viêm loét dạ dày - tá tràng',
          'Rối loạn tiêu hóa / Ngộ độc thực phẩm nhẹ',
          'Hội chứng trào ngược dạ dày thực quản (GERD)',
        ],
        advice: 'Tạm dừng ăn thức ăn cay nóng, nhiều dầu mỡ. Chia nhỏ bữa ăn và bù nước nếu có nôn/tiêu chảy.',
        warningFlags: [
          'Nếu có dấu hiệu đau bụng quằn quại hoặc sốt kèm theo, cần đến cơ sở y tế loại trừ viêm ruột thừa',
        ],
      );
    }

    // 5. Chuyên khoa Cơ - Xương - Khớp & Chấn thương
    if (text.contains('khớp') ||
        text.contains('gối') ||
        text.contains('lưng') ||
        text.contains('cổ vai gáy') ||
        text.contains('té ngã') ||
        text.contains('sưng') ||
        text.contains('đau nhức xương')) {
      return const TriageResult(
        symptoms: 'Cơ Xương Khớp & Vận động',
        urgency: TriageUrgency.routine,
        suggestedDepartment: 'Khoa Cơ Xương Khớp',
        departmentId: 'dept-ortho',
        suggestedDoctorId: 'dr-linh',
        suggestedDoctorName: 'BS. Trần Thảo Linh',
        possibleConditions: [
          'Thoái hóa khớp / Viêm khớp',
          'Căng cơ / Chấn thương phần mềm',
          'Thoát vị đĩa đệm cột sống',
        ],
        advice: 'Hạn chế mang vác vật nặng, chườm ấm hoặc chườm lạnh tùy tình trạng sưng và chụp X-quang/MRI khi khám.',
        warningFlags: [],
      );
    }

    // 6. Mặc định: Khám Nội tổng quát
    return const TriageResult(
      symptoms: 'Triệu chứng chung cần thăm khám',
      urgency: TriageUrgency.routine,
      suggestedDepartment: 'Khoa Khám bệnh - Nội tổng quát',
      departmentId: 'dept-general',
      suggestedDoctorId: 'dr-linh',
      suggestedDoctorName: 'BS. Trần Thảo Linh',
      possibleConditions: [
        'Cần thăm khám lâm sàng và xét nghiệm để chẩn đoán chính xác',
      ],
      advice: 'Bạn nên đặt lịch khám sớm với bác sĩ nội tổng quát để được lắng nghe và kiểm tra toàn diện.',
      warningFlags: [],
    );
  }
}
