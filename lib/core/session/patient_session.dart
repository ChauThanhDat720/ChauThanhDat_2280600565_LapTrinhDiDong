import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local profile cache used until the Cognito/API account service is connected.
/// Passwords and medical data are never written here.
class PatientSession extends ChangeNotifier {
  PatientSession._();
  static final instance = PatientSession._();

  static const _nameKey = 'patient_name';
  static const _emailKey = 'patient_email';
  static const _phoneKey = 'patient_phone';
  static const _dobKey = 'patient_dob';
  static const _genderKey = 'patient_gender';
  static const _addressKey = 'patient_address';
  static const _emergencyNameKey = 'patient_emergency_name';
  static const _emergencyPhoneKey = 'patient_emergency_phone';

  String _name = '';
  String _email = '';
  String _phone = '';
  String _dateOfBirth = '';
  String _gender = '';
  String _address = '';
  String _emergencyContactName = '';
  String _emergencyContactPhone = '';

  String get name => _name.isEmpty ? 'Patient' : _name;
  String get email => _email;
  String get phone => _phone;
  String get dateOfBirth => _dateOfBirth;
  String get gender => _gender;
  String get address => _address;
  String get emergencyContactName => _emergencyContactName;
  String get emergencyContactPhone => _emergencyContactPhone;
  bool get isLoggedIn => _email.isNotEmpty;

  Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    _name = preferences.getString(_nameKey) ?? '';
    _email = preferences.getString(_emailKey) ?? '';
    _phone = preferences.getString(_phoneKey) ?? '';
    _dateOfBirth = preferences.getString(_dobKey) ?? '';
    _gender = preferences.getString(_genderKey) ?? '';
    _address = preferences.getString(_addressKey) ?? '';
    _emergencyContactName = preferences.getString(_emergencyNameKey) ?? '';
    _emergencyContactPhone = preferences.getString(_emergencyPhoneKey) ?? '';
    notifyListeners();
  }

  Future<void> update({
    required String name,
    required String email,
    required String phone,
    required String dateOfBirth,
    required String gender,
    required String address,
    String emergencyContactName = '',
    String emergencyContactPhone = '',
  }) async {
    _name = name.trim();
    _email = email.trim();
    _phone = phone.trim();
    _dateOfBirth = dateOfBirth.trim();
    _gender = gender.trim();
    _address = address.trim();
    _emergencyContactName = emergencyContactName.trim();
    _emergencyContactPhone = emergencyContactPhone.trim();
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_nameKey, _name),
      preferences.setString(_emailKey, _email),
      preferences.setString(_phoneKey, _phone),
      preferences.setString(_dobKey, _dateOfBirth),
      preferences.setString(_genderKey, _gender),
      preferences.setString(_addressKey, _address),
      preferences.setString(_emergencyNameKey, _emergencyContactName),
      preferences.setString(_emergencyPhoneKey, _emergencyContactPhone),
    ]);
    notifyListeners();
  }

  Future<void> signIn({required String name, required String email}) async {
    _name = name.trim();
    _email = email.trim();
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_nameKey, _name),
      preferences.setString(_emailKey, _email),
    ]);
    notifyListeners();
  }

  Future<void> clear() async {
    _name = '';
    _email = '';
    _phone = '';
    _dateOfBirth = '';
    _gender = '';
    _address = '';
    _emergencyContactName = '';
    _emergencyContactPhone = '';
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_nameKey),
      preferences.remove(_emailKey),
      preferences.remove(_phoneKey),
      preferences.remove(_dobKey),
      preferences.remove(_genderKey),
      preferences.remove(_addressKey),
      preferences.remove(_emergencyNameKey),
      preferences.remove(_emergencyPhoneKey),
    ]);
    notifyListeners();
  }
}
