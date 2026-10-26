import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/invoice.dart';

class EInvoiceScreen extends StatelessWidget {
  const EInvoiceScreen({
    super.key,
    required this.invoice,
  });

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final paidDateStr = invoice.paidAt != null
        ? '${invoice.paidAt!.day.toString().padLeft(2, '0')}/${invoice.paidAt!.month.toString().padLeft(2, '0')}/${invoice.paidAt!.year} ${invoice.paidAt!.hour.toString().padLeft(2, '0')}:${invoice.paidAt!.minute.toString().padLeft(2, '0')}'
        : '25/10/2026 09:30';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Hóa đơn Viện phí Điện tử'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Chia sẻ hóa đơn',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đang chuẩn bị chia sẻ Hóa đơn điện tử PDF...'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // Tờ Hóa đơn Điện tử (Ticket/Receipt style)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header Hóa đơn
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.local_hospital_rounded, color: Colors.white, size: 28),
                                SizedBox(width: 8),
                                Text(
                                  'SMART HOSPITAL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '✓ ĐÃ THANH TOÁN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'HÓA ĐƠN ĐIỆN TỬ DỊCH VỤ KHÁM CHỮA BỆNH',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mã hóa đơn: ${invoice.invoiceCode}',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                        Text(
                          'Mã tra cứu E-Invoice: ${invoice.eInvoiceLookupCode ?? "EINV-2026-MB"}',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Thân Hóa đơn
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thông tin người bệnh & bác sĩ
                        _sectionTitle('I. THÔNG TIN BỆNH NHÂN & KHÁM BỆNH'),
                        const SizedBox(height: 8),
                        _infoRow('Họ và tên:', invoice.patientName, isBold: true),
                        _infoRow('Mã bệnh nhân:', invoice.patientId),
                        _infoRow('Bác sĩ khám:', invoice.doctorName ?? 'BS. Trần Thảo Linh'),
                        _infoRow('Khoa khám:', invoice.department ?? 'Khoa Tim mạch'),
                        _infoRow('Mã lịch hẹn:', invoice.appointmentId),

                        const Divider(height: 28),

                        // Bảng chi tiết viện phí
                        _sectionTitle('II. CHI TIẾT CHI PHÍ VIỆN PHÍ'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'BẢNG KÊ CHI TIẾT TỪNG KHOẢN MỤC & ĐƠN THUỐC:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569)),
                                ),
                              ),
                              ...invoice.displayItems.map((item) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'SL: ${item.quantity} ${item.unit}  •  Đơn giá: ${item.formattedUnitPrice}',
                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        item.formattedTotalPrice,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const Divider(height: 16, thickness: 1.5),
                              _feeRow('1. Tiền khám chuyên khoa', invoice.formattedExaminationFee),
                              if (invoice.medicineFee > 0) ...[
                                const Divider(height: 12),
                                _feeRow('2. Thuốc điều trị theo đơn', invoice.formattedMedicineFee),
                              ],
                              if (invoice.otherFee > 0) ...[
                                const Divider(height: 12),
                                _feeRow('3. Dịch vụ cận lâm sàng', '${invoice.otherFee} đ'),
                              ],
                              if (invoice.discountAmount > 0) ...[
                                const Divider(height: 12),
                                _feeRow('4. Giảm trừ BHYT', '- ${invoice.discountAmount} đ', isDiscount: true),
                              ],
                              const Divider(height: 16, thickness: 1.5),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'TỔNG TIỀN THANH TOÁN:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    invoice.formattedPaidAmount,
                                    style: const TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 28),

                        // Thông tin giao dịch ngân hàng
                        _sectionTitle('III. THÔNG TIN XÁC NHẬN NGÂN HÀNG'),
                        const SizedBox(height: 8),
                        _infoRow('Phương thức:', 'Chuyển khoản VietQR (Napas 247)'),
                        _infoRow('Ngân hàng nhận:', 'MB Bank (Ngân hàng Quân Đội)'),
                        _infoRow('Tài khoản thụ hưởng:', '${invoice.bankAccountNumber} (${invoice.bankAccountName})'),
                        _infoRow('Mã giao dịch Bank:', invoice.bankTransactionId ?? 'MB-FT2610258839'),
                        _infoRow('Thời gian thanh toán:', paidDateStr),

                        if (invoice.displayItems.isNotEmpty || invoice.medicineFee > 0) ...[
                          const Divider(height: 28),
                          _sectionTitle('IV. TIẾN ĐỘ CẤP PHÁT THUỐC TẠI NHÀ THUỐC BỆNH VIỆN'),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.local_pharmacy_rounded, color: Color(0xFF0D9488), size: 20),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Quầy Dược số 2 - Tầng 1 (Khu khám Ngoại trú)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFCCFBF1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'ĐÃ SẴN SÀNG',
                                        style: TextStyle(
                                          color: Color(0xFF0F766E),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _pharmacyStep(
                                  step: '1',
                                  title: 'Bác sĩ kê đơn điện tử',
                                  subtitle: 'Chữ ký số đã được xác thực bởi BS điều trị',
                                  isCompleted: true,
                                ),
                                const SizedBox(height: 10),
                                _pharmacyStep(
                                  step: '2',
                                  title: 'Đã hoàn tất thanh toán viện phí',
                                  subtitle: 'Xác nhận qua VietQR Napas 247',
                                  isCompleted: true,
                                ),
                                const SizedBox(height: 10),
                                _pharmacyStep(
                                  step: '3',
                                  title: 'Thuốc đã soạn sẵn sàng',
                                  subtitle:
                                      'Vui lòng đến Quầy Dược số 2 xuất trình mã hóa đơn ${invoice.invoiceCode} để nhận thuốc',
                                  isCompleted: true,
                                  isHighlighted: true,
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // QR Code tra cứu và dấu mộc điện tử
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              _QrReceiptCode(
                                data: 'https://smarthospital.vn/e-invoice/${invoice.invoiceCode}?lookup=${invoice.eInvoiceLookupCode}',
                                size: 80,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'HÓA ĐƠN ĐÃ ĐƯỢC KÝ SỐ',
                                      style: TextStyle(
                                        color: Color(0xFF15803D),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Có giá trị pháp lý theo Nghị định 123/2020/NĐ-CP của Chính phủ về Hóa đơn điện tử.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ký bởi: SMART HOSPITAL CLINIC CA',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Nút bấm quay lại
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Quay lại Lịch khám'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.bold,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feeRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
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

  Widget _pharmacyStep({
    required String step,
    required String title,
    required String subtitle,
    required bool isCompleted,
    bool isHighlighted = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isHighlighted
                ? const Color(0xFF0D9488)
                : (isCompleted ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
            shape: BoxShape.circle,
          ),
          child: isCompleted
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  step,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isHighlighted ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QrReceiptCode extends StatelessWidget {
  const _QrReceiptCode({required this.data, this.size = 80});
  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _ReceiptCanvasPainter(qrImage),
      ),
    );
  }
}

class _ReceiptCanvasPainter extends CustomPainter {
  _ReceiptCanvasPainter(this.image);
  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF0F172A);
    final moduleSize = size.width / image.moduleCount;

    for (int x = 0; x < image.moduleCount; x++) {
      for (int y = 0; y < image.moduleCount; y++) {
        if (image.isDark(y, x)) {
          final rect = Rect.fromLTWH(
            x * moduleSize,
            y * moduleSize,
            moduleSize,
            moduleSize,
          );
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReceiptCanvasPainter oldDelegate) => false;
}
