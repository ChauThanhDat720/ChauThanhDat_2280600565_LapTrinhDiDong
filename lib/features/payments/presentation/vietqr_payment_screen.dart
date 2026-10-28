import 'dart:async';
import '../../../core/realtime/hospital_realtime_service.dart';
import '../../../core/realtime/realtime_events.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';

import '../../../core/theme/app_theme.dart';
import '../../notifications/data/notification_store.dart';
import '../../notifications/domain/notification_item.dart';
import '../data/payment_repository.dart';
import '../domain/invoice.dart';
import '../utils/vietqr_helper.dart';
import 'e_invoice_screen.dart';

class VietQrPaymentScreen extends StatefulWidget {
  const VietQrPaymentScreen({
    super.key,
    required this.invoice,
    this.repository,
  });

  final Invoice invoice;
  final PaymentRepository? repository;

  @override
  State<VietQrPaymentScreen> createState() => _VietQrPaymentScreenState();
}

class _VietQrPaymentScreenState extends State<VietQrPaymentScreen> {
  late PaymentRepository _repository;
  late Invoice _invoice;
  bool _isProcessing = false;
  bool _useMicroPaymentForTest = false; // Chế độ test 2.000đ tiền thật
  bool _useVectorQr = false; // Chế độ hiển thị QR Vector EMVCo siêu nét
  Timer? _countdownTimer;
  StreamSubscription<RealtimePaymentEvent>? _paymentRealtimeSub;
  int _secondsRemaining = 15 * 60; // 15 phút đếm ngược

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _repository = widget.repository ?? LocalPaymentRepository();
    BankAccountConfigStore.instance.addListener(_onBankConfigChanged);
    BankAccountConfigStore.instance.load().then((_) {
      if (mounted) _onBankConfigChanged();
    });

    _paymentRealtimeSub = HospitalRealtimeService.instance.paymentStream.listen((event) {
      if (event.invoiceId == _invoice.id || event.invoiceCode == _invoice.invoiceCode || event.appointmentId == _invoice.appointmentId) {
        if (mounted) {
          _paymentRealtimeSub?.cancel();
    _countdownTimer?.cancel();
          final updated = _invoice.copyWith(
            paymentStatus: PaymentStatus.paid,
            bankTransactionId: event.bankTransactionId,
            paidAmount: event.amount,
            paidAt: DateTime.now(),
          );
          setState(() {
            _invoice = updated;
            _isProcessing = false;
          });
          _showPaidSuccessDialog(updated);
        }
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_secondsRemaining > 0) {
          setState(() => _secondsRemaining--);
        } else {
          timer.cancel();
        }
      }
    });
  }

  void _onBankConfigChanged() {
    if (!mounted) return;
    final cfg = BankAccountConfigStore.instance;
    setState(() {
      _invoice = _invoice.copyWith(
        bankName: cfg.bankName,
        bankBin: cfg.bankBin,
        bankAccountNumber: cfg.accountNumber,
        bankAccountName: cfg.accountName,
        vietQrUrl: '',
      );
    });
  }

  @override
  void dispose() {
    BankAccountConfigStore.instance.removeListener(_onBankConfigChanged);
    _countdownTimer?.cancel();
    super.dispose();
  }

  int get _currentAmount => _useMicroPaymentForTest ? 2000 : _invoice.totalAmount;

  String get _currentQrUrl => _useMicroPaymentForTest
      ? _invoice.getCustomVietQrUrl(2000)
      : _invoice.dynamicVietQrUrl;

  String get _currentEmvcoString => VietQrHelper.generateEmvcoString(
        bankBin: _invoice.bankBin,
        accountNumber: _invoice.bankAccountNumber,
        amount: _currentAmount,
        memo: _invoice.paymentRef,
      );

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label: $text'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _checkPaymentStatus() async {
    setState(() => _isProcessing = true);
    try {
      final updated = await _repository.getInvoiceById(_invoice.id);
      if (mounted) {
        setState(() {
          _invoice = updated;
          _isProcessing = false;
        });
        if (updated.isPaid) {
          _showPaidSuccessDialog(updated);
        } else {
          _showConfirmRealTransferDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kiểm tra: $e')),
        );
      }
    }
  }

  void _showConfirmRealTransferDialog() {
    final txCtrl = TextEditingController(
      text: 'FT${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Xác nhận chuyển khoản tiền thật',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn đã quét mã VietQR và chuyển tiền vào tài khoản thụ hưởng:',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ngân hàng: ${BankAccountConfigStore.instance.currentBank.fullName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Số tài khoản: ${_invoice.bankAccountNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chủ tài khoản: ${_invoice.bankAccountName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Số tiền: ${Invoice.formatCurrency(_currentAmount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: txCtrl,
              decoration: const InputDecoration(
                labelText: 'Mã giao dịch ngân hàng (FT / Tùy chọn)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chưa chuyển'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
            ),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Tôi đã chuyển tiền thành công'),
            onPressed: () {
              Navigator.pop(ctx);
              _simulatePayment();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _simulatePayment() async {
    setState(() => _isProcessing = true);
    try {
      final updated = await _repository.simulatePayment(
        _invoice.id,
        amount: _currentAmount,
      );
      if (mounted) {
        setState(() {
          _invoice = updated;
          _isProcessing = false;
        });
        _showPaidSuccessDialog(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi mô phỏng: $e')),
        );
      }
    }
  }

  void _showBankConfigDialog() {
    final store = BankAccountConfigStore.instance;
    VietQrBank selectedBank = store.currentBank;
    final accNumberCtrl = TextEditingController(text: _invoice.bankAccountNumber);
    final accNameCtrl = TextEditingController(text: _invoice.bankAccountName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cấu hình Tài khoản Ngân hàng nhận tiền thật',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Nhập tài khoản ngân hàng của bạn để sinh mã VietQR NAPAS 247 chuẩn. Bạn có thể dùng app ngân hàng quét mã và chuyển tiền thật trực tiếp vào tài khoản này.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<VietQrBank>(
                  initialValue: selectedBank,
                  decoration: const InputDecoration(
                    labelText: 'Chọn Ngân hàng thụ hưởng',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  items: BankAccountConfigStore.supportedBanks
                      .map(
                        (b) => DropdownMenuItem(
                          value: b,
                          child: Text(
                            '${b.shortName} - ${b.fullName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedBank = val);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: accNumberCtrl,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Số tài khoản ngân hàng của bạn',
                    hintText: 'VD: 0355157761 hoặc 1903...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: accNameCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Tên chủ tài khoản (IN HOA KHÔNG DẤU)',
                    hintText: 'VD: NGUYEN VAN A',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: const Text(
                      'Lưu & Tạo Mã VietQR Tài khoản của tôi',
                    ),
                    onPressed: () async {
                      final numStr = accNumberCtrl.text.trim();
                      final nameStr = accNameCtrl.text.trim().toUpperCase();
                      if (numStr.isEmpty || nameStr.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Vui lòng nhập đầy đủ Số tài khoản và Tên chủ tài khoản!',
                            ),
                          ),
                        );
                        return;
                      }
                      await BankAccountConfigStore.instance.updateAccount(
                        bank: selectedBank,
                        accountNumber: numStr,
                        accountName: nameStr,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đã cập nhật mã QR nhận tiền sang ${selectedBank.shortName} - $numStr ($nameStr)!',
                            ),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPaidSuccessDialog(Invoice invoice) {
    NotificationStore.instance.addNotification(
      title: 'Thanh toán viện phí thành công',
      body:
          'Giao dịch cho hóa đơn ${invoice.id} (${invoice.formattedPaidAmount}) đã hoàn tất. Toa thuốc điện tử đã được chuyển đến Nhà thuốc Bệnh viện.',
      type: NotificationType.system,
      referenceId: invoice.id,
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
            SizedBox(width: 8),
            Text('Thanh toán thành công!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hệ thống đã nhận được tiền từ ngân hàng và tự động phát hành Hóa đơn điện tử.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mã hóa đơn: ${invoice.invoiceCode}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Mã tra cứu E-Invoice: ${invoice.eInvoiceLookupCode ?? "EINV-MB"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF15803D))),
                  const SizedBox(height: 4),
                  Text('Số tiền: ${invoice.formattedPaidAmount}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(_invoice);
            },
            child: const Text('Đóng'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
            ),
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Xem Hóa đơn Điện tử'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => EInvoiceScreen(invoice: invoice),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isAlreadyPaid = _invoice.isPaid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Thanh toán Viện phí VietQR'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts_rounded),
            tooltip: 'Cài đặt TK Ngân hàng nhận tiền của tôi',
            onPressed: _showBankConfigDialog,
          ),
          if (isAlreadyPaid)
            IconButton(
              icon: const Icon(Icons.receipt_long_rounded),
              tooltip: 'Xem hóa đơn',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EInvoiceScreen(invoice: _invoice),
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            // Status banner if already paid
            if (isAlreadyPaid)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Viện phí đã thanh toán thành công!',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                          ),
                          Text(
                            'Mã giao dịch: ${_invoice.bankTransactionId ?? "MB-FT"}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EInvoiceScreen(invoice: _invoice),
                          ),
                        );
                      },
                      child: const Text('Xem biên lai'),
                    ),
                  ],
                ),
              ),

            // Card chi tiết khoản thu & chuyển đổi test tiền thật
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hóa đơn: ${_invoice.invoiceCode}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _invoice.paymentStatus.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _invoice.paymentStatus.label,
                          style: TextStyle(
                            color: _invoice.paymentStatus.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _feeRow('Tiền khám chuyên khoa', _invoice.formattedExaminationFee),
                  if (_invoice.medicineFee > 0) ...[
                    const SizedBox(height: 8),
                    _feeRow('Tiền thuốc theo đơn', _invoice.formattedMedicineFee),
                  ],
                  if (_invoice.discountAmount > 0) ...[
                    const SizedBox(height: 8),
                    _feeRow('BHYT & Ưu đãi', '- ${_invoice.discountAmount} đ', isDiscount: true),
                  ],
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng viện phí:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        _useMicroPaymentForTest ? '2.000 đ' : _invoice.formattedTotalAmount,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),

                  // Lựa chọn chuyển số tiền demo 2.000đ thật
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _useMicroPaymentForTest
                                ? 'Đang bật chế độ Quét Test Tiền Thật: 2.000 đ'
                                : 'Số tiền thực tế: ${_invoice.formattedTotalAmount}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _useMicroPaymentForTest = !_useMicroPaymentForTest;
                            });
                          },
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                          child: Text(
                            _useMicroPaymentForTest ? 'Về tiền gốc' : 'Đổi sang 2.000đ',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bảng kê chi tiết đơn thuốc & dịch vụ trước khi thanh toán
            _buildItemizedBillCard(),

            const SizedBox(height: 16),

            // Card mã QR thanh toán
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Logo VietQR & Ngân hàng thụ hưởng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF003B95),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          BankAccountConfigStore.instance.currentBank.shortName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'VietQR | NAPAS 247',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Mã QR hiển thị
                  Container(
                    width: 240,
                    height: 240,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                    ),
                    child: _useVectorQr
                        ? Center(
                            child: _VietQrCanvasView(
                              data: _currentEmvcoString,
                              size: 210,
                            ),
                          )
                        : Image.network(
                            _currentQrUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (ctx, err, stack) {
                              // Fallback vẽ vector QR nếu không tải được ảnh
                              return Center(
                                child: _VietQrCanvasView(
                                  data: _currentEmvcoString,
                                  size: 210,
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _useVectorQr = !_useVectorQr);
                    },
                    icon: Icon(
                      _useVectorQr ? Icons.image_outlined : Icons.qr_code_2_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _useVectorQr
                          ? 'Đang hiện QR Vector EMVCo siêu nét (Nhấn để xem khung ảnh VietQR)'
                          : 'Khó quét trên màn hình? Chuyển sang QR Vector EMVCo siêu nét',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        'Mã QR hết hạn sau: ${_formatTimer(_secondsRemaining)}',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Dùng app ngân hàng bất kỳ (MB, VCB, Techcombank, MoMo,...) quét mã để thanh toán',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Card Thông tin tài khoản thụ hưởng
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Thông tin chuyển khoản thụ hưởng',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showBankConfigDialog,
                        icon: const Icon(Icons.edit_rounded, size: 15),
                        label: const Text(
                          'Đổi sang TK của tôi',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _bankInfoRow(
                    'Ngân hàng',
                    BankAccountConfigStore.instance.currentBank.fullName,
                    onCopy: () => _copyToClipboard(_invoice.bankName, 'Ngân hàng'),
                  ),
                  const Divider(height: 16),
                  _bankInfoRow(
                    'Số tài khoản',
                    _invoice.bankAccountNumber,
                    isHighlight: true,
                    onCopy: () => _copyToClipboard(_invoice.bankAccountNumber, 'Số tài khoản'),
                  ),
                  const Divider(height: 16),
                  _bankInfoRow(
                    'Chủ tài khoản',
                    _invoice.bankAccountName,
                    isHighlight: true,
                    onCopy: () => _copyToClipboard(_invoice.bankAccountName, 'Tên chủ tài khoản'),
                  ),
                  const Divider(height: 16),
                  _bankInfoRow(
                    'Số tiền',
                    _useMicroPaymentForTest ? '2.000 đ' : _invoice.formattedTotalAmount,
                    isHighlight: true,
                    onCopy: () => _copyToClipboard(_currentAmount.toString(), 'Số tiền'),
                  ),
                  const Divider(height: 16),
                  _bankInfoRow(
                    'Nội dung CK',
                    _invoice.paymentRef,
                    isHighlight: true,
                    onCopy: () => _copyToClipboard(_invoice.paymentRef, 'Nội dung chuyển khoản'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Nút bấm hành động
            if (!isAlreadyPaid) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _checkPaymentStatus,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Kiểm tra kết quả thanh toán'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF16A34A),
                    side: const BorderSide(color: Color(0xFF16A34A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _simulatePayment,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Mô phỏng Ngân hàng duyệt tiền (Sandbox)'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EInvoiceScreen(invoice: _invoice),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Xem Hóa đơn Điện tử E-Invoice'),
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _feeRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isDiscount ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _bankInfoRow(
    String label,
    String value, {
    bool isHighlight = false,
    VoidCallback? onCopy,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? const Color(0xFF0F172A) : const Color(0xFF334155),
            ),
          ),
        ),
        if (onCopy != null)
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Sao chép',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

Widget _itemCategoryHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(InvoiceItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            'ĐVT: ${item.unit}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SL: ${item.quantity}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• Đơn giá: ${item.formattedUnitPrice}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.formattedTotalPrice,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          if (item.usageInstructions != null && item.usageInstructions!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'HDSD: ${item.usageInstructions}',
              style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF0D9488)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemizedBillCard() {
    final items = _invoice.displayItems;
    final medicineItems = items.where((i) => i.category == 'Thuốc').toList();
    final examItems = items.where((i) => i.category == 'Khám bệnh').toList();
    final labItems = items.where((i) => i.category == 'Cận lâm sàng').toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
          ),
          title: const Text(
            'Chi tiết Bảng kê & Đơn thuốc',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Text(
            'Xem số lượng, đơn giá từng loại thuốc (${items.length} khoản mục)',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          children: [
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (examItems.isNotEmpty) ...[
                    _itemCategoryHeader('I. CÔNG KHÁM BÁC SĨ', Icons.medical_services_outlined, const Color(0xFF0284C7)),
                    const SizedBox(height: 8),
                    ...examItems.map(_buildItemRow),
                    const SizedBox(height: 12),
                  ],
                  if (medicineItems.isNotEmpty) ...[
                    _itemCategoryHeader('II. DANH MỤC THUỐC BÁC SĨ KÊ', Icons.medication_rounded, const Color(0xFF0D9488)),
                    const SizedBox(height: 8),
                    ...medicineItems.map(_buildItemRow),
                    const SizedBox(height: 12),
                  ],
                  if (labItems.isNotEmpty) ...[
                    _itemCategoryHeader('III. DỊCH VỤ CẬN LÂM SÀNG', Icons.biotech_rounded, const Color(0xFF7C3AED)),
                    const SizedBox(height: 8),
                    ...labItems.map(_buildItemRow),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _feeRow('Tiền công khám:', _invoice.formattedExaminationFee),
                        if (_invoice.medicineFee > 0) ...[
                          const SizedBox(height: 6),
                          _feeRow('Tiền thuốc (${medicineItems.length} loại):', _invoice.formattedMedicineFee),
                        ],
                        if (_invoice.otherFee > 0) ...[
                          const SizedBox(height: 6),
                          _feeRow('Tiền cận lâm sàng:', '${_invoice.otherFee} đ'),
                        ],
                        if (_invoice.discountAmount > 0) ...[
                          const SizedBox(height: 6),
                          _feeRow('BHYT chi trả:', '- ${_invoice.discountAmount} đ', isDiscount: true),
                        ],
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'BỆNH NHÂN CẦN THANH TOÁN:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              _invoice.formattedTotalAmount,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      icon: const Icon(Icons.fullscreen_rounded, size: 18),
                      label: const Text('Mở phiếu kê viện phí đầy đủ'),
                      onPressed: () => _showFullItemizedSheet(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _showFullItemizedSheet(BuildContext context) {
    final items = _invoice.displayItems;
    final medicineItems = items.where((i) => i.category == 'Thuốc').toList();
    final examItems = items.where((i) => i.category == 'Khám bệnh').toList();
    final labItems = items.where((i) => i.category == 'Cận lâm sàng').toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BẢNG KÊ CHI PHÍ KHÁM CHỮA BỆNH',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'Chuẩn hóa theo mẫu Bảng kê chi phí Viện phí & Nhà thuốc',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Thông tin người bệnh
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Họ và tên: ${_invoice.patientName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        const SizedBox(height: 3),
                        Text('Mã bệnh nhân: ${_invoice.patientId}  •  Mã HĐ: ${_invoice.invoiceCode}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        if (_invoice.doctorName != null) ...[
                          const SizedBox(height: 3),
                          Text('Bác sĩ điều trị: ${_invoice.doctorName} (${_invoice.department ?? "Nội khoa"})', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (examItems.isNotEmpty) ...[
                    _itemCategoryHeader('I. CÔNG KHÁM BÁC SĨ', Icons.medical_services_outlined, const Color(0xFF0284C7)),
                    const SizedBox(height: 8),
                    ...examItems.map(_buildItemRow),
                    const SizedBox(height: 14),
                  ],

                  if (medicineItems.isNotEmpty) ...[
                    _itemCategoryHeader('II. CHI TIẾT ĐƠN THUỐC BỆNH VIỆN', Icons.medication_rounded, const Color(0xFF0D9488)),
                    const SizedBox(height: 8),
                    ...medicineItems.map(_buildItemRow),
                    const SizedBox(height: 14),
                  ],

                  if (labItems.isNotEmpty) ...[
                    _itemCategoryHeader('III. DỊCH VỤ CẬN LÂM SÀNG', Icons.biotech_rounded, const Color(0xFF7C3AED)),
                    const SizedBox(height: 8),
                    ...labItems.map(_buildItemRow),
                    const SizedBox(height: 14),
                  ],

                  // Tổng kết
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      children: [
                        _feeRow('Tổng tiền khám bệnh:', _invoice.formattedExaminationFee),
                        if (_invoice.medicineFee > 0) ...[
                          const SizedBox(height: 6),
                          _feeRow('Tổng tiền thuốc (${medicineItems.length} loại):', _invoice.formattedMedicineFee),
                        ],
                        if (_invoice.otherFee > 0) ...[
                          const SizedBox(height: 6),
                          _feeRow('Tổng tiền cận lâm sàng:', '${_invoice.otherFee} đ'),
                        ],
                        if (_invoice.discountAmount > 0) ...[
                          const SizedBox(height: 6),
                          _feeRow('BHYT chi trả:', '- ${_invoice.discountAmount} đ', isDiscount: true),
                        ],
                        const Divider(height: 18, thickness: 1.5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TỔNG TIỀN PHẢI THANH TOÁN:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            Text(
                              _invoice.formattedTotalAmount,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Đóng & Tiếp tục thanh toán VietQR'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VietQrCanvasView extends StatelessWidget {
  const _VietQrCanvasView({required this.data, this.size = 200});
  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);

    return CustomPaint(
      size: Size(size, size),
      painter: _VietQrCanvasPainter(qrImage),
    );
  }
}

class _VietQrCanvasPainter extends CustomPainter {
  _VietQrCanvasPainter(this.image);
  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;
    final moduleSize = size.width / image.moduleCount;

    for (int x = 0; x < image.moduleCount; x++) {
      for (int y = 0; y < image.moduleCount; y++) {
        if (image.isDark(y, x)) {
          final rect = Rect.fromLTWH(
            x * moduleSize,
            y * moduleSize,
            moduleSize + 0.35,
            moduleSize + 0.35,
          );
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VietQrCanvasPainter oldDelegate) => false;

}
