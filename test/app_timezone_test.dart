import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/utils/app_timezone.dart';

void main() {
  test('UTC converts to Vietnam wall clock', () {
    final value = AppTimezone.fromUtc(DateTime.utc(2026, 11, 20, 2));
    expect(AppTimezone.date(value), '20/11/2026');
    expect(AppTimezone.time(value), '09:00');
  });
  test('Vietnam wall clock converts to UTC', () {
    final value = AppTimezone.toUtc(DateTime(2026, 11, 20, 9));
    expect(value, DateTime.utc(2026, 11, 20, 2));
  });
  test('UTC conversion crosses Vietnam day boundary', () {
    final value = AppTimezone.fromUtc(DateTime.utc(2026, 11, 20, 20));
    expect(AppTimezone.date(value), '21/11/2026');
    expect(AppTimezone.time(value), '03:00');
  });
  test('formats a 24 hour appointment range', () {
    expect(
      AppTimezone.range(DateTime(2026, 1, 1, 8), DateTime(2026, 1, 1, 8, 30)),
      '08:00 - 08:30',
    );
  });
}
