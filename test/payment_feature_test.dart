import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/features/payments/data/payment_repository.dart';
import 'package:smart_hospital/features/payments/domain/invoice.dart';
import 'package:smart_hospital/features/payments/presentation/e_invoice_screen.dart';
import 'package:smart_hospital/features/payments/presentation/invoice_management_screen.dart';
import 'package:smart_hospital/features/payments/presentation/vietqr_payment_screen.dart';
import 'package:smart_hospital/features/payments/utils/vietqr_helper.dart';

void main() {
  group('VietQR Helper Tests', () {
    test('generateEmvcoString builds standard NAPAS 247 EMVCo payload', () {
      final emvco = VietQrHelper.generateEmvcoString(
        bankBin: '970422',
        accountNumber: '050902185537',
        amount: 150000,
        memo: 'VP101_DAT',
      );

      expect(emvco.startsWith('000201'), isTrue); // EMVCo Header
      expect(emvco.contains('A000000727'), isTrue); // NAPAS AID
      expect(emvco.contains('970422'), isTrue); // MB Bank BIN
      expect(emvco.contains('050902185537'), isTrue); // MB Account Number
      expect(emvco.contains('VP101_DAT'), isTrue); // Payment Reference
      expect(emvco.contains('704'), isTrue); // Currency VND
      expect(emvco.length, greaterThan(60));
    });

    test('generateEmvcoString handles 2.000d test amount', () {
      final emvco = VietQrHelper.generateEmvcoString(
        bankBin: '970422',
        accountNumber: '050902185537',
        amount: 2000,
        memo: 'VPTEST',
      );

      expect(emvco.contains('54042000'), isTrue); // Amount 2000
    });
  });

  group('Payment Repository Tests', () {
    late LocalPaymentRepository repository;

    setUp(() {
      repository = LocalPaymentRepository();
    });

    test('getInvoiceForAppointment returns existing or creates new invoice', () async {
      final invoice = await repository.getInvoiceForAppointment('APT-101');
      expect(invoice.id, 'inv-101');
      expect(invoice.totalAmount, 150000);
      expect(invoice.bankAccountNumber, '050902185537');
      expect(invoice.bankAccountName, 'CHAU THANH DAT');
    });

    test('simulatePayment marks invoice as paid and generates lookup code', () async {
      final updated = await repository.simulatePayment('inv-101');
      expect(updated.isPaid, isTrue);
      expect(updated.paymentStatus, PaymentStatus.paid);
      expect(updated.bankTransactionId, isNotNull);
      expect(updated.eInvoiceLookupCode, isNotNull);
      expect(updated.paidAt, isNotNull);
    });

    test('getReconciliationReport returns balanced summary', () async {
      final report = await repository.getReconciliationReport();
      expect(report['reconciliationStatus'], 'BALANCED');
      expect(report['discrepancyVnd'], 0);
      expect(report['totalInvoices'], greaterThanOrEqualTo(3));
      expect(report['bankAccount']['bankAccountNumber'], '050902185537');
    });
  });

  group('VietQR Payment UI Tests', () {
    testWidgets('VietQrPaymentScreen renders MB Bank info and simulate payment button',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalPaymentRepository();
      final invoice = await repo.getInvoiceForAppointment('APT-101');

      await tester.pumpWidget(
        MaterialApp(
          home: VietQrPaymentScreen(
            invoice: invoice,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thanh toán Viện phí VietQR'), findsOneWidget);
      expect(find.text('MB BANK'), findsOneWidget);
      expect(find.text('050902185537'), findsOneWidget);
      expect(find.text('CHAU THANH DAT'), findsOneWidget);
      expect(find.textContaining('Mô phỏng Ngân hàng duyệt tiền'), findsOneWidget);

      // Tap simulate button
      await tester.tap(find.textContaining('Mô phỏng Ngân hàng duyệt tiền'));
      await tester.pumpAndSettle();

      expect(find.text('Thanh toán thành công!'), findsOneWidget);
      expect(find.text('Xem Hóa đơn Điện tử'), findsOneWidget);
    });

    testWidgets('EInvoiceScreen displays e-receipt details and signed stamp',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalPaymentRepository();
      final invoice = await repo.getInvoiceForAppointment('APT-103');

      await tester.pumpWidget(
        MaterialApp(
          home: EInvoiceScreen(invoice: invoice),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hóa đơn Viện phí Điện tử'), findsOneWidget);
      expect(find.text('SMART HOSPITAL'), findsOneWidget);
      expect(find.text('✓ ĐÃ THANH TOÁN'), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.text('HÓA ĐƠN ĐÃ ĐƯỢC KÝ SỐ'), findsOneWidget);
    });

    testWidgets('InvoiceManagementScreen displays reconciliation card and filter chips',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalPaymentRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InvoiceManagementScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản lý Viện phí & Đối soát'), findsOneWidget);
      expect(find.text('ĐỐI SOÁT VIỆN PHÍ NGÂN HÀNG'), findsOneWidget);
      expect(find.text('KHỚP 100% (0đ LỆCH)'), findsOneWidget);
      expect(find.text('HD261025-101'), findsOneWidget);
    });

    testWidgets('VietQrPaymentScreen renders itemized medicines with quantity and unit price before payment',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalPaymentRepository();
      final invoice = await repo.getInvoiceForAppointment('APT-102');

      await tester.pumpWidget(
        MaterialApp(
          home: VietQrPaymentScreen(
            invoice: invoice,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết Bảng kê & Đơn thuốc'), findsOneWidget);
      expect(find.text('Amlodipine 5mg'), findsOneWidget);
      expect(find.textContaining('SL: 30'), findsOneWidget);
      expect(find.textContaining('Đơn giá: 3.000 đ'), findsOneWidget);
      expect(find.text('90.000 đ'), findsOneWidget);
      expect(find.text('Aspirin 81mg'), findsOneWidget);
      expect(find.textContaining('SL: 20'), findsOneWidget);
      expect(find.text('35.000 đ'), findsOneWidget);

      await tester.tap(find.text('Mở phiếu kê viện phí đầy đủ'));
      await tester.pumpAndSettle();
      expect(find.text('BẢNG KÊ CHI PHÍ KHÁM CHỮA BỆNH'), findsOneWidget);
      expect(find.text('Đóng & Tiếp tục thanh toán VietQR'), findsOneWidget);
    });
  });
}
