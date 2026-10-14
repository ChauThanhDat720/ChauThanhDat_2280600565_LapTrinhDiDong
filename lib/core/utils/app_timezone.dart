/// Time rules for Smart Hospital. Vietnam has a fixed UTC+07:00 offset and
/// does not observe daylight saving time, so a dependency is unnecessary.
/// Values returned by [fromUtc] are Vietnam wall-clock values; always format
/// them with this helper and convert them back with [toUtc] before an API call.
abstract final class AppTimezone {
  static const _vietnamOffset = Duration(hours: 7);

  static DateTime fromUtc(DateTime value) => value.toUtc().add(_vietnamOffset);

  static DateTime toUtc(DateTime vietnamWallTime) => DateTime.utc(
    vietnamWallTime.year,
    vietnamWallTime.month,
    vietnamWallTime.day,
    vietnamWallTime.hour - 7,
    vietnamWallTime.minute,
    vietnamWallTime.second,
    vietnamWallTime.millisecond,
    vietnamWallTime.microsecond,
  );

  static DateTime now() => fromUtc(DateTime.now().toUtc());

  static String date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  static String time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  static String range(DateTime start, DateTime end) =>
      '${time(start)} - ${time(end)}';
}
