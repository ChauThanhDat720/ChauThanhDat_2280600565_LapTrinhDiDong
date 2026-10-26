import '../../../core/network/api_client.dart';
import '../domain/medicine.dart';

abstract interface class MedicineRepository {
  Future<List<Medicine>> getMedicines({String? search, String? category});
  Future<Medicine?> getMedicineById(String id);
  Future<Medicine?> lookupByName(String name);
  Future<List<String>> getCategories();
}

class LocalMedicineRepository implements MedicineRepository {
  const LocalMedicineRepository();

  static final List<Medicine> sampleMedicines = [
    const Medicine(
      id: 'med-paracetamol',
      name: 'Paracetamol',
      brandNames: 'Panadol, Hapacol, Efferalgan, Tylenol',
      activeIngredient: 'Paracetamol 500mg',
      category: 'Giảm đau - Hạ sốt',
      dosageForm: 'Viên nén / Viên sủi',
      indications:
          'Hạ sốt, giảm các cơn đau từ nhẹ đến vừa: đau đầu, đau răng, đau họng, đau nhức cơ khớp, đau bụng kinh.',
      dosageInstructions:
          'Người lớn: 500mg - 1000mg (1-2 viên)/lần, mỗi 4-6 giờ. Tối đa không quá 4g (8 viên)/ngày. Uống sau ăn.',
      sideEffects:
          'Hiếm gặp phát ban da, nổi mề đay. Dùng quá liều hoặc kéo dài có thể gây độc tính nghiêm trọng trên gan (suy gan cấp).',
      contraindications:
          'Quá mẫn với paracetamol. Người suy gan nặng, thiếu hụt men G6PD.',
      precautions:
          'Không uống rượu bia khi đang dùng thuốc. Tránh dùng chung với các thuốc khác cũng chứa paracetamol để tránh quá liều.',
    ),
    const Medicine(
      id: 'med-amlodipine',
      name: 'Amlodipine',
      brandNames: 'Norvasc, Amlor, Amlopin',
      activeIngredient: 'Amlodipine besylate 5mg',
      category: 'Tim mạch - Huyết áp',
      dosageForm: 'Viên nén',
      indications:
          'Điều trị tăng huyết áp vô căn, đau thắt ngực mạn tính ổn định, đau thắt ngực thể co thắt (Prinzmetal).',
      dosageInstructions:
          'Khởi đầu 5mg x 1 lần/ngày. Có thể tăng tối đa lên 10mg x 1 lần/ngày sau 2-4 tuần nếu cần. Uống cùng một thời điểm mỗi ngày.',
      sideEffects:
          'Phù cổ chân/bàn chân, nhức đầu, chóng mặt, đỏ bừng mặt, hồi hộp, mệt mỏi.',
      contraindications:
          'Hạ huyết áp nặng, sốc tim, hẹp van động mạch chủ nặng, suy tim huyết động không ổn định.',
      precautions:
          'Thận trọng ở người cao tuổi và bệnh nhân suy giảm chức năng gan.',
    ),
    const Medicine(
      id: 'med-aspirin',
      name: 'Aspirin 81mg',
      brandNames: 'Aspirin pH8, Aspilets, Cardiprin',
      activeIngredient: 'Acetylsalicylic acid 81mg',
      category: 'Tim mạch - Chống đông máu',
      dosageForm: 'Viên bao tan trong ruột',
      indications:
          'Phòng ngừa tiên phát và thứ phát nhồi máu cơ tim, đột quỵ thiếu máu cục bộ, chống kết tập tiểu cầu.',
      dosageInstructions:
          'Người lớn: 1 viên (81mg - 100mg) x 1 lần/ngày. Uống nguyên viên với nhiều nước sau bữa ăn chính.',
      sideEffects:
          'Kích ứng dạ dày, buồn nôn, khó tiêu, nguy cơ xuất huyết tiêu hóa, bầm tím dưới da.',
      contraindications:
          'Loét dạ dày tá tràng tiến triển, rối loạn đông máu, hen suyễn do NSAID, suy gan thận nặng.',
      precautions:
          'Ngừng thuốc 7 ngày trước các phẫu thuật hoặc nhổ răng. Thông báo ngay nếu có phân đen hoặc nôn ra máu.',
    ),
    const Medicine(
      id: 'med-amoxicillin',
      name: 'Amoxicillin',
      brandNames: 'Augmentin, Clamoxyl, Ospamox',
      activeIngredient: 'Amoxicillin trihydrate 500mg',
      category: 'Kháng sinh',
      dosageForm: 'Viên nang / Viên nén',
      indications:
          'Điều trị nhiễm khuẩn đường hô hấp trên và dưới (viêm họng, viêm amidan, viêm phế quản, viêm xoang), nhiễm khuẩn tai mũi họng, tiết niệu.',
      dosageInstructions:
          '500mg mỗi 8 giờ hoặc 875mg mỗi 12 giờ. Uống đủ đợt từ 7-10 ngày theo chỉ định, không tự ý ngưng thuốc giữa chừng.',
      sideEffects:
          'Tiêu chảy nhẹ, buồn nôn, nổi mẩn đỏ trên da, nhiễm nấm Candida miệng/âm đạo.',
      contraindications:
          'Tiền sử dị ứng với kháng sinh nhóm Penicillin hoặc Cephalosporin, bệnh tăng bạch cầu đơn nhân nhiễm trùng.',
      precautions:
          'Uống nhiều nước. Nếu xuất hiện phát ban ngứa hoặc khó thở, ngưng thuốc ngay lập tức.',
    ),
    const Medicine(
      id: 'med-metformin',
      name: 'Metformin',
      brandNames: 'Glucophage, Panfor, Diamet',
      activeIngredient: 'Metformin hydrochloride 500mg / 850mg',
      category: 'Tiểu đường',
      dosageForm: 'Viên nén bao phim',
      indications:
          'Điều trị đái tháo đường type 2 ở người lớn, đặc biệt ở bệnh nhân thừa cân béo phì khi chế độ ăn và luyện tập không kiểm soát đủ đường huyết.',
      dosageInstructions:
          'Khởi đầu 500mg x 1-2 lần/ngày trong hoặc ngay sau bữa ăn để giảm tác dụng phụ trên đường tiêu hóa.',
      sideEffects:
          'Đầy bụng, tiêu chảy, buồn nôn, miệng có vị kim loại, chán ăn (thường tự hết sau vài tuần).',
      contraindications:
          'Suy thận nặng (eGFR < 30), suy tim mất bù, nhiễm toan ceton do tiểu đường, nghiện rượu mạn tính.',
      precautions:
          'Tạm ngưng dùng trước 48 giờ khi chụp X-quang hoặc CT scan có tiêm thuốc cản quang chứa iod.',
    ),
    const Medicine(
      id: 'med-salbutamol',
      name: 'Salbutamol',
      brandNames: 'Ventolin Inhaler, Asmasal',
      activeIngredient: 'Salbutamol sulfate 100mcg/nhát xịt',
      category: 'Hô hấp - Hen suyễn',
      dosageForm: 'Bình xịt định liều (Inhaler)',
      indications:
          'Cắt cơn co thắt phế quản cấp trong hen phế quản, viêm phế quản mạn tính, bệnh phổi tắc nghẽn mạn tính (COPD).',
      dosageInstructions:
          'Cắt cơn hen cấp: Xịt 1-2 nhát vào miệng. Tối đa không quá 8 nhát/ngày. Lắc đều bình xịt trước khi dùng.',
      sideEffects:
          'Run ngón tay nhẹ, hồi hộp, tim đập nhanh, đau đầu, hạ kali máu thoáng qua.',
      contraindications:
          'Quá mẫn với Salbutamol, dọa sảy thai trong 6 tháng đầu.',
      precautions:
          'Thận trọng ở bệnh nhân cường giáp, rối loạn nhịp tim nhanh, tăng huyết áp.',
    ),
    const Medicine(
      id: 'med-omeprazole',
      name: 'Omeprazole',
      brandNames: 'Losec, Omez, Omeptik',
      activeIngredient: 'Omeprazole 20mg',
      category: 'Tiêu hóa - Dạ dày',
      dosageForm: 'Viên nang tan trong ruột',
      indications:
          'Viêm loét dạ dày - tá tràng, trào ngược dạ dày thực quản (GERD), hội chứng Zollinger-Ellison, phối hợp kháng sinh diệt HP.',
      dosageInstructions:
          '20mg x 1 lần/ngày. Uống nguyên viên vào buổi sáng trước bữa ăn ít nhất 30-60 phút.',
      sideEffects:
          'Nhức đầu, đầy hơi, đau bụng, táo bón hoặc tiêu chảy nhẹ.',
      contraindications:
          'Dị ứng với các thuốc ức chế bơm proton (PPI). Không phối hợp với nelfinavir.',
      precautions:
          'Không nhai hoặc nghiền nát hạt thuốc trong viên nang.',
    ),
    const Medicine(
      id: 'med-ibuprofen',
      name: 'Ibuprofen',
      brandNames: 'Gofen, Brufen, Alaxan',
      activeIngredient: 'Ibuprofen 400mg',
      category: 'Kháng viêm - Giảm đau',
      dosageForm: 'Viên nang mềm',
      indications:
          'Giảm đau và kháng viêm trong viêm khớp, thoái hóa khớp, đau lưng, đau răng, đau sau chấn thương, thống kinh.',
      dosageInstructions:
          'Người lớn: 400mg x 3 lần/ngày sau khi ăn no. Uống kèm một ly nước đầy.',
      sideEffects:
          'Ợ nóng, loét dạ dày, chóng mặt, tăng men gan, ứ dịch nhẹ.',
      contraindications:
          'Viêm loét dạ dày tiến triển, suy gan thận nặng, 3 tháng cuối thai kỳ, tiền sử co thắt phế quản do aspirin.',
      precautions:
          'Dùng liều thấp nhất có hiệu quả trong thời gian ngắn nhất có thể.',
    ),
    const Medicine(
      id: 'med-cetirizine',
      name: 'Cetirizine',
      brandNames: 'Zyrtec, Cetiriz, Virlix',
      activeIngredient: 'Cetirizine dihydrochloride 10mg',
      category: 'Dị ứng - Kháng Histamin',
      dosageForm: 'Viên nén bao phim',
      indications:
          'Điều trị viêm mũi dị ứng theo mùa hoặc quanh năm, viêm kết mạc dị ứng, mề đay mạn tính vô căn, ngứa do dị ứng thời tiết.',
      dosageInstructions:
          'Người lớn và trẻ trên 12 tuổi: 10mg (1 viên) x 1 lần/ngày vào buổi tối trước khi đi ngủ.',
      sideEffects:
          'Buồn ngủ nhẹ, khô miệng, mệt mỏi, đau đầu.',
      contraindications:
          'Suy thận giai đoạn cuối (ClCr < 10ml/phút), dị ứng với cetirizine hoặc hydroxyzine.',
      precautions:
          'Thận trọng khi lái xe hoặc vận hành máy móc do có thể gây buồn ngủ nhẹ.',
    ),
    const Medicine(
      id: 'med-atorvastatin',
      name: 'Atorvastatin',
      brandNames: 'Lipitor, Atorlip, Stator',
      activeIngredient: 'Atorvastatin calcium 20mg',
      category: 'Tim mạch - Hạ mỡ máu',
      dosageForm: 'Viên nén',
      indications:
          'Hạ cholesterol toàn phần, LDL-C, triglyceride; phòng ngừa tai biến mạch máu não và biến cố mạch vành ở người có nguy cơ cao.',
      dosageInstructions:
          'Khởi đầu 10-20mg x 1 lần/ngày vào buổi tối. Có thể điều chỉnh liều sau 4 tuần.',
      sideEffects:
          'Đau cơ, yếu cơ, rối loạn tiêu hóa nhẹ, tăng men gan thoáng qua.',
      contraindications:
          'Bệnh gan tiến triển, phụ nữ có thai và đang cho con bú.',
      precautions:
          'Báo ngay cho bác sĩ nếu bị đau cơ, yếu cơ không rõ nguyên nhân.',
    ),
  ];

  @override
  Future<List<Medicine>> getMedicines({String? search, String? category}) async {
    return sampleMedicines.where((m) {
      if (category != null && category.isNotEmpty && category != 'Tất cả') {
        if (m.category != category) return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        final nameMatches = m.name.toLowerCase().contains(q);
        final brandMatches = m.brandNames.toLowerCase().contains(q);
        final activeMatches = m.activeIngredient.toLowerCase().contains(q);
        final indicationMatches = m.indications.toLowerCase().contains(q);
        if (!nameMatches && !brandMatches && !activeMatches && !indicationMatches) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Future<Medicine?> getMedicineById(String id) async {
    return sampleMedicines.where((m) => m.id == id).firstOrNull;
  }

  @override
  Future<Medicine?> lookupByName(String name) async {
    final clean = name.trim().toLowerCase();
    for (final med in sampleMedicines) {
      if (clean.contains(med.name.toLowerCase())) return med;
      for (final brand in med.brandNames.split(',')) {
        final b = brand.trim().toLowerCase();
        if (b.isNotEmpty && clean.contains(b)) return med;
      }
    }
    return null;
  }

  @override
  Future<List<String>> getCategories() async {
    final set = sampleMedicines.map((m) => m.category).toSet();
    return set.toList();
  }
}

class RemoteMedicineRepository implements MedicineRepository {
  const RemoteMedicineRepository([this._client]);

  final ApiClient? _client;
  final LocalMedicineRepository _fallback = const LocalMedicineRepository();

  @override
  Future<List<Medicine>> getMedicines({String? search, String? category}) async {
    try {
      if (_client == null) {
        return await _fallback.getMedicines(search: search, category: category);
      }
      final query = <String, String>{};
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (category != null && category.isNotEmpty && category != 'Tất cả') {
        query['category'] = category;
      }

      final result = await _client.get('/medicines', query: query);
      final items = result is Map<String, dynamic> ? result['items'] : result;
      if (items is List) {
        return items
            .whereType<Map<String, dynamic>>()
            .map(Medicine.fromJson)
            .toList();
      }
      return await _fallback.getMedicines(search: search, category: category);
    } catch (_) {
      return _fallback.getMedicines(search: search, category: category);
    }
  }

  @override
  Future<Medicine?> getMedicineById(String id) async {
    try {
      if (_client == null) {
        return await _fallback.getMedicineById(id);
      }
      final result = await _client.get('/medicines/$id');
      if (result is Map<String, dynamic>) {
        return Medicine.fromJson(result);
      }
      return await _fallback.getMedicineById(id);
    } catch (_) {
      return _fallback.getMedicineById(id);
    }
  }

  @override
  Future<Medicine?> lookupByName(String name) async {
    try {
      if (_client == null) {
        return await _fallback.lookupByName(name);
      }
      final result = await _client.get('/medicines/lookup', query: {'name': name});
      if (result is Map<String, dynamic>) {
        return Medicine.fromJson(result);
      }
      return await _fallback.lookupByName(name);
    } catch (_) {
      return _fallback.lookupByName(name);
    }
  }

  @override
  Future<List<String>> getCategories() async {
    try {
      if (_client == null) {
        return await _fallback.getCategories();
      }
      final result = await _client.get('/medicines/categories');
      if (result is Map<String, dynamic> && result['items'] is List) {
        return (result['items'] as List).cast<String>();
      }
      return await _fallback.getCategories();
    } catch (_) {
      return _fallback.getCategories();
    }
  }
}
