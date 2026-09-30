import 'package:flutter/foundation.dart';

class PatientSession extends ChangeNotifier {
  PatientSession._();
  static final instance = PatientSession._();

  String _name = '';
  String _email = '';
  String _phone = '+84 912 345 678';

  String get name => _name.isEmpty ? 'Patient' : _name;
  String get email => _email;
  String get phone => _phone;

  void update({required String name, required String email, String? phone}) {
    _name = name.trim();
    _email = email.trim();
    if (phone != null) _phone = phone.trim();
    notifyListeners();
  }

  void clear() {
    _name = '';
    _email = '';
    notifyListeners();
  }
}
