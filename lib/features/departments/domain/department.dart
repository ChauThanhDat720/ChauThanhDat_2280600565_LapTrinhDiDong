class Department {
  const Department({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.doctorCount,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final int doctorCount;
}

const departments = <Department>[
  Department(
    id: 'cardiology',
    name: 'Tim mạch',
    description: 'Chăm sóc tim và hệ tim mạch.',
    icon: '❤️',
    doctorCount: 12,
  ),

  Department(
    id: 'pediatrics',
    name: 'Nhi khoa',
    description: 'Chăm sóc sức khỏe cho trẻ em và trẻ sơ sinh.',
    icon: '👶',
    doctorCount: 9,
  ),

  Department(
    id: 'dermatology',
    name: 'Da liễu',
    description: 'Chăm sóc da, tóc và móng.',
    icon: '🧴',
    doctorCount: 7,
  ),

  Department(
    id: 'ent',
    name: 'Tai Mũi Họng',
    description: 'Khám và điều trị tai, mũi và họng.',
    icon: '👂',
    doctorCount: 8,
  ),

  Department(
    id: 'neurology',
    name: 'Thần kinh',
    description: 'Chẩn đoán và điều trị các bệnh về hệ thần kinh.',
    icon: '🧠',
    doctorCount: 6,
  ),

  Department(
    id: 'orthopedics',
    name: 'Chấn thương chỉnh hình',
    description: 'Chăm sóc xương, khớp, cơ và vận động.',
    icon: '🦴',
    doctorCount: 10,
  ),

  Department(
    id: 'general-medicine',
    name: 'Nội tổng quát',
    description: 'Khám tổng quát và tư vấn chăm sóc sức khỏe.',
    icon: '🩺',
    doctorCount: 15,
  ),

  Department(
    id: 'dentistry',
    name: 'Răng Hàm Mặt',
    description: 'Chăm sóc, phòng ngừa và điều trị các bệnh răng miệng.',
    icon: '🦷',
    doctorCount: 5,
  ),
];
