import 'package:flutter/material.dart';

class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.departmentId,
    required this.department,
    required this.specialty,
    required this.experience,
    required this.color,
  });

  final String id;
  final String name;
  final String departmentId;
  final String department;
  final String specialty;
  final String experience;
  final Color color;
}

const doctors = [
  Doctor(
    id: 'dr-linh',
    name: 'BS. Trần Thảo Linh',
    departmentId: 'cardiology',
    department: 'Tim mạch',
    specialty: 'Bác sĩ tim mạch',
    experience: '12 năm kinh nghiệm',
    color: Color(0xFFBDE5E9),
  ),
  Doctor(
    id: 'dr-duc',
    name: 'BS. Nguyễn Đức Minh',
    departmentId: 'pediatrics',
    department: 'Nhi khoa',
    specialty: 'Bác sĩ nhi khoa',
    experience: '9 năm kinh nghiệm',
    color: Color(0xFFFFDCC0),
  ),
  Doctor(
    id: 'dr-lan',
    name: 'BS. Phạm Ngọc Lan',
    departmentId: 'dermatology',
    department: 'Da liễu',
    specialty: 'Bác sĩ da liễu',
    experience: '10 năm kinh nghiệm',
    color: Color(0xFFE5D6FA),
  ),
  Doctor(
    id: 'dr-tuan',
    name: 'BS. Lê Anh Tuấn',
    departmentId: 'general-medicine',
    department: 'Nội tổng quát',
    specialty: 'Bác sĩ nội tổng quát',
    experience: '15 năm kinh nghiệm',
    color: Color(0xFFD4EDC7),
  ),
  Doctor(
    id: 'dr-huong',
    name: 'BS. Võ Thu Hương',
    departmentId: 'ent',
    department: 'Tai Mũi Họng',
    specialty: 'Bác sĩ tai mũi họng',
    experience: '8 năm kinh nghiệm',
    color: Color(0xFFF8D6DF),
  ),
  Doctor(
    id: 'dr-phong',
    name: 'BS. Đặng Hải Phong',
    departmentId: 'neurology',
    department: 'Thần kinh',
    specialty: 'Bác sĩ thần kinh',
    experience: '11 năm kinh nghiệm',
    color: Color(0xFFD4DEFA),
  ),
  Doctor(
    id: 'dr-mai',
    name: 'BS. Bùi Thanh Mai',
    departmentId: 'orthopedics',
    department: 'Chấn thương chỉnh hình',
    specialty: 'Bác sĩ cơ xương khớp',
    experience: '10 năm kinh nghiệm',
    color: Color(0xFFF9E3BE),
  ),
  Doctor(
    id: 'dr-khanh',
    name: 'BS. Hoàng Khánh Vy',
    departmentId: 'dentistry',
    department: 'Răng Hàm Mặt',
    specialty: 'Bác sĩ nha khoa',
    experience: '7 năm kinh nghiệm',
    color: Color(0xFFD1EFE8),
  ),
];
