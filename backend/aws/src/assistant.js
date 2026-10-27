// Offline information support, never a doctor's diagnosis or a prescription engine.
export function assistantReply(session, message, hasImage) {
  const text = message.toLowerCase().normalize('NFD').replace(/\p{Diacritic}/gu, '').replaceAll('đ', 'd').toLowerCase();
  if (/kho tho|dau nguc|ngat|bat tinh|sung moi|sung luoi|sung hong|co giat|chay mau nhieu/.test(text)) {
    return 'Nếu đang có triệu chứng nghiêm trọng như khó thở, đau ngực, ngất hoặc sưng môi/lưỡi/họng, hãy đến cơ sở cấp cứu hoặc gọi cấp cứu ngay. Không chờ phản hồi trong chat.';
  }
  if (/yeu cau bac si|gap bac si|bac si tra loi/.test(text)) return 'Yêu cầu đã được ghi vào phiên tư vấn để bác sĩ xem. Đây chưa phải xác nhận bác sĩ đã đọc tin. Nếu cần hỗ trợ sớm, hãy liên hệ trực tiếp cơ sở khám.';
  if (/quen (lieu|uong|thuoc)|uong bu/.test(text)) return 'Cách xử trí quên liều tùy từng thuốc. Xem tờ hướng dẫn hoặc hỏi bác sĩ/dược sĩ; không tự uống gấp đôi để bù liều trừ khi được hướng dẫn cụ thể. Bạn quên thuốc nào và vào lúc nào?';
  if (/don thuoc|thuoc nay|lieu dung|truoc.*an|sau.*an/.test(text)) return session.prescription
    ? `Đơn thuốc đã lưu cho lần khám này:\n${session.prescription}\nHãy theo đúng đơn và nhãn thuốc; hỏi bác sĩ/dược sĩ nếu hướng dẫn chưa rõ. Trợ lý không tự bổ sung liều dùng.`
    : 'Phiên này chưa có đơn thuốc. Bạn hãy trao đổi với bác sĩ/dược sĩ về tên thuốc và hướng dẫn trên nhãn; không tự đổi liều.';
  if (hasImage) return 'Ảnh đã được lưu cùng tin nhắn để bác sĩ xem. Trợ lý tự động không phân tích hay chẩn đoán từ ảnh. Hãy mô tả thêm thời gian xuất hiện và triệu chứng đi kèm.';
  return 'Mình là trợ lý hậu khám tự động. Hãy mô tả câu hỏi, triệu chứng và thời điểm xuất hiện. Các quyết định điều trị cần bác sĩ/dược sĩ đánh giá; chọn yêu cầu bác sĩ khi cần.';
}
