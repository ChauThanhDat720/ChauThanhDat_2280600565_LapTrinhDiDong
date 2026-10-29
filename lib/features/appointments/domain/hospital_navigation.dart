import 'package:flutter/material.dart';

import 'appointment.dart';

/// Đại diện cho 1 bước trong lộ trình di chuyển của bệnh nhân tại bệnh viện
class NavigationStep {
  const NavigationStep({
    required this.stepNumber,
    required this.title,
    required this.roomCode,
    required this.locationName,
    required this.directions,
    required this.buildingWing,
    required this.floor,
    required this.icon,
    this.badge,
    this.isDone = false,
    this.isCurrent = false,
  });

  final int stepNumber;
  final String title;
  final String roomCode;
  final String locationName;
  final String directions;
  final String buildingWing; // Khu A, Khu B, Khu C
  final String floor; // Tầng trệt, Tầng 1, Tầng 2, Tầng 3
  final IconData icon;
  final String? badge;
  final bool isDone;
  final bool isCurrent;
}

/// Thông tin lộ trình tổng thể được tính toán linh hoạt theo từng Bác sĩ & Ca khám
class HospitalRoute {
  const HospitalRoute({
    required this.doctorId,
    required this.doctorName,
    required this.department,
    required this.specialty,
    required this.clinicRoom,
    required this.buildingWing,
    required this.floor,
    required this.elevatorNote,
    required this.paraclinicalLab,
    required this.pharmacyDesk,
    required this.estimatedWalkingMinutes,
    required this.steps,
  });

  final String doctorId;
  final String doctorName;
  final String department;
  final String specialty;
  final String clinicRoom;
  final String buildingWing;
  final String floor;
  final String elevatorNote;
  final String paraclinicalLab;
  final String pharmacyDesk;
  final int estimatedWalkingMinutes;
  final List<NavigationStep> steps;
}

/// Dữ liệu sơ đồ từng tầng để vẽ mặt bằng thông minh
class HospitalFloorPlan {
  const HospitalFloorPlan({
    required this.floorLevel,
    required this.floorName,
    required this.description,
    required this.wings,
  });

  final int floorLevel;
  final String floorName;
  final String description;
  final List<HospitalWingPlan> wings;
}

class HospitalWingPlan {
  const HospitalWingPlan({required this.wingName, required this.rooms});

  final String wingName;
  final List<HospitalRoomInfo> rooms;
}

class HospitalRoomInfo {
  const HospitalRoomInfo({
    required this.roomCode,
    required this.name,
    required this.category,
    this.doctorId,
  });

  final String roomCode;
  final String name;
  final String category; // 'clinic', 'lab', 'pharmacy', 'reception'
  final String? doctorId;
}

/// Bộ điều phối Lộ trình Bệnh viện Thông minh (Tự động linh hoạt theo từng Bác sĩ)
class HospitalNavigationResolver {
  const HospitalNavigationResolver._();

  static const Map<String, Map<String, String>> _doctorProfiles = {
    'dr-linh': {
      'room': 'Phòng 204 - Tầng 2',
      'wing': 'Khu B',
      'floor': 'Tầng 2',
      'elevator': 'Thang máy Trụ B (Bên phải sảnh trung tâm) lên Tầng 2',
      'directions': 'Ra khỏi thang máy Trụ B, rẽ phải 15m. Phòng 204 nằm bên tay trái đối diện sảnh chờ Tim mạch.',
      'lab': 'Phòng 208 - Đo Điện tim ECG & Siêu âm Tim màu (Tầng 2 Khu B)',
      'labDirections':
          'Từ phòng khám rẽ phải đi tiếp 20m cùng dãy hành lang Tầng 2.',
      'pharmacy': 'Quầy Dược số 2 - Tầng 1 Khu B (Cạnh quầy viện phí)',
      'minutes': '3',
    },
    'dr-duc': {
      'room': 'Phòng 105 - Tầng 1',
      'wing': 'Khu A',
      'floor': 'Tầng 1',
      'elevator':
          'Sảnh Nhi khoa Tầng trệt đi thẳng vào 40m (Không cần thang máy)',
      'directions': 'Từ quầy tiếp đón đi thẳng theo đường line màu Vàng (Khu Nhi khoa). Phòng 105 có khu vui chơi trẻ em.',
      'lab': 'Phòng 108 - Lấy mẫu xét nghiệm Nhi & Cân đo sinh trắc (Tầng 1 Khu A)',
      'labDirections':
          'Đối diện phòng khám 105, cách 10m về phía bên phải sảnh Nhi.',
      'pharmacy': 'Quầy Dược số 1 - Tầng 1 Khu A (Quầy Dược Nhi & Cấp tốc)',
      'minutes': '2',
    },
    'dr-lan': {
      'room': 'Phòng 302 - Tầng 3',
      'wing': 'Khu C',
      'floor': 'Tầng 3',
      'elevator': 'Thang máy Trụ C (Phía đông tòa nhà) lên Tầng 3',
      'directions': 'Ra thang máy Trụ C rẽ trái ngay sảnh chờ Chuyên khoa Da liễu. Phòng 302 có đèn xanh báo hiệu.',
      'lab':
          'Phòng 305 - Soi da kỹ thuật số & Thủ thuật Da liễu (Tầng 3 Khu C)',
      'labDirections': 'Cùng hành lang Tầng 3 Khu C, cách phòng khám 3 phòng.',
      'pharmacy': 'Quầy Dược số 2 - Tầng 1 Khu B',
      'minutes': '4',
    },
    'dr-tuan': {
      'room': 'Phòng 201 - Tầng 2',
      'wing': 'Khu B',
      'floor': 'Tầng 2',
      'elevator': 'Thang máy Trụ B hoặc cầu thang bộ giữa lên Tầng 2',
      'directions':
          'Ngay đầu hành lang Tầng 2 Khu B, phòng đầu tiên bên tay phải.',
      'lab': 'Phòng 206 - Phòng Lấy máu & Tiếp nhận bệnh phẩm (Tầng 2 Khu B)',
      'labDirections':
          'Đi dọc hành lang 30m đến ngã rẽ phòng Xét nghiệm chung.',
      'pharmacy': 'Quầy Dược số 2 - Tầng 1 Khu B',
      'minutes': '3',
    },
    'dr-huong': {
      'room': 'Phòng 212 - Tầng 2',
      'wing': 'Khu B',
      'floor': 'Tầng 2',
      'elevator': 'Thang máy Trụ B lên Tầng 2 rẽ phải cuối hành lang',
      'directions': 'Đi hết hành lang Khu B Tầng 2, phòng Nội soi & Khám TMH nằm ở góc yên tĩnh cuối cánh gà.',
      'lab': 'Phòng 215 - Nội soi Tai Mũi Họng ống mềm HD (Tầng 2 Khu B)',
      'labDirections': 'Nằm liền kề phòng khám 212 (có cửa thông liên phòng).',
      'pharmacy': 'Quầy Dược số 2 - Tầng 1 Khu B',
      'minutes': '3',
    },
    'dr-phong': {
      'room': 'Phòng 310 - Tầng 3',
      'wing': 'Khu C',
      'floor': 'Tầng 3',
      'elevator': 'Thang máy Trụ C lên Tầng 3 đi qua cầu nối kính Khu C',
      'directions': 'Đi qua cầu nối kính sang Khu Thần kinh, phòng 310 nằm bên phải gần phòng đo điện não.',
      'lab': 'Phòng 312 - Đo Điện não đồ EEG & Lưu huyết não (Tầng 3 Khu C)',
      'labDirections':
          'Cạnh phòng 310, rẽ phải tại biển chỉ dẫn Thần kinh chức năng.',
      'pharmacy': 'Quầy Dược số 2 - Tầng 1 Khu B',
      'minutes': '4',
    },
    'dr-mai': {
      'room': 'Phòng 118 - Tầng 1',
      'wing': 'Khu A',
      'floor': 'Tầng 1',
      'elevator': 'Tầng trệt sảnh A đi thẳng qua sảnh Chấn thương (Không cần thang máy)',
      'directions': 'Từ quầy tiếp đón đi theo vạch chỉ dẫn màu Đỏ (Khu Cơ Xương Khớp). Phòng rộng có lối đi cho xe lăn.',
      'lab': 'Phòng 120 - Chụp X-quang Kỹ thuật số & Đo mật độ xương (Tầng 1 Khu A)',
      'labDirections': 'Đối diện phòng khám 118, có biển cảnh báo tia X.',
      'pharmacy': 'Quầy Dược số 1 - Tầng 1 Khu A',
      'minutes': '2',
    },
    'dr-khanh': {
      'room': 'Phòng 308 - Tầng 3',
      'wing': 'Khu C',
      'floor': 'Tầng 3',
      'elevator': 'Thang máy Trụ C lên Tầng 3 rẽ phải vào Khoa Nha',
      'directions': 'Ra khỏi thang máy Trụ C, rẽ phải vào sảnh Chăm sóc Răng Hàm Mặt. Phòng 308.',
      'lab': 'Phòng 309 - Chụp X-quang Nha khoa Panorama & CT ConeBeam (Tầng 3 Khu C)',
      'labDirections': 'Nằm ngay cạnh cửa phòng khám 308.',
      'pharmacy': 'Quầy Dược số 2 - Tầng 1 Khu B',
      'minutes': '4',
    },
  };

  /// Lấy số phòng khám mặc định theo Bác sĩ (linh hoạt, không fix cứng)
  static String getDoctorClinicRoom(String doctorId, {String? department}) {
    if (_doctorProfiles.containsKey(doctorId)) {
      return _doctorProfiles[doctorId]!['room']!;
    }
    // Fallback thông minh theo chuyên khoa nếu có bác sĩ mới
    final dept = (department ?? '').toLowerCase();
    if (dept.contains('nhi')) return 'Phòng 105 - Tầng 1 Khu A';
    if (dept.contains('xương') || dept.contains('chấn thương')) {
      return 'Phòng 118 - Tầng 1 Khu A';
    }
    if (dept.contains('da liễu') ||
        dept.contains('thần kinh') ||
        dept.contains('răng')) {
      return 'Phòng 302 - Tầng 3 Khu C';
    }
    return 'Phòng 204 - Tầng 2 Khu B';
  }

  /// Trích xuất hoặc giải mã Lộ trình đầy đủ 4 bước cho Ca khám cụ thể
  static HospitalRoute resolveRoute(Appointment appointment) {
    final docId = appointment.doctorId;
    final profile = _doctorProfiles[docId];

    final roomStr =
        appointment.roomNumber ??
        profile?['room'] ??
        getDoctorClinicRoom(docId, department: appointment.department);

    final wing =
        profile?['wing'] ??
        (roomStr.contains('Khu A')
            ? 'Khu A'
            : (roomStr.contains('Khu C') ? 'Khu C' : 'Khu B'));
    final floor =
        profile?['floor'] ??
        (roomStr.contains('Tầng 1')
            ? 'Tầng 1'
            : (roomStr.contains('Tầng 3') ? 'Tầng 3' : 'Tầng 2'));
    final elevator = profile?['elevator'] ?? 'Đi thang máy đến $floor $wing';
    final directions =
        profile?['directions'] ??
        'Theo bảng chỉ dẫn tại hành lang $floor $wing đến $roomStr.';
    final lab =
        profile?['lab'] ??
        'Phòng Cận lâm sàng & Xét nghiệm trung tâm (Tầng 2 Khu B)';
    final labDirections =
        profile?['labDirections'] ??
        'Theo biển chỉ dẫn phòng Xét nghiệm tại cùng tầng hoặc Tầng 2.';
    final pharmacy =
        profile?['pharmacy'] ??
        (wing == 'Khu A'
            ? 'Quầy Dược số 1 - Tầng 1 Khu A'
            : 'Quầy Dược số 2 - Tầng 1 Khu B');
    final walkingMinutes = int.tryParse(profile?['minutes'] ?? '3') ?? 3;

    final isCheckedIn =
        appointment.status == AppointmentStatus.checkedIn ||
        appointment.status == AppointmentStatus.completed;
    final isCompleted = appointment.status == AppointmentStatus.completed;
    final journey = appointment.journey;
    final labActive = ['lab_ordered', 'lab_reported'].contains(journey?.stage);
    final cancelled = appointment.status == AppointmentStatus.cancelled;

    final steps = [
      NavigationStep(
        stepNumber: 1,
        title: 'Tiếp đón & Xác thực Check-in',
        roomCode: 'SẢNH-01',
        locationName: 'Quầy Tiếp đón Trung tâm (Tầng trệt)',
        directions: 'Xuất trình mã QR trên Thẻ lên phòng khám tại kiosk hoặc quầy lễ tân để nhận Số Thứ Tự (STT).',
        buildingWing: 'Sảnh Trung Tâm',
        floor: 'Tầng trệt',
        icon: Icons.qr_code_scanner_rounded,
        badge: isCheckedIn ? 'ĐÃ TIẾP ĐÓN' : 'BƯỚC HIỆN TẠI',
        isDone: isCheckedIn,
        isCurrent: !isCheckedIn && !cancelled,
      ),
      NavigationStep(
        stepNumber: 2,
        title: 'Khám chuyên khoa với ${appointment.doctorName}',
        roomCode: roomStr,
        locationName: '$roomStr ($wing)',
        directions: '$elevator. $directions',
        buildingWing: wing,
        floor: floor,
        icon: Icons.meeting_room_rounded,
        badge: isCompleted
            ? 'ĐÃ KHÁM XONG'
            : journey?.stage == 'consulting'
            ? 'BÁC SĨ ĐÃ GỌI'
            : journey?.stage == 'lab_completed'
            ? 'CHỜ KẾT LUẬN'
            : (isCheckedIn ? 'ĐANG CHỜ GỌI KHÁM' : 'BƯỚC TIẾP THEO'),
        isDone: isCompleted,
        isCurrent: isCheckedIn && !isCompleted && !labActive && !cancelled,
      ),
      NavigationStep(
        stepNumber: 3,
        title: 'Thực hiện Cận lâm sàng (Nếu có chỉ định)',
        roomCode: lab.split(' - ').first,
        locationName: lab,
        directions: labDirections,
        buildingWing: wing,
        floor: floor,
        icon: Icons.biotech_rounded,
        badge: journey?.labReviewed == true
            ? 'BÁC SĨ ĐÃ XEM'
            : journey?.stage == 'lab_reported'
            ? 'CHỜ BÁC SĨ XEM'
            : labActive
            ? 'ĐÃ CHỈ ĐỊNH'
            : journey?.prescribed == true
            ? 'KHÔNG CHỈ ĐỊNH'
            : 'KHI CÓ CHỈ ĐỊNH',
        isDone:
            journey?.labReviewed == true ||
            (journey?.prescribed == true && journey?.hasLabOrder == false),
        isCurrent: labActive && !cancelled,
      ),
      NavigationStep(
        stepNumber: 4,
        title: 'Thanh toán & Nhận thuốc theo đơn',
        roomCode: pharmacy.split(' - ').first,
        locationName: pharmacy,
        directions: 'Sau khi hoàn tất khám và thanh toán VietQR, đến quầy dược xuất trình mã đơn thuốc để nhận thuốc mang về.',
        buildingWing: wing == 'Khu A' ? 'Khu A' : 'Khu B',
        floor: 'Tầng 1',
        icon: Icons.local_pharmacy_rounded,
        badge: journey?.medicinesReceived == true
            ? 'ĐÃ NHẬN THUỐC'
            : journey?.paymentSimulated == true
            ? 'CHỜ NHẬN THUỐC'
            : isCompleted
            ? 'SẴN SÀNG NHẬN THUỐC'
            : 'BƯỚC CUỐI CÙNG',
        isDone: journey?.medicinesReceived == true,
        isCurrent: isCompleted && journey?.medicinesReceived != true,
      ),
    ];

    return HospitalRoute(
      doctorId: docId,
      doctorName: appointment.doctorName,
      department: appointment.department,
      specialty: appointment.specialty,
      clinicRoom: roomStr,
      buildingWing: wing,
      floor: floor,
      elevatorNote: elevator,
      paraclinicalLab: lab,
      pharmacyDesk: pharmacy,
      estimatedWalkingMinutes: walkingMinutes,
      steps: steps,
    );
  }

  /// Trả về sơ đồ các tầng cho Modal Sơ đồ Bệnh viện (Floor Plan Map)
  static List<HospitalFloorPlan> getFloorPlans() {
    return const [
      HospitalFloorPlan(
        floorLevel: 0,
        floorName: 'Tầng trệt (Ground Floor)',
        description:
            'Sảnh chính, Kiosk Check-in tự động, Tiếp đón trung tâm, Cấp cứu',
        wings: [
          HospitalWingPlan(
            wingName: 'Sảnh Trung Tâm',
            rooms: [
              HospitalRoomInfo(
                roomCode: 'Q-01',
                name: 'Quầy Tiếp đón 1 & 2',
                category: 'reception',
              ),
              HospitalRoomInfo(
                roomCode: 'KIOSK',
                name: 'Trụ Kiosk Quét QR tự động',
                category: 'reception',
              ),
            ],
          ),
          HospitalWingPlan(
            wingName: 'Khu A (Cấp cứu)',
            rooms: [
              HospitalRoomInfo(
                roomCode: 'CC-01',
                name: 'Cấp cứu 24/7',
                category: 'clinic',
              ),
            ],
          ),
        ],
      ),
      HospitalFloorPlan(
        floorLevel: 1,
        floorName: 'Tầng 1 (1st Floor)',
        description:
            'Khoa Nhi, Chấn thương chỉnh hình, Nhà thuốc Bệnh viện số 1 & 2',
        wings: [
          HospitalWingPlan(
            wingName: 'Khu A',
            rooms: [
              HospitalRoomInfo(
                roomCode: 'Phòng 105',
                name: 'BS. Nguyễn Đức Minh (Nhi khoa)',
                category: 'clinic',
                doctorId: 'dr-duc',
              ),
              HospitalRoomInfo(
                roomCode: 'Phòng 108',
                name: 'Xét nghiệm máu Nhi & Cân đo',
                category: 'lab',
              ),
              HospitalRoomInfo(
                roomCode: 'Phòng 118',
                name: 'BS. Bùi Thanh Mai (Chấn thương)',
                category: 'clinic',
                doctorId: 'dr-mai',
              ),
              HospitalRoomInfo(
                roomCode: 'Phòng 120',
                name: 'Chụp X-quang Kỹ thuật số',
                category: 'lab',
              ),
              HospitalRoomInfo(
                roomCode: 'Dược 1',
                name: 'Quầy Dược số 1 (Nhi khoa & Cấp tốc)',
                category: 'pharmacy',
              ),
            ],
          ),
          HospitalWingPlan(
            wingName: 'Khu B',
            rooms: [
              HospitalRoomInfo(
                roomCode: 'Dược 2',
                name: 'Quầy Dược số 2 & Viện phí VietQR',
                category: 'pharmacy',
              ),
            ],
          ),
        ],
      ),
      HospitalFloorPlan(
        floorLevel: 2,
        floorName: 'Tầng 2 (2nd Floor)',
        description: 'Khoa Tim mạch, Nội tổng quát, Tai Mũi Họng, Phòng Siêu âm tim & ECG',
        wings: [
          HospitalWingPlan(
            wingName: 'Khu B',
            rooms: [
              HospitalRoomInfo(
                roomCode: 'Phòng 201',
                name: 'BS. Lê Anh Tuấn (Nội tổng quát)',
                category: 'clinic',
                doctorId: 'dr-tuan',
              ),
              HospitalRoomInfo(
                roomCode: 'Phòng 204',
                name: 'BS. Trần Thảo Linh (Tim mạch)',
                category: 'clinic',
                doctorId: 'dr-linh',
              ),
              HospitalRoomInfo(
                roomCode: 'Phòng 206',
                name: 'Phòng Lấy mẫu máu & Bệnh phẩm',
                category: 'lab',
              ),
              HospitalRoomInfo(
                roomCode: 'Phòng 208',
                name: 'Đo Điện tâm đồ ECG & Siêu âm Tim',
                category: 'lab',
              ),
              HospitalRoomInfo(
                roomCode: 'Phòng 212',
                name: 'BS. Võ Thu Hương (Tai Mũi Họng)',
                category: 'clinic',
                doctorId: 'dr-huong',
              ),
              HospitalRoomInfo(
                roomCode: 'Phòng 215',
                name: 'Nội soi Tai Mũi Họng ống mềm HD',
                category: 'lab',
              ),
            ],
          ),
        ],
      ),
      HospitalFloorPlan(
        floorLevel: 3,
        floorName: 'Tầng 3 (3rd Floor)',
        description: 'Khoa Da liễu, Thần kinh, Răng Hàm Mặt, Chẩn đoán hình ảnh kỹ thuật cao',
        wings: [
          HospitalWingPlan(
            wingName: 'Khu C',
            rooms: [
              HospitalRoomInfo(
                roomCode: 'Phòng 302',
                name: 'BS. Phạm Ngọc Lan (Da liễu)',
                category: 'clinic',
                doctorId: 'dr-lan',
              ),
              HospitalRoomInfo(
                roomCode: 'Phòng 305',
                name: 'Soi da kỹ thuật số & Laser Da liễu',
                category: 'lab',
              ),
              HospitalRoomInfo(
                roomCode: 'Phòng 308',
                name: 'BS. Hoàng Khánh Vy (Răng Hàm Mặt)',
                category: 'clinic',
                doctorId: 'dr-khanh',
              ),
              HospitalRoomInfo(
                roomCode: 'Phòng 309',
                name: 'Chụp Panorama Nha khoa & CT ConeBeam',
                category: 'lab',
              ),
              HospitalRoomInfo(
                roomCode: 'Phòng 310',
                name: 'BS. Đặng Hải Phong (Thần kinh)',
                category: 'clinic',
                doctorId: 'dr-phong',
              ),
              HospitalRoomInfo(
                roomCode: 'Phòng 312',
                name: 'Đo Điện não đồ EEG & Lưu huyết não',
                category: 'lab',
              ),
            ],
          ),
        ],
      ),
    ];
  }
}
