import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../domain/doctor.dart';

abstract interface class DoctorRepository {
  Future<List<Doctor>> getDoctors();
  Future<Doctor?> getDoctorById(String id);
}

class LocalDoctorRepository implements DoctorRepository {
  const LocalDoctorRepository();

  @override
  Future<List<Doctor>> getDoctors() async => doctors;

  @override
  Future<Doctor?> getDoctorById(String id) async {
    for (final doctor in doctors) {
      if (doctor.id == id) return doctor;
    }
    return null;
  }
}

class RemoteDoctorRepository implements DoctorRepository {
  const RemoteDoctorRepository(this._client);
  final ApiClient _client;

  @override
  Future<List<Doctor>> getDoctors() async {
    final result = await _client.get('/doctors');
    final items = result is Map<String, dynamic> ? result['items'] : result;
    if (items is! List) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(_doctorFromJson)
        .toList(growable: false);
  }

  @override
  Future<Doctor?> getDoctorById(String id) async {
    final result = await _client.get('/doctors/$id');
    return result is Map<String, dynamic> ? _doctorFromJson(result) : null;
  }

  Doctor _doctorFromJson(Map<String, dynamic> json) => Doctor(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    departmentId: json['departmentId'] as String? ?? '',
    department: json['department'] as String? ?? '',
    specialty: json['specialty'] as String? ?? '',
    experience: json['experience'] as String? ?? '',
    color: const Color(0xFFBDE5E9),
  );
}
