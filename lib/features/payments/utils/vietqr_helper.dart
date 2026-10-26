import 'dart:convert';

/// Tiện ích sinh mã EMVCo chuẩn NAPAS 247 cho VietQR
class VietQrHelper {
  static String formatTlv(String id, String value) {
    final len = value.length.toString().padLeft(2, '0');
    return '$id$len$value';
  }

  /// Tính mã CRC16-CCITT theo chuẩn EMVCo QR
  static int crc16(List<int> bytes) {
    int crc = 0xFFFF;
    for (final b in bytes) {
      crc ^= (b << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc & 0xFFFF;
  }

  /// Tạo chuỗi EMVCo VietQR chuẩn của Ngân hàng Nhà nước & Napas 247
  static String generateEmvcoString({
    String bankBin = '970422', // MB Bank
    String accountNumber = '050902185537',
    int amount = 150000,
    String memo = 'VP101',
  }) {
    // 1. Phân hệ thông tin ngân hàng thụ hưởng (Tag 38)
    final guid = formatTlv('00', 'A000000727'); // NAPAS GUID
    final subBankBin = formatTlv('00', bankBin);
    final subAcc = formatTlv('01', accountNumber);
    final bankSubInfo = formatTlv('01', '$subBankBin$subAcc');
    final service = formatTlv('02', 'QRIBFTTA'); // Chuyển nhanh 247 qua số tài khoản
    final tag38Value = '$guid$bankSubInfo$service';
    final tag38 = formatTlv('38', tag38Value);

    // 2. Các trường thông tin bổ sung (Tag 62)
    final cleanMemo = memo.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    final tag62Value = formatTlv('08', cleanMemo);
    final tag62 = formatTlv('62', tag62Value);

    // 3. Ghép các thẻ chính
    final payload = StringBuffer();
    payload.write(formatTlv('00', '01')); // Format indicator
    payload.write(formatTlv('01', '12')); // Dynamic QR
    payload.write(tag38);
    payload.write(formatTlv('53', '704')); // VND
    if (amount > 0) {
      payload.write(formatTlv('54', amount.toString()));
    }
    payload.write(formatTlv('58', 'VN')); // Vietnam
    payload.write(tag62);
    payload.write('6304'); // CRC ID + length

    // 4. Tính CRC16
    final bytes = utf8.encode(payload.toString());
    final crcValue = crc16(bytes).toRadixString(16).toUpperCase().padLeft(4, '0');

    return '${payload.toString()}$crcValue';
  }
}
