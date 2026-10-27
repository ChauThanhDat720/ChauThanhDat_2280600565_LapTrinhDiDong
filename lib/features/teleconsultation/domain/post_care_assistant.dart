import 'teleconsultation.dart';

/// Offline, deterministic support. Never impersonates the treating doctor.
/// Medication guidance: https://www.sps.nhs.uk/articles/advising-on-missed-or-delayed-doses-of-medicines/
/// Red flags: https://www.surreyandsussex.nhs.uk/our-services/pharmacy
class PostCareAssistant {
  const PostCareAssistant();

  String reply(
    TeleconsultationSession session,
    String message, {
    bool hasImage = false,
  }) {
    final text = normalize(message);
    bool has(List<String> terms) => terms.any(text.contains);

    if (has([
      'kho tho',
      'dau nguc',
      'ngat',
      'bat tinh',
      'sung moi',
      'sung luoi',
      'sung mat',
      'sung hong',
      'co giat',
      'chay mau nhieu',
    ])) {
      return 'Nếu bạn đang khó thở, đau ngực, ngất, sưng môi/lưỡi/họng hoặc chảy máu nhiều, '
          'hãy đến cơ sở cấp cứu gần nhất hoặc gọi cấp cứu ngay. Nhờ người bên cạnh hỗ trợ; '
          'không chờ phản hồi trong chat. Mang theo đơn thuốc và thuốc đang dùng nếu có thể.';
    }
    if (has([
      'bac si tra loi',
      'gap bac si',
      'yeu cau bac si',
      'chuyen bac si',
    ])) {
      return 'Yêu cầu bác sĩ đã được ghi trong cuộc hội thoại. Bạn hãy bổ sung triệu chứng, '
          'thời điểm xuất hiện và tên thuốc để bác sĩ xem khi mở phiên tư vấn. '
          'Phản hồi tự động không xác nhận bác sĩ đã nhận hoặc đọc tin. '
          'Nếu cần hỗ trợ sớm, hãy liên hệ trực tiếp cơ sở khám.';
    }
    if (has(['quen lieu', 'quen uong', 'bo lieu', 'uong bu', 'quen thuoc'])) {
      return 'Cách xử trí quên liều tùy từng thuốc. Hãy xem hướng dẫn trên nhãn/tờ hướng dẫn '
          'hoặc hỏi bác sĩ, dược sĩ; không tự uống gấp đôi để bù liều trừ khi được hướng dẫn cụ thể. '
          'Bạn quên thuốc nào, liều lúc mấy giờ và liều tiếp theo lúc nào?';
    }
    if (has([
      'don thuoc',
      'lieu dung',
      'truoc',
      'sau bua',
      'sau an',
      'uong thuoc',
      'thuoc nay',
    ])) {
      final prescription = session.prescription?.trim() ?? '';
      return prescription.isEmpty
          ? 'Phiên tư vấn chưa có đơn thuốc được lưu. Bạn hãy cung cấp tên thuốc và hướng dẫn '
                'trên nhãn để trao đổi với bác sĩ/dược sĩ. Không tự đổi liều hoặc thời điểm dùng thuốc.'
          : 'Đơn thuốc được lưu cho lần khám này:\n$prescription\n\n'
                'Hãy làm theo đơn và nhãn thuốc. Nếu đơn chưa ghi uống trước hay sau ăn, '
                'hãy hỏi bác sĩ/dược sĩ cho đúng loại thuốc; trợ lý không tự bổ sung liều dùng.';
    }
    if (has([
      'chong mat',
      'choang',
      'buon non',
      'phat ban',
      'man ngua',
      'di ung',
      'dau',
      'sot',
      'vet thuong',
    ])) {
      return 'Bạn hãy ghi lại triệu chứng, mức độ, thời điểm bắt đầu, tên thuốc và thời điểm dùng '
          'rồi liên hệ bác sĩ/dược sĩ để được đánh giá. Trợ lý không thể kết luận đây là phản ứng bình thường '
          'hoặc quyết định đổi/ngừng thuốc. Nếu triệu chứng tăng nhanh hoặc nghiêm trọng, hãy đi khám ngay. '
          'Bạn có thể gửi thêm ảnh để bác sĩ xem.';
    }
    if (has(['tai kham', 'hen kham', 'dat lich'])) {
      return 'Bạn có thể vào mục Lịch khám để đặt lịch tái khám. Chuẩn bị đơn thuốc, kết quả xét nghiệm '
          'và ghi chép triệu chứng để bác sĩ đối chiếu. Nếu triệu chứng nặng lên, liên hệ cơ sở khám sớm '
          'thay vì chờ đến ngày hẹn.';
    }
    if (has(['kieng', 'an uong', 'ruou', 'bia', 'the duc'])) {
      return 'Chế độ ăn uống và vận động cần phù hợp bệnh lý và thuốc đang dùng. Hãy theo hướng dẫn '
          'sau khám và hỏi bác sĩ/dược sĩ về tương tác với thức ăn, rượu bia. '
          'Bạn muốn hỏi về thực phẩm hoặc hoạt động nào?';
    }
    if (hasImage) {
      return 'Ảnh đã được lưu kèm tin nhắn để bác sĩ xem trong phiên tư vấn. Trợ lý tự động không phân tích '
          'hay chẩn đoán từ ảnh. Bạn hãy mô tả thêm vị trí, thời gian xuất hiện và triệu chứng đi kèm.';
    }
    if (has(['cam on', 'xin chao', 'chao', 'hello'])) {
      return 'Chào bạn! Mình là trợ lý hậu khám tự động. Bạn có thể hỏi về đơn thuốc đã lưu, '
          'quên liều, cách liên hệ bác sĩ hoặc tái khám. Hãy cho biết bạn đang cần hỗ trợ điều gì.';
    }
    return 'Bạn hãy mô tả rõ câu hỏi, triệu chứng và thời điểm xuất hiện, cùng tên thuốc nếu có. '
        'Trợ lý hỗ trợ thông tin cơ bản; bác sĩ cần đánh giá các vấn đề điều trị cụ thể. '
        'Chọn “Yêu cầu bác sĩ” để ghi yêu cầu vào phiên tư vấn.';
  }

  static String normalize(String value) {
    var text = value.toLowerCase();
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    groups.forEach((replacement, characters) {
      text = text.replaceAll(RegExp('[$characters]'), replacement);
    });
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }
}
