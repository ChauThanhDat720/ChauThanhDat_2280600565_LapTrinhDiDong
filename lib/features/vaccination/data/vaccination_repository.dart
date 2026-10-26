import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/app_timezone.dart';
import '../domain/vaccination_record.dart';

abstract interface class VaccinationRepository {
  Future<List<VaccinationRecord>> getVaccinations({String? patientId, String? familyMemberId});
  Future<VaccinationRecord?> getVaccinationById(String id);
  Future<VaccinationRecord?> getVaccinationByCertificateCode(String certCode);
  Future<List<VaccinationRecord>> getUpcomingDoses({String? patientId});
  Future<List<VaccineProtocolGroup>> getProtocols();
  Future<VaccinationRecord> saveVaccination(VaccinationRecord record);
}

class VaccinationStore extends ChangeNotifier {
  VaccinationStore._();
  static final instance = VaccinationStore._();

  final List<VaccinationRecord> _records = [];
  List<VaccinationRecord> get records => List.unmodifiable(_records);

  void clearForTest() {
    _records.clear();
    notifyListeners();
  }

  void seedIfEmpty() {
    if (_records.isNotEmpty) return;
    final now = AppTimezone.now();

    final rec1 = VaccinationRecord(
      id: 'vac-001',
      patientId: 'BN-01',
      familyMemberId: 'fam-self',
      patientName: 'Nguyễn Văn An',
      vaccineName: 'Gardasil 9 (Mỹ)',
      targetDisease: 'Ung thư cổ tử cung, u nhú & mụn cóc sinh dục do HPV',
      doseNumber: 1,
      totalDoses: 3,
      batchNumber: 'MSD-VN2408',
      manufacturer: 'Merck Sharp & Dohme (Mỹ)',
      administeredDate: now.subtract(const Duration(days: 60)),
      nextDoseDate: now.add(const Duration(days: 7)),
      facilityName: 'Bệnh viện Đa khoa Quốc tế Smart Hospital',
      doctorName: 'BS. Trần Thảo Linh',
      nurseName: 'ĐD. Lê Thị Hồng',
      reactionStatus: 'Vết tiêm hơi căng tức nhẹ, hết sau 24h',
      certificateCode: 'VAC-2026-VN-98231',
      status: 'completed',
    );

    final rec2 = VaccinationRecord(
      id: 'vac-002',
      patientId: 'BN-01',
      familyMemberId: 'fam-self',
      patientName: 'Nguyễn Văn An',
      vaccineName: 'Vaxigrip Tetra (Pháp)',
      targetDisease: 'Cúm mùa tứ giá (A/H1N1, A/H3N2, B/Victoria, B/Yamagata)',
      doseNumber: 1,
      totalDoses: 1,
      batchNumber: 'SNF-FR7712',
      manufacturer: 'Sanofi Pasteur (Pháp)',
      administeredDate: now.subtract(const Duration(days: 30)),
      nextDoseDate: null,
      facilityName: 'Bệnh viện Đa khoa Quốc tế Smart Hospital',
      doctorName: 'BS. Trần Thảo Linh',
      nurseName: 'ĐD. Lê Thị Hồng',
      reactionStatus: 'Bình thường, không sốt, không phản ứng phụ',
      certificateCode: 'VAC-2026-VN-87123',
      status: 'completed',
    );

    final rec3 = VaccinationRecord(
      id: 'vac-003',
      patientId: 'BN-01',
      familyMemberId: 'fam-self',
      patientName: 'Nguyễn Văn An',
      vaccineName: 'Engerix B 20mcg (Bỉ)',
      targetDisease: 'Viêm gan virus B',
      doseNumber: 3,
      totalDoses: 3,
      batchNumber: 'GSK-BE8921',
      manufacturer: 'GlaxoSmithKline - GSK (Bỉ)',
      administeredDate: now.subtract(const Duration(days: 180)),
      nextDoseDate: null,
      facilityName: 'Bệnh viện Đa khoa Quốc tế Smart Hospital',
      doctorName: 'BS. Trần Thảo Linh',
      nurseName: 'ĐD. Nguyễn Thu Hà',
      reactionStatus: 'Bình thường, nồng độ kháng thể Anti-HBs đạt > 1000 mIU/mL',
      certificateCode: 'VAC-2026-VN-66512',
      status: 'completed',
    );

    final rec4 = VaccinationRecord(
      id: 'vac-004',
      patientId: 'BN-01',
      familyMemberId: 'fam-child',
      patientName: 'Nguyễn Minh Khang',
      vaccineName: 'Infanrix Hexa 6 trong 1 (Bỉ)',
      targetDisease: 'Bạch hầu, Ho gà, Uốn ván, Bại liệt, Hib, Viêm gan B',
      doseNumber: 3,
      totalDoses: 3,
      batchNumber: 'GSK-6IN1-5521',
      manufacturer: 'GlaxoSmithKline - GSK (Bỉ)',
      administeredDate: now.subtract(const Duration(days: 300)),
      nextDoseDate: null,
      facilityName: 'Bệnh viện Đa khoa Quốc tế Smart Hospital',
      doctorName: 'BS. Lê Thị Mai',
      nurseName: 'ĐD. Nguyễn Thu Hà',
      reactionStatus: 'Sốt nhẹ 37.8 độ C sau tiêm 6h, hạ sốt sau uống Paracetamol',
      certificateCode: 'VAC-2026-VN-33109',
      status: 'completed',
    );

    _records.addAll([rec1, rec2, rec3, rec4]);
    notifyListeners();
  }

  void save(VaccinationRecord record) {
    final idx = _records.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      _records[idx] = record;
    } else {
      _records.insert(0, record);
    }
    notifyListeners();
  }

  List<VaccinationRecord> getByFamilyMember(String? familyMemberId) {
    seedIfEmpty();
    if (familyMemberId == null || familyMemberId.isEmpty || familyMemberId == 'all') {
      return List.unmodifiable(_records);
    }
    return _records.where((r) => r.familyMemberId == familyMemberId).toList();
  }

  List<VaccinationRecord> getUpcoming() {
    seedIfEmpty();
    return _records.where((r) => r.nextDoseDate != null).toList()
      ..sort((a, b) => a.nextDoseDate!.compareTo(b.nextDoseDate!));
  }
}

class LocalVaccinationRepository implements VaccinationRepository {
  const LocalVaccinationRepository();

  @override
  Future<List<VaccinationRecord>> getVaccinations({String? patientId, String? familyMemberId}) async {
    VaccinationStore.instance.seedIfEmpty();
    return VaccinationStore.instance.getByFamilyMember(familyMemberId);
  }

  @override
  Future<VaccinationRecord?> getVaccinationById(String id) async {
    VaccinationStore.instance.seedIfEmpty();
    return VaccinationStore.instance.records.where((r) => r.id == id).firstOrNull;
  }

  @override
  Future<VaccinationRecord?> getVaccinationByCertificateCode(String certCode) async {
    VaccinationStore.instance.seedIfEmpty();
    return VaccinationStore.instance.records.where((r) => r.certificateCode == certCode).firstOrNull;
  }

  @override
  Future<List<VaccinationRecord>> getUpcomingDoses({String? patientId}) async {
    return VaccinationStore.instance.getUpcoming();
  }

  @override
  Future<List<VaccineProtocolGroup>> getProtocols() async {
    return const [
      VaccineProtocolGroup(
        ageGroup: '0 - 12 tuổi (Trẻ sơ sinh & Trẻ nhỏ)',
        vaccines: [
          VaccineProtocolItem(
            name: 'Vắc-xin Lao (BCG)',
            target: 'Lao màng não & lao phổi sơ sinh',
            schedule: '1 mũi duy nhất trong 24-48h sau sinh',
            recommendedDoses: 1,
          ),
          VaccineProtocolItem(
            name: 'Vắc-xin 6 trong 1 (Infanrix Hexa / Hexaxim)',
            target: 'Bạch hầu, Ho gà, Uốn ván, Bại liệt, Hib, Viêm gan B',
            schedule: '3 mũi lúc 2, 3, 4 tháng; nhắc mũi 4 lúc 16-18 tháng',
            recommendedDoses: 4,
          ),
          VaccineProtocolItem(
            name: 'Vắc-xin Phế cầu khuẩn (Synflorix / Prevenar 13)',
            target: 'Viêm phổi, viêm tai giữa, viêm màng não do phế cầu',
            schedule: 'Lúc 2, 4, 6 tháng và mũi nhắc sau 1 tuổi',
            recommendedDoses: 4,
          ),
          VaccineProtocolItem(
            name: 'Vắc-xin Sởi - Quai bị - Rubella (MMR)',
            target: 'Sởi, Quai bị, Rubella',
            schedule: 'Mũi 1 lúc 9-12 tháng, mũi 2 lúc 4-6 tuổi',
            recommendedDoses: 2,
          ),
        ],
      ),
      VaccineProtocolGroup(
        ageGroup: '13 - 49 tuổi (Thanh thiếu niên & Người trưởng thành)',
        vaccines: [
          VaccineProtocolItem(
            name: 'Vắc-xin HPV 9 chủng (Gardasil 9)',
            target: 'Ung thư cổ tử cung, âm đạo, hậu môn và sùi mào gà',
            schedule: 'Phác đồ 3 mũi: 0 - 2 - 6 tháng (từ 9 đến 45 tuổi)',
            recommendedDoses: 3,
          ),
          VaccineProtocolItem(
            name: 'Vắc-xin Cúm mùa tứ giá (Vaxigrip Tetra)',
            target: 'Cúm mùa A (H1N1, H3N2) và Cúm B',
            schedule: 'Tiêm nhắc lại 1 mũi mỗi năm vào đầu mùa dịch',
            recommendedDoses: 1,
          ),
          VaccineProtocolItem(
            name: 'Vắc-xin Viêm gan B (Engerix B)',
            target: 'Viêm gan B, xơ gan và ung thư tế bào gan',
            schedule: 'Phác đồ 0 - 1 - 6 tháng; kiểm tra kháng thể sau 5 năm',
            recommendedDoses: 3,
          ),
          VaccineProtocolItem(
            name: 'Vắc-xin Uốn ván - Bạch hầu (Td / Adacel)',
            target: 'Uốn ván, Bạch hầu',
            schedule: 'Tiêm nhắc lại mỗi 10 năm/lần hoặc khi có vết thương',
            recommendedDoses: 1,
          ),
        ],
      ),
      VaccineProtocolGroup(
        ageGroup: 'Phụ nữ chuẩn bị mang thai',
        vaccines: [
          VaccineProtocolItem(
            name: 'Vắc-xin Sởi - Quai bị - Rubella (MMR II)',
            target: 'Hội chứng Rubella bẩm sinh, quái thai',
            schedule: 'Hoàn tất trước khi có thai tối thiểu 3 tháng',
            recommendedDoses: 1,
          ),
          VaccineProtocolItem(
            name: 'Vắc-xin Thủy đậu (Varivax)',
            target: 'Thủy đậu thai kỳ, dị tật bẩm sinh',
            schedule: '2 mũi cách nhau 1 tháng, hoàn tất trước mang thai 3 tháng',
            recommendedDoses: 2,
          ),
          VaccineProtocolItem(
            name: 'Vắc-xin Uốn ván thai phụ (VAT)',
            target: 'Uốn ván sơ sinh cho mẹ và con',
            schedule: '2 mũi trong thai kỳ (mũi 2 trước sinh tối thiểu 1 tháng)',
            recommendedDoses: 2,
          ),
        ],
      ),
      VaccineProtocolGroup(
        ageGroup: 'Người cao tuổi & Bệnh nền tim mạch (≥ 50 tuổi)',
        vaccines: [
          VaccineProtocolItem(
            name: 'Vắc-xin Phế cầu 13 (Prevenar 13)',
            target: 'Viêm phổi cộng đồng, nhiễm khuẩn huyết phế cầu',
            schedule: '1 mũi duy nhất cho người lớn tuổi / suy tim, tăng huyết áp',
            recommendedDoses: 1,
          ),
          VaccineProtocolItem(
            name: 'Vắc-xin Cúm mùa hàng năm (Vaxigrip Tetra)',
            target: 'Biến chứng tim mạch do cúm, suy tim cấp do nhiễm trùng',
            schedule: '1 mũi tiêm nhắc đều đặn mỗi năm',
            recommendedDoses: 1,
          ),
          VaccineProtocolItem(
            name: 'Vắc-xin Zona thần kinh (Shingrix)',
            target: 'Đau dây thần kinh sau zona, biến chứng mắt',
            schedule: '2 mũi cách nhau 2-6 tháng cho người từ 50 tuổi trở lên',
            recommendedDoses: 2,
          ),
        ],
      ),
    ];
  }

  @override
  Future<VaccinationRecord> saveVaccination(VaccinationRecord record) async {
    VaccinationStore.instance.save(record);
    return record;
  }
}

class RemoteVaccinationRepository implements VaccinationRepository {
  const RemoteVaccinationRepository([this._client]);
  final ApiClient? _client;
  static const _fallback = LocalVaccinationRepository();

  @override
  Future<List<VaccinationRecord>> getVaccinations({String? patientId, String? familyMemberId}) async {
    try {
      if (_client == null) return await _fallback.getVaccinations(patientId: patientId, familyMemberId: familyMemberId);
      final query = <String, String>{};
      if (patientId != null) query['patientId'] = patientId;
      if (familyMemberId != null) query['familyMemberId'] = familyMemberId;

      final res = await _client.get('/vaccinations', query: query);
      if (res is Map<String, dynamic> && res['vaccinations'] is List) {
        final list = (res['vaccinations'] as List)
            .map((e) => VaccinationRecord.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final rec in list) {
          VaccinationStore.instance.save(rec);
        }
        return list;
      }
      return await _fallback.getVaccinations(patientId: patientId, familyMemberId: familyMemberId);
    } catch (_) {
      return await _fallback.getVaccinations(patientId: patientId, familyMemberId: familyMemberId);
    }
  }

  @override
  Future<VaccinationRecord?> getVaccinationById(String id) async {
    try {
      if (_client == null) return await _fallback.getVaccinationById(id);
      final res = await _client.get('/vaccinations/$id');
      if (res is Map<String, dynamic>) {
        return VaccinationRecord.fromJson(res);
      }
      return await _fallback.getVaccinationById(id);
    } catch (_) {
      return await _fallback.getVaccinationById(id);
    }
  }

  @override
  Future<VaccinationRecord?> getVaccinationByCertificateCode(String certCode) async {
    try {
      if (_client == null) return await _fallback.getVaccinationByCertificateCode(certCode);
      final res = await _client.get('/vaccinations/passport/$certCode');
      if (res is Map<String, dynamic> && res['certificate'] is Map<String, dynamic>) {
        return VaccinationRecord.fromJson(res['certificate'] as Map<String, dynamic>);
      }
      return await _fallback.getVaccinationByCertificateCode(certCode);
    } catch (_) {
      return await _fallback.getVaccinationByCertificateCode(certCode);
    }
  }

  @override
  Future<List<VaccinationRecord>> getUpcomingDoses({String? patientId}) async {
    try {
      if (_client == null) return await _fallback.getUpcomingDoses(patientId: patientId);
      final query = <String, String>{};
      if (patientId != null) query['patientId'] = patientId;
      final res = await _client.get('/vaccinations/upcoming', query: query);
      if (res is Map<String, dynamic> && res['upcoming'] is List) {
        return (res['upcoming'] as List)
            .map((e) => VaccinationRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return await _fallback.getUpcomingDoses(patientId: patientId);
    } catch (_) {
      return await _fallback.getUpcomingDoses(patientId: patientId);
    }
  }

  @override
  Future<List<VaccineProtocolGroup>> getProtocols() async {
    try {
      if (_client == null) return await _fallback.getProtocols();
      final res = await _client.get('/vaccinations/protocols');
      if (res is Map<String, dynamic> && res['protocols'] is List) {
        return (res['protocols'] as List)
            .map((e) => VaccineProtocolGroup.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return await _fallback.getProtocols();
    } catch (_) {
      return await _fallback.getProtocols();
    }
  }

  @override
  Future<VaccinationRecord> saveVaccination(VaccinationRecord record) async {
    try {
      VaccinationStore.instance.save(record);
      if (_client != null) {
        final res = await _client.post('/vaccinations', body: record.toJson());
        if (res is Map<String, dynamic>) {
          return VaccinationRecord.fromJson(res);
        }
      }
      return record;
    } catch (_) {
      return record;
    }
  }
}
