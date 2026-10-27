import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VietQrBank {
  const VietQrBank({
    required this.code,
    required this.shortName,
    required this.fullName,
    required this.bin,
  });

  final String code;
  final String shortName;
  final String fullName;
  final String bin;
}

/// Kho cấu hình Tài khoản Ngân hàng nhận tiền thật (VietQR NAPAS 247)
class BankAccountConfigStore extends ChangeNotifier {
  BankAccountConfigStore._();
  static final BankAccountConfigStore instance = BankAccountConfigStore._();

  static const _bankCodeKey = 'vietqr_bank_code';
  static const _bankNameKey = 'vietqr_bank_name';
  static const _bankBinKey = 'vietqr_bank_bin';
  static const _accountNumberKey = 'vietqr_account_number';
  static const _accountNameKey = 'vietqr_account_name';

  static const List<VietQrBank> supportedBanks = [
    VietQrBank(
      code: 'MBBank',
      shortName: 'MB BANK',
      fullName: 'MB Bank (Ngân hàng Quân Đội)',
      bin: '970422',
    ),
    VietQrBank(
      code: 'VCB',
      shortName: 'VIETCOMBANK',
      fullName: 'Vietcombank (Ngân hàng Ngoại thương)',
      bin: '970436',
    ),
    VietQrBank(
      code: 'TCB',
      shortName: 'TECHCOMBANK',
      fullName: 'Techcombank (Ngân hàng Kỹ thương)',
      bin: '970407',
    ),
    VietQrBank(
      code: 'BIDV',
      shortName: 'BIDV',
      fullName: 'BIDV (Đầu tư & Phát triển VN)',
      bin: '970418',
    ),
    VietQrBank(
      code: 'ICB',
      shortName: 'VIETINBANK',
      fullName: 'VietinBank (Công thương VN)',
      bin: '970415',
    ),
    VietQrBank(
      code: 'ACB',
      shortName: 'ACB',
      fullName: 'ACB (Ngân hàng Á Châu)',
      bin: '970416',
    ),
    VietQrBank(
      code: 'VPB',
      shortName: 'VPBANK',
      fullName: 'VPBank (Việt Nam Thịnh Vượng)',
      bin: '970432',
    ),
    VietQrBank(
      code: 'TPB',
      shortName: 'TPBANK',
      fullName: 'TPBank (Ngân hàng Tiên Phong)',
      bin: '970423',
    ),
    VietQrBank(
      code: 'STB',
      shortName: 'SACOMBANK',
      fullName: 'Sacombank (Sài Gòn Thương Tín)',
      bin: '970403',
    ),
    VietQrBank(
      code: 'VBA',
      shortName: 'AGRIBANK',
      fullName: 'Agribank (NN & PT Nông thôn)',
      bin: '970405',
    ),
    VietQrBank(
      code: 'VIB',
      shortName: 'VIB',
      fullName: 'VIB (Ngân hàng Quốc Tế)',
      bin: '970441',
    ),
    VietQrBank(
      code: 'HDB',
      shortName: 'HDBANK',
      fullName: 'HDBank (Phát triển TP.HCM)',
      bin: '970437',
    ),
    VietQrBank(
      code: 'MSB',
      shortName: 'MSB',
      fullName: 'MSB (Hàng Hải Việt Nam)',
      bin: '970426',
    ),
    VietQrBank(
      code: 'OCB',
      shortName: 'OCB',
      fullName: 'OCB (Ngân hàng Phương Đông)',
      bin: '970448',
    ),
    VietQrBank(
      code: 'SHB',
      shortName: 'SHB',
      fullName: 'SHB (Sài Gòn - Hà Nội)',
      bin: '970443',
    ),
  ];

  String _bankCode = 'MBBank';
  String _bankName = 'MBBank';
  String _bankBin = '970422';
  String _accountNumber = '0355157761';
  String _accountName = 'CHAU THANH DAT';
  bool _loaded = false;

  String get bankCode => _bankCode;
  String get bankName => _bankName;
  String get bankBin => _bankBin;
  String get accountNumber => _accountNumber;
  String get accountName => _accountName;

  VietQrBank get currentBank =>
      supportedBanks.where((b) => b.bin == _bankBin).firstOrNull ??
      supportedBanks.first;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _bankCode = prefs.getString(_bankCodeKey) ?? _bankCode;
    _bankName = prefs.getString(_bankNameKey) ?? _bankName;
    _bankBin = prefs.getString(_bankBinKey) ?? _bankBin;
    final savedAcc = prefs.getString(_accountNumberKey);
    if (savedAcc != null && savedAcc != '050902185537') {
      _accountNumber = savedAcc;
    } else if (savedAcc == '050902185537') {
      _accountNumber = '0355157761';
      await prefs.setString(_accountNumberKey, _accountNumber);
    }
    _accountName = prefs.getString(_accountNameKey) ?? _accountName;
    _loaded = true;
    notifyListeners();
  }

  Future<void> updateAccount({
    required VietQrBank bank,
    required String accountNumber,
    required String accountName,
  }) async {
    _bankCode = bank.code;
    _bankName = bank.code;
    _bankBin = bank.bin;
    _accountNumber = accountNumber.trim();
    _accountName = accountName.trim().toUpperCase();
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_bankCodeKey, _bankCode),
      prefs.setString(_bankNameKey, _bankName),
      prefs.setString(_bankBinKey, _bankBin),
      prefs.setString(_accountNumberKey, _accountNumber),
      prefs.setString(_accountNameKey, _accountName),
    ]);
    notifyListeners();
  }
}

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
    String accountNumber = '0355157761',
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
