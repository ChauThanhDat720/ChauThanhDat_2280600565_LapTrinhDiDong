import 'package:flutter/material.dart';

enum PaymentStatus {
  unpaid,
  pending,
  paid,
  cancelled;

  String get label => switch (this) {
        unpaid => 'Chờ thanh toán',
        pending => 'Đang xử lý',
        paid => 'Đã thanh toán',
        cancelled => 'Đã hủy',
      };

  Color get color => switch (this) {
        paid => const Color(0xFF16A34A),
        pending => const Color(0xFFD97706),
        unpaid => const Color(0xFFDC2626),
        cancelled => const Color(0xFF64748B),
      };

  static PaymentStatus fromJson(String? value) {
    switch (value?.toLowerCase()) {
      case 'paid':
        return PaymentStatus.paid;
      case 'pending':
        return PaymentStatus.pending;
      case 'cancelled':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.unpaid;
    }
  }
}

class InvoiceItem {
  const InvoiceItem({
    required this.name,
    required this.category, // 'Khám bệnh', 'Thuốc', 'Cận lâm sàng', 'Vật tư y tế'
    required this.unit, // 'Lượt', 'Viên', 'Gói', 'Chai', 'Lần'
    required this.quantity,
    required this.unitPrice,
    this.usageInstructions,
  });

  final String name;
  final String category;
  final String unit;
  final int quantity;
  final int unitPrice;
  final String? usageInstructions;

  int get totalPrice => quantity * unitPrice;
  String get formattedUnitPrice => Invoice.formatCurrency(unitPrice);
  String get formattedTotalPrice => Invoice.formatCurrency(totalPrice);

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'Thuốc',
        unit: json['unit'] as String? ?? 'Viên',
        quantity: (json['quantity'] ?? 1) as int,
        unitPrice: (json['unitPrice'] ?? json['unit_price'] ?? 0) as int,
        usageInstructions: json['usageInstructions'] as String? ??
            json['usage_instructions'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'unit': unit,
        'quantity': quantity,
        'unit_price': unitPrice,
        if (usageInstructions != null) 'usage_instructions': usageInstructions,
      };
}

class Invoice {
  const Invoice({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    this.doctorId,
    this.doctorName,
    this.department,
    required this.invoiceCode,
    this.eInvoiceLookupCode,
    this.examinationFee = 150000,
    this.medicineFee = 0,
    this.otherFee = 0,
    this.discountAmount = 0,
    required this.totalAmount,
    this.items = const [],
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentMethod = 'vietqr',
    required this.paymentRef,
    this.bankName = 'MBBank',
    this.bankBin = '970422',
    this.bankAccountNumber = '050902185537',
    this.bankAccountName = 'CHAU THANH DAT',
    this.bankTransactionId,
    this.paidAmount = 0,
    this.paidAt,
    this.createdAt,
    this.vietQrUrl,
  });

  final String id;
  final String appointmentId;
  final String patientId;
  final String patientName;
  final String? doctorId;
  final String? doctorName;
  final String? department;
  final String invoiceCode;
  final String? eInvoiceLookupCode;
  final int examinationFee;
  final int medicineFee;
  final int otherFee;
  final int discountAmount;
  final int totalAmount;
  final List<InvoiceItem> items;
  final PaymentStatus paymentStatus;
  final String paymentMethod;
  final String paymentRef;
  final String bankName;
  final String bankBin;
  final String bankAccountNumber;
  final String bankAccountName;
  final String? bankTransactionId;
  final int paidAmount;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final String? vietQrUrl;

  bool get isPaid => paymentStatus == PaymentStatus.paid;

  String get formattedTotalAmount => formatCurrency(totalAmount);
  String get formattedExaminationFee => formatCurrency(examinationFee);
  String get formattedMedicineFee => formatCurrency(medicineFee);
  String get formattedPaidAmount => formatCurrency(paidAmount > 0 ? paidAmount : totalAmount);

  static String formatCurrency(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return '${buffer.toString().split('').reversed.join('')} đ';
  }

  /// Danh sách chi tiết các khoản thu viện phí & thuốc
  List<InvoiceItem> get displayItems {
    if (items.isNotEmpty) return items;

    final list = <InvoiceItem>[];
    if (examinationFee > 0) {
      list.add(
        InvoiceItem(
          name: 'Công khám chuyên khoa ${department ?? "Nội khoa"}',
          category: 'Khám bệnh',
          unit: 'Lượt',
          quantity: 1,
          unitPrice: examinationFee,
          usageInstructions: doctorName != null ? 'Bác sĩ: $doctorName' : null,
        ),
      );
    }

    if (otherFee > 0) {
      list.add(
        InvoiceItem(
          name: 'Dịch vụ Cận lâm sàng & Chẩn đoán hình ảnh',
          category: 'Cận lâm sàng',
          unit: 'Lần',
          quantity: 1,
          unitPrice: otherFee,
        ),
      );
    }

    if (medicineFee > 0) {
      if (medicineFee == 125000) {
        list.addAll([
          const InvoiceItem(
            name: 'Amlodipine 5mg',
            category: 'Thuốc',
            unit: 'Viên',
            quantity: 30,
            unitPrice: 3000,
            usageInstructions: 'Uống 1 viên vào 08:00 sáng mỗi ngày',
          ),
          const InvoiceItem(
            name: 'Aspirin 81mg',
            category: 'Thuốc',
            unit: 'Viên',
            quantity: 20,
            unitPrice: 1750,
            usageInstructions: 'Uống 1 viên sau bữa ăn trưa',
          ),
        ]);
      } else if (medicineFee == 85000) {
        list.addAll([
          const InvoiceItem(
            name: 'Paracetamol 500mg',
            category: 'Thuốc',
            unit: 'Viên',
            quantity: 20,
            unitPrice: 2000,
            usageInstructions: 'Uống 1 viên x 2 lần/ngày khi đau sốt',
          ),
          const InvoiceItem(
            name: 'Vitamin C 500mg',
            category: 'Thuốc',
            unit: 'Viên',
            quantity: 15,
            unitPrice: 3000,
            usageInstructions: 'Uống 1 viên vào buổi sáng sau ăn',
          ),
        ]);
      } else {
        list.add(
          InvoiceItem(
            name: 'Thuốc điều trị theo đơn bác sĩ kê',
            category: 'Thuốc',
            unit: 'Gói',
            quantity: 1,
            unitPrice: medicineFee,
          ),
        );
      }
    }

    return list;
  }

  /// Trích xuất tự động các loại thuốc từ chuỗi kê đơn của bác sĩ
  static List<InvoiceItem> parsePrescriptionToItems(String prescription) {
    final lines = prescription
        .split(RegExp(r'[\n;]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length > 2)
        .toList();

    final result = <InvoiceItem>[];
    for (final line in lines) {
      final clean = line.replaceFirst(RegExp(r'^\d+[\.\-\)]\s*'), '').trim();
      String name = clean;
      String? instructions;

      if (clean.contains(' - ')) {
        final parts = clean.split(' - ');
        name = parts[0].trim();
        instructions = parts.sublist(1).join(' - ').trim();
      } else if (clean.contains(':')) {
        final parts = clean.split(':');
        name = parts[0].trim();
        instructions = parts.sublist(1).join(':').trim();
      } else if (clean.contains('(') && clean.contains(')')) {
        final m = RegExp(r'^(.*?)\((.*?)\)').firstMatch(clean);
        if (m != null) {
          name = m.group(1)!.trim();
          instructions = m.group(2)!.trim();
        }
      }

      final lower = name.toLowerCase();
      int unitPrice = 3000;
      int quantity = 20;
      String unit = 'Viên';

      if (lower.contains('paracetamol') || lower.contains('panadol')) {
        unitPrice = 2000;
        quantity = 15;
      } else if (lower.contains('vitamin c')) {
        unitPrice = 2500;
        quantity = 10;
      } else if (lower.contains('amlodipin')) {
        unitPrice = 3500;
        quantity = 30;
      } else if (lower.contains('aspirin')) {
        unitPrice = 2000;
        quantity = 30;
      } else if (lower.contains('cefixim')) {
        unitPrice = 8500;
        quantity = 10;
      } else if (lower.contains('augmentin')) {
        unitPrice = 12000;
        quantity = 14;
      } else if (lower.contains('ventolin')) {
        unitPrice = 75000;
        quantity = 1;
        unit = 'Chai xịt';
      } else if (lower.contains('multivitamin')) {
        unitPrice = 4500;
        quantity = 30;
      } else {
        if (instructions != null) {
          if (instructions.contains('3 lần') || instructions.contains('3 viên')) {
            quantity = 21;
          } else if (instructions.contains('2 lần') || instructions.contains('2 viên')) {
            quantity = 14;
          } else if (instructions.contains('1 lần') || instructions.contains('1 viên')) {
            quantity = 30;
          }
        }
      }

      result.add(
        InvoiceItem(
          name: name,
          category: 'Thuốc',
          unit: unit,
          quantity: quantity,
          unitPrice: unitPrice,
          usageInstructions: instructions ?? 'Theo chỉ định của bác sĩ',
        ),
      );
    }

    return result;
  }

  String get dynamicVietQrUrl {
    if (vietQrUrl != null && vietQrUrl!.isNotEmpty) return vietQrUrl!;
    final encName = Uri.encodeComponent(bankAccountName);
    final encRef = Uri.encodeComponent(paymentRef);
    return 'https://img.vietqr.io/image/$bankBin-$bankAccountNumber-compact2.png?amount=$totalAmount&addInfo=$encRef&accountName=$encName';
  }

  String getCustomVietQrUrl(int customAmount) {
    final encName = Uri.encodeComponent(bankAccountName);
    final encRef = Uri.encodeComponent(paymentRef);
    return 'https://img.vietqr.io/image/$bankBin-$bankAccountNumber-compact2.png?amount=$customAmount&addInfo=$encRef&accountName=$encName';
  }

  Invoice copyWith({
    String? id,
    String? appointmentId,
    String? patientId,
    String? patientName,
    String? doctorId,
    String? doctorName,
    String? department,
    String? invoiceCode,
    String? eInvoiceLookupCode,
    int? examinationFee,
    int? medicineFee,
    int? otherFee,
    int? discountAmount,
    int? totalAmount,
    List<InvoiceItem>? items,
    PaymentStatus? paymentStatus,
    String? paymentMethod,
    String? paymentRef,
    String? bankName,
    String? bankBin,
    String? bankAccountNumber,
    String? bankAccountName,
    String? bankTransactionId,
    int? paidAmount,
    DateTime? paidAt,
    DateTime? createdAt,
    String? vietQrUrl,
  }) {
    return Invoice(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      department: department ?? this.department,
      invoiceCode: invoiceCode ?? this.invoiceCode,
      eInvoiceLookupCode: eInvoiceLookupCode ?? this.eInvoiceLookupCode,
      examinationFee: examinationFee ?? this.examinationFee,
      medicineFee: medicineFee ?? this.medicineFee,
      otherFee: otherFee ?? this.otherFee,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentRef: paymentRef ?? this.paymentRef,
      bankName: bankName ?? this.bankName,
      bankBin: bankBin ?? this.bankBin,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankTransactionId: bankTransactionId ?? this.bankTransactionId,
      paidAmount: paidAmount ?? this.paidAmount,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      vietQrUrl: vietQrUrl ?? this.vietQrUrl,
    );
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String? ?? '',
      appointmentId: json['appointment_id'] as String? ?? json['appointmentId'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? json['patientId'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? json['patientName'] as String? ?? 'Bệnh nhân',
      doctorId: json['doctor_id'] as String? ?? json['doctorId'] as String?,
      doctorName: json['doctor_name'] as String? ?? json['doctorName'] as String?,
      department: json['department'] as String?,
      invoiceCode: json['invoice_code'] as String? ?? json['invoiceCode'] as String? ?? '',
      eInvoiceLookupCode: json['e_invoice_lookup_code'] as String? ?? json['eInvoiceLookupCode'] as String?,
      examinationFee: (json['examination_fee'] ?? json['examinationFee'] ?? 150000) as int,
      medicineFee: (json['medicine_fee'] ?? json['medicineFee'] ?? 0) as int,
      otherFee: (json['other_fee'] ?? json['otherFee'] ?? 0) as int,
      discountAmount: (json['discount_amount'] ?? json['discountAmount'] ?? 0) as int,
      totalAmount: (json['total_amount'] ?? json['totalAmount'] ?? 150000) as int,
      items: json['items'] is List
          ? (json['items'] as List)
              .map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      paymentStatus: PaymentStatus.fromJson(json['payment_status'] as String? ?? json['paymentStatus'] as String?),
      paymentMethod: json['payment_method'] as String? ?? json['paymentMethod'] as String? ?? 'vietqr',
      paymentRef: json['payment_ref'] as String? ?? json['paymentRef'] as String? ?? 'VP101',
      bankName: json['bank_name'] as String? ?? json['bankName'] as String? ?? 'MBBank',
      bankBin: json['bank_bin'] as String? ?? json['bankBin'] as String? ?? '970422',
      bankAccountNumber: json['bank_account_number'] as String? ?? json['bankAccountNumber'] as String? ?? '050902185537',
      bankAccountName: json['bank_account_name'] as String? ?? json['bankAccountName'] as String? ?? 'CHAU THANH DAT',
      bankTransactionId: json['bank_transaction_id'] as String? ?? json['bankTransactionId'] as String?,
      paidAmount: (json['paid_amount'] ?? json['paidAmount'] ?? 0) as int,
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      vietQrUrl: json['viet_qr_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'appointment_id': appointmentId,
        'patient_id': patientId,
        'patient_name': patientName,
        'doctor_id': doctorId,
        'doctor_name': doctorName,
        'department': department,
        'invoice_code': invoiceCode,
        'e_invoice_lookup_code': eInvoiceLookupCode,
        'examination_fee': examinationFee,
        'medicine_fee': medicineFee,
        'other_fee': otherFee,
        'discount_amount': discountAmount,
        'total_amount': totalAmount,
        'items': items.map((e) => e.toJson()).toList(),
        'payment_status': paymentStatus.name,
        'payment_method': paymentMethod,
        'payment_ref': paymentRef,
        'bank_name': bankName,
        'bank_bin': bankBin,
        'bank_account_number': bankAccountNumber,
        'bank_account_name': bankAccountName,
        'bank_transaction_id': bankTransactionId,
        'paid_amount': paidAmount,
        'paid_at': paidAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'viet_qr_url': vietQrUrl,
      };
}
