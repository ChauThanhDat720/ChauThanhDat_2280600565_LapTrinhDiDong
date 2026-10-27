import '../../appointments/domain/appointment.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/patient_session.dart';
import '../domain/invoice.dart';

abstract class PaymentRepository {
  Future<Invoice> getInvoiceForAppointment(String appointmentId);
  Future<Invoice> getInvoiceById(String id);
  Future<List<Invoice>> getInvoices({String? patientId, String? status});
  Future<Invoice> simulatePayment(String invoiceId, {int? amount});
  Future<Map<String, dynamic>> getReconciliationReport();
}

class LocalPaymentRepository implements PaymentRepository {
  static final List<Invoice> _sharedInvoices = [];
  static bool _seeded = false;

  LocalPaymentRepository({List<Invoice>? initialInvoices}) {
    if (initialInvoices != null) {
      _invoices = List<Invoice>.from(initialInvoices);
    } else {
      if (!_seeded) {
        _seeded = true;
        _seedDefaultInvoices(_sharedInvoices);
      }
      _invoices = _sharedInvoices;
    }
  }

  late final List<Invoice> _invoices;

  static void resetForTest() {
    _sharedInvoices.clear();
    _seeded = false;
  }

  static void _seedDefaultInvoices(List<Invoice> target) {
    final now = DateTime.now();
    target.addAll([
      Invoice(
        id: 'inv-101',
        appointmentId: 'APT-101',
        patientId: 'BN-01',
        patientName: 'Nguyễn Văn An',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        department: 'Khoa Tim mạch',
        invoiceCode: 'HD261025-101',
        examinationFee: 150000,
        medicineFee: 0,
        totalAmount: 150000,
        items: const [
          InvoiceItem(
            name: 'Công khám chuyên khoa Tim mạch',
            category: 'Khám bệnh',
            unit: 'Lượt',
            quantity: 1,
            unitPrice: 150000,
            usageInstructions: 'Bác sĩ: BS. Trần Thảo Linh (Phòng 204)',
          ),
        ],
        paymentStatus: PaymentStatus.unpaid,
        paymentRef: 'VP101_DAT',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      Invoice(
        id: 'inv-102',
        appointmentId: 'APT-102',
        patientId: 'BN-02',
        patientName: 'Trần Thị Mai',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        department: 'Khoa Tim mạch',
        invoiceCode: 'HD261025-102',
        examinationFee: 150000,
        medicineFee: 125000,
        totalAmount: 275000,
        items: const [
          InvoiceItem(
            name: 'Công khám chuyên khoa Tim mạch',
            category: 'Khám bệnh',
            unit: 'Lượt',
            quantity: 1,
            unitPrice: 150000,
            usageInstructions: 'Bác sĩ: BS. Trần Thảo Linh (Phòng 204)',
          ),
          InvoiceItem(
            name: 'Amlodipine 5mg',
            category: 'Thuốc',
            unit: 'Viên',
            quantity: 30,
            unitPrice: 3000,
            usageInstructions: 'Uống 1 viên vào 08:00 sáng mỗi ngày',
          ),
          InvoiceItem(
            name: 'Aspirin 81mg',
            category: 'Thuốc',
            unit: 'Viên',
            quantity: 20,
            unitPrice: 1750,
            usageInstructions: 'Uống 1 viên sau bữa ăn trưa',
          ),
        ],
        paymentStatus: PaymentStatus.unpaid,
        paymentRef: 'VP102_DAT',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      Invoice(
        id: 'inv-103',
        appointmentId: 'APT-103',
        patientId: 'BN-01',
        patientName: 'Nguyễn Văn An',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        department: 'Khoa Tim mạch',
        invoiceCode: 'HD261025-103',
        eInvoiceLookupCode: 'EINV-2026-8892-MB',
        examinationFee: 150000,
        medicineFee: 85000,
        totalAmount: 235000,
        items: const [
          InvoiceItem(
            name: 'Công khám chuyên khoa Tim mạch',
            category: 'Khám bệnh',
            unit: 'Lượt',
            quantity: 1,
            unitPrice: 150000,
            usageInstructions: 'Bác sĩ: BS. Trần Thảo Linh (Phòng 204)',
          ),
          InvoiceItem(
            name: 'Paracetamol 500mg',
            category: 'Thuốc',
            unit: 'Viên',
            quantity: 20,
            unitPrice: 2000,
            usageInstructions: 'Uống 1 viên x 2 lần/ngày khi đau sốt',
          ),
          InvoiceItem(
            name: 'Vitamin C 500mg',
            category: 'Thuốc',
            unit: 'Viên',
            quantity: 15,
            unitPrice: 3000,
            usageInstructions: 'Uống 1 viên vào buổi sáng sau ăn',
          ),
        ],
        paymentStatus: PaymentStatus.paid,
        paymentRef: 'VP103_DAT',
        bankTransactionId: 'MB-FT2610259832',
        paidAmount: 235000,
        paidAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  @override
  Future<Invoice> getInvoiceForAppointment(String appointmentId) async {
    final apt = AppointmentStore.instance.appointments
        .where((a) => a.id == appointmentId)
        .firstOrNull;

    final foundIdx = _invoices.indexWhere(
      (e) => e.appointmentId == appointmentId,
    );
    if (foundIdx >= 0) {
      final existing = _invoices[foundIdx];
      if (!existing.isPaid &&
          existing.medicineFee == 0 &&
          apt?.prescription != null &&
          apt!.prescription!.trim().isNotEmpty) {
        final parsedMeds = Invoice.parsePrescriptionToItems(apt.prescription!);
        final medFee = parsedMeds.fold(0, (sum, i) => sum + i.totalPrice);
        final updatedItems = [...existing.items, ...parsedMeds];
        final updated = existing.copyWith(
          medicineFee: medFee,
          totalAmount: existing.examinationFee + medFee + existing.otherFee,
          items: updatedItems,
        );
        _invoices[foundIdx] = updated;
        return updated;
      }
      return existing;
    }

    final items = <InvoiceItem>[];
    const examFee = 150000;
    items.add(
      InvoiceItem(
        name: 'Công khám chuyên khoa ${apt?.department.isNotEmpty == true ? apt!.department : "Tim mạch"}',
        category: 'Khám bệnh',
        unit: 'Lượt',
        quantity: 1,
        unitPrice: examFee,
        usageInstructions: apt?.doctorName.isNotEmpty == true ? 'Bác sĩ: ${apt!.doctorName}' : null,
      ),
    );

    int medicineFee = 0;
    if (apt?.prescription != null && apt!.prescription!.trim().isNotEmpty) {
      final parsedMeds = Invoice.parsePrescriptionToItems(apt.prescription!);
      items.addAll(parsedMeds);
      medicineFee = parsedMeds.fold(0, (sum, i) => sum + i.totalPrice);
    }

    int otherFee = 0;
    if (apt?.statusNote != null && apt!.statusNote!.contains('Kết quả CLS:')) {
      otherFee = 65000;
      items.add(
        const InvoiceItem(
          name: 'Chỉ định Cận lâm sàng (Điện tâm đồ ECG / Xét nghiệm máu)',
          category: 'Cận lâm sàng',
          unit: 'Lần',
          quantity: 1,
          unitPrice: 65000,
        ),
      );
    }

    final totalAmount = examFee + medicineFee + otherFee;
    final resolvedPatientId = apt?.patientId.isNotEmpty == true
        ? apt!.patientId
        : (PatientSession.instance.isDemoAccount
              ? 'BN-01'
              : PatientSession.instance.patientId);
    final resolvedPatientName = apt?.patientName.isNotEmpty == true
        ? apt!.patientName
        : (PatientSession.instance.email.isNotEmpty
              ? PatientSession.instance.name
              : 'Bệnh nhân');

    // Tự sinh hóa đơn mới cho lịch hẹn với đầy đủ bảng kê thuốc & dịch vụ
    final newInv = Invoice(
      id: 'inv-${DateTime.now().millisecondsSinceEpoch}',
      appointmentId: appointmentId,
      patientId: resolvedPatientId,
      patientName: resolvedPatientName,
      doctorId: apt?.doctorId,
      doctorName: apt?.doctorName ?? 'BS. Trần Thảo Linh',
      department: apt?.department ?? 'Khoa Tim mạch',
      invoiceCode: 'HD261025-${_invoices.length + 100}',
      examinationFee: examFee,
      medicineFee: medicineFee,
      otherFee: otherFee,
      totalAmount: totalAmount,
      items: items,
      paymentStatus: PaymentStatus.unpaid,
      paymentRef: 'VP${appointmentId.replaceAll(RegExp(r'[^0-9]'), '')}_DAT',
      createdAt: DateTime.now(),
    );
    _invoices.insert(0, newInv);
    return newInv;
  }

  @override
  Future<Invoice> getInvoiceById(String id) async {
    final found = _invoices.where((e) => e.id == id);
    if (found.isNotEmpty) return found.first;
    throw Exception('Không tìm thấy hóa đơn ID $id');
  }

  @override
  Future<List<Invoice>> getInvoices({String? patientId, String? status}) async {
    var list = List<Invoice>.from(_invoices);
    if (patientId != null && patientId.isNotEmpty) {
      list = list
          .where(
            (e) =>
                e.patientId == patientId ||
                (patientId == PatientSession.instance.patientId &&
                    PatientSession.instance.matchesPatientId(e.patientId)),
          )
          .toList();
    } else if (PatientSession.instance.role == 'patient' &&
        !PatientSession.instance.isDemoAccount) {
      list = list
          .where((e) => PatientSession.instance.matchesPatientId(e.patientId))
          .toList();
    }
    if (status != null && status.isNotEmpty) {
      list = list.where((e) => e.paymentStatus.name == status.toLowerCase()).toList();
    }
    return list;
  }

  @override
  Future<Invoice> simulatePayment(String invoiceId, {int? amount}) async {
    final index = _invoices.indexWhere((e) => e.id == invoiceId);
    if (index == -1) {
      throw Exception('Không tìm thấy hóa đơn để thanh toán.');
    }

    final target = _invoices[index];
    final updated = target.copyWith(
      paymentStatus: PaymentStatus.paid,
      paidAmount: amount ?? target.totalAmount,
      paidAt: DateTime.now(),
      bankTransactionId: 'MB-FT${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      eInvoiceLookupCode: 'EINV-2026-${target.paymentRef.replaceAll('_', '')}-MB',
    );
    _invoices[index] = updated;
    return updated;
  }

  @override
  Future<Map<String, dynamic>> getReconciliationReport() async {
    final visible = await getInvoices();
    int totalRevenue = 0;
    int paidCount = 0;
    int unpaidCount = 0;

    for (final inv in visible) {
      if (inv.isPaid) {
        paidCount++;
        totalRevenue += inv.paidAmount > 0 ? inv.paidAmount : inv.totalAmount;
      } else {
        unpaidCount++;
      }
    }

    return {
      'reconciliationDate': DateTime.now().toIso8601String(),
      'totalInvoices': visible.length,
      'paidInvoices': paidCount,
      'unpaidInvoices': unpaidCount,
      'totalRevenueVnd': totalRevenue,
      'discrepancyVnd': 0,
      'reconciliationStatus': 'BALANCED',
      'bankAccount': {
        'bankName': 'MBBank',
        'bankAccountNumber': '050902185537',
        'bankAccountName': 'CHAU THANH DAT',
      },
    };
  }
}

class RemotePaymentRepository implements PaymentRepository {
  RemotePaymentRepository([
    this._client,
    LocalPaymentRepository? fallback,
  ]) : _fallback = fallback ?? LocalPaymentRepository();

  final ApiClient? _client;
  final LocalPaymentRepository _fallback;

  @override
  Future<Invoice> getInvoiceForAppointment(String appointmentId) async {
    try {
      if (_client != null) {
        final res = await _client.get('/appointments/$appointmentId/invoice');
        if (res is Map<String, dynamic>) {
          return Invoice.fromJson(res);
        }
      }
    } catch (_) {
      // Fallback local
    }
    return _fallback.getInvoiceForAppointment(appointmentId);
  }

  @override
  Future<Invoice> getInvoiceById(String id) async {
    try {
      if (_client != null) {
        final res = await _client.get('/invoices/$id');
        if (res is Map<String, dynamic>) {
          return Invoice.fromJson(res);
        }
      }
    } catch (_) {
      // Fallback local
    }
    return _fallback.getInvoiceById(id);
  }

  @override
  Future<List<Invoice>> getInvoices({String? patientId, String? status}) async {
    try {
      if (_client != null) {
        final query = <String, String>{};
        if (patientId != null) query['patientId'] = patientId;
        if (status != null) query['status'] = status;

        final res = await _client.get('/invoices', query: query.isNotEmpty ? query : null);
        if (res is Map<String, dynamic> && res['items'] is List) {
          return (res['items'] as List)
              .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {
      // Fallback local
    }
    return _fallback.getInvoices(patientId: patientId, status: status);
  }

  @override
  Future<Invoice> simulatePayment(String invoiceId, {int? amount}) async {
    try {
      if (_client != null) {
        final requestBody = <String, dynamic>{'invoiceId': invoiceId};
        if (amount != null) requestBody['amount'] = amount;
        final res = await _client.post('/payments/simulate', body: requestBody);
        if (res is Map<String, dynamic> && res['invoice'] is Map<String, dynamic>) {
          return Invoice.fromJson(res['invoice'] as Map<String, dynamic>);
        }
      }
    } catch (_) {
      // Fallback local
    }
    return _fallback.simulatePayment(invoiceId, amount: amount);
  }

  @override
  Future<Map<String, dynamic>> getReconciliationReport() async {
    try {
      if (_client != null) {
        final res = await _client.get('/payments/reconciliation');
        if (res is Map<String, dynamic>) {
          return res;
        }
      }
    } catch (_) {
      // Fallback local
    }
    return _fallback.getReconciliationReport();
  }
}
