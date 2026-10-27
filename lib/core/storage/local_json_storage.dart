import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Serializes read/modify/write operations, including across repository instances.
abstract final class LocalJsonStorage {
  static final Map<String, Future<void>> _writes = {};

  static Future<T> exclusive<T>(String key, Future<T> Function() action) {
    final previous = _writes[key] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _writes[key] = settled;
    settled.then((_) {
      if (identical(_writes[key], settled)) _writes.remove(key);
    });
    return result;
  }

  static Future<List<Map<String, dynamic>>?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(key);
    if (value == null) return null;
    // A damaged cache must surface as an error, rather than overwrite saved data.
    return (jsonDecode(value) as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> write(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(key, jsonEncode(items))) {
      throw StateError(
        'Không thể lưu dữ liệu trên thiết bị. Vui lòng thử lại.',
      );
    }
  }
}
