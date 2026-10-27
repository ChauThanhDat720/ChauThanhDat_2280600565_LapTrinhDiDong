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

  String _resolvePatientId(Appointment? apt) => apt?.patientId.isNotEmpty == true
      ? apt!.patientId
      : (PatientSession.instance.isDemoAccount
            ? 'BN-01'
            : PatientSession.instance.patientId);

  String _resolvePatientName(Appointment? apt) =>
      apt?.patientName.isNotEmpty == true
      ? apt!.patientName
      : (PatientSession.instance.email.isNotEmpty
            ? PatientSession.instance.name
            : 'Bệnh nhân');

  /// Đợt 1: Hóa đơn Phí Đăng ký Khám chuyên khoa (bắt buộc thanh toán trước khi cấp QR Check-in)
  Future<Invoice> getOrCreateBookingInvoice(String appointmentId) async {
    final existing = _invoices
        .where(
          (e) =>
              e.appointmentId == appointmentId &&
              e.stage == PaymentStage.booking,
        )
        .firstOrNull;
    if (existing != null) return existing;

    final apt = AppointmentStore.instance.appointments
        .where((a) => a.id == appointmentId)
        .firstOrNull;
    const examFee = 150000;
    final items = [
      InvoiceItem(
        name:
            'Công khám chuyên khoa ${apt?.department.isNotEmpty == true ? apt!.department : "Tim mạch"}',
        category: 'Khám bệnh',
        unit: 'Lượt',
        quantity: 1,
        unitPrice: examFee,
        usageInstructions: apt?.doctorName.isNotEmpty == true
            ? 'Bác sĩ: ${apt!.doctorName}'
            : null,
      ),
    ];

    final newInv = Invoice(
      id: 'inv-booking-$appointmentId',
      appointmentId: appointmentId,
      patientId: _resolvePatientId(apt),
      patientName: _resolvePatientName(apt),
      doctorId: apt?.doctorId,
      doctorName: apt?.doctorName ?? 'BS. Trần Thảo Linh',
      department: apt?.department ?? 'Khoa Tim mạch',
      invoiceCode: 'HD-KHAM-${_invoices.length + 101}',
      examinationFee: examFee,
      medicineFee: 0,
      otherFee: 0,
      totalAmount: examFee,
      items: items,
      paymentStatus: PaymentStatus.unpaid,
      paymentRef:
          'KHAM${appointmentId.replaceAll(RegExp(r'[^0-9A-Za-z]'), '')}_DAT',
      createdAt: DateTime.now(),
      stage: PaymentStage.booking,
    );
    _invoices.insert(0, newInv);
    return newInv;
  }

  /// Đợt 2: Hóa đơn Phí Xét nghiệm & Cận lâm sàng (bắt buộc thanh toán trước khi cấp QR lấy mẫu CLS)
  Future<Invoice> createOrUpdateLabInvoice(
    String appointmentId,
    List<String> labNames,
  ) async {
    final apt = AppointmentStore.instance.appointments
        .where((a) => a.id == appointmentId)
        .firstOrNull;
    final labItems = Invoice.parseLabOrdersToItems(labNames);
    final labTotal = labItems.fold<int>(0, (sum, i) => sum + i.totalPrice);

    final existingIdx = _invoices.indexWhere(
      (e) => e.appointmentId == appointmentId && e.stage == PaymentStage.lab,
    );
    if (existingIdx >= 0) {
      final current = _invoices[existingIdx];
      if (current.isPaid) return current;
      final updated = current.copyWith(
        otherFee: labTotal,
        totalAmount: labTotal,
        items: labItems,
      );
      _invoices[existingIdx] = updated;
      return updated;
    }

    final newInv = Invoice(
      id: 'inv-lab-$appointmentId',
      appointmentId: appointmentId,
      patientId: _resolvePatientId(apt),
      patientName: _resolvePatientName(apt),
      doctorId: apt?.doctorId,
      doctorName: apt?.doctorName ?? 'BS. Trần Thảo Linh',
      department: apt?.department ?? 'Khoa Tim mạch',
      invoiceCode: 'HD-CLS-${_invoices.length + 101}',
      examinationFee: 0,
      medicineFee: 0,
      otherFee: labTotal,
      totalAmount: labTotal,
      items: labItems,
      paymentStatus: PaymentStatus.unpaid,
      paymentRef:
          'CLS${appointmentId.replaceAll(RegExp(r'[^0-9A-Za-z]'), '')}_DAT',
      createdAt: DateTime.now(),
      stage: PaymentStage.lab,
    );
    _invoices.insert(0, newInv);
    return newInv;
  }

  Future<Invoice?> getLabInvoice(String appointmentId) async {
    final existing = _invoices
        .where(
          (e) =>
              e.appointmentId == appointmentId && e.stage == PaymentStage.lab,
        )
        .firstOrNull;
    if (existing != null) return existing;

    final apt = AppointmentStore.instance.appointments
        .where((a) => a.id == appointmentId)
        .firstOrNull;
    final note = apt?.statusNote ?? '';
    if (note.contains('Chỉ định CLS:') || note.contains('Kết quả CLS:')) {
      final match = RegExp(
        r'(?:Chỉ định CLS:|Kết quả CLS:)\s*([^\(\n]+)',
      ).firstMatch(note);
      final rawLabs = match != null
          ? match
                .group(1)!
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList()
          : <String>['Tổng phân tích tế bào máu (CBC)', 'Điện tâm đồ ECG'];
      return createOrUpdateLabInvoice(appointmentId, rawLabs);
    }
    return null;
  }

  /// Đợt 3: Hóa đơn Tiền Thuốc theo đơn Bác sĩ kê
  Future<Invoice?> getOrCreatePharmacyInvoice(String appointmentId) async {
    final apt = AppointmentStore.instance.appointments
        .where((a) => a.id == appointmentId)
        .firstOrNull;
    if (apt?.prescription == null || apt!.prescription!.trim().isEmpty) {
      return null;
    }

    final existingIdx = _invoices.indexWhere(
      (e) =>
          e.appointmentId == appointmentId && e.stage == PaymentStage.pharmacy,
    );
    final medItems = Invoice.parsePrescriptionToItems(apt.prescription!);
    final medFee = medItems.fold<int>(0, (sum, i) => sum + i.totalPrice);

    if (existingIdx >= 0) {
      final existing = _invoices[existingIdx];
      if (!existing.isPaid && existing.totalAmount != medFee) {
        final updated = existing.copyWith(
          medicineFee: medFee,
          totalAmount: medFee,
          items: medItems,
        );
        _invoices[existingIdx] = updated;
        return updated;
      }
      return existing;
    }

    final newInv = Invoice(
      id: 'inv-pharm-$appointmentId',
      appointmentId: appointmentId,
      patientId: _resolvePatientId(apt),
      patientName: _resolvePatientName(apt),
      doctorId: apt.doctorId,
      doctorName: apt.doctorName,
      department: apt.department,
      invoiceCode: 'HD-THUOC-${_invoices.length + 101}',
      examinationFee: 0,
      medicineFee: medFee,
      otherFee: 0,
      totalAmount: medFee,
      items: medItems,
      paymentStatus: PaymentStatus.unpaid,
      paymentRef:
          'THUOC${appointmentId.replaceAll(RegExp(r'[^0-9A-Za-z]'), '')}_DAT',
      createdAt: DateTime.now(),
      stage: PaymentStage.pharmacy,
    );
    _invoices.insert(0, newInv);
    return newInv;
  }

  /// Danh sách tất cả hóa đơn theo 3 giai đoạn của lịch hẹn
  Future<List<Invoice>> getStageInvoicesForAppointment(
    String appointmentId,
  ) async {
    final booking = await getOrCreateBookingInvoice(appointmentId);
    final lab = await getLabInvoice(appointmentId);
    final pharmacy = await getOrCreatePharmacyInvoice(appointmentId);
    return [booking, if (lab != null) lab, if (pharmacy != null) pharmacy];
  }

  /// Kiểm tra một giai đoạn cụ thể của lịch khám đã được thanh toán chưa
  Future<bool> isStagePaid(String appointmentId, PaymentStage stage) async {
    final stages = await getStageInvoicesForAppointment(appointmentId);
    final match = stages.where((e) => e.stage == stage).firstOrNull;
    if (match != null && match.isPaid) return true;

    // Tương thích ngược nếu có hóa đơn tổng hợp đã thanh toán cho ca khám này
    final anyCombinedPaid = _invoices.any(
      (e) =>
          e.appointmentId == appointmentId &&
          e.isPaid &&
          ((stage == PaymentStage.booking && e.examinationFee > 0) ||
              (stage == PaymentStage.lab && e.otherFee > 0) ||
              (stage == PaymentStage.pharmacy && e.medicineFee > 0)),
    );
    return anyCombinedPaid;
  }

  @override
  Future<Invoice> getInvoiceForAppointment(String appointmentId) async {
    final stages = await getStageInvoicesForAppointment(appointmentId);
    final unpaidStage = stages.where((e) => !e.isPaid).firstOrNull;
    if (unpaidStage != null) return unpaidStage;
    return stages.last;
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
        'bankAccountNumber': '0355157761',
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
