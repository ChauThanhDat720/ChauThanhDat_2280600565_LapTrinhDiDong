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

  String _name = '';
  String _email = '';
  String _phone = '';
  String _dateOfBirth = '';
  String _gender = '';
  String _address = '';

  String get name => _name.isEmpty ? 'Patient' : _name;
  String get email => _email;
  String get phone => _phone;
  String get dateOfBirth => _dateOfBirth;
  String get gender => _gender;
  String get address => _address;
  bool get isLoggedIn => _email.isNotEmpty;

  Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    _name = preferences.getString(_nameKey) ?? '';
    _email = preferences.getString(_emailKey) ?? '';
    _phone = preferences.getString(_phoneKey) ?? '';
    _dateOfBirth = preferences.getString(_dobKey) ?? '';
    _gender = preferences.getString(_genderKey) ?? '';
    _address = preferences.getString(_addressKey) ?? '';
    notifyListeners();
  }

  Future<void> update({
    required String name,
    required String email,
    required String phone,
    required String dateOfBirth,
    required String gender,
    required String address,
  }) async {
    _name = name.trim();
    _email = email.trim();
    _phone = phone.trim();
    _dateOfBirth = dateOfBirth.trim();
    _gender = gender.trim();
    _address = address.trim();
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_nameKey, _name),
      preferences.setString(_emailKey, _email),
      preferences.setString(_phoneKey, _phone),
      preferences.setString(_dobKey, _dateOfBirth),
      preferences.setString(_genderKey, _gender),
      preferences.setString(_addressKey, _address),
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
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_nameKey),
      preferences.remove(_emailKey),
      preferences.remove(_phoneKey),
      preferences.remove(_dobKey),
      preferences.remove(_genderKey),
      preferences.remove(_addressKey),
    ]);
    notifyListeners();
  }
}
