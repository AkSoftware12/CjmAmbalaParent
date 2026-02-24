import 'package:intl/intl.dart';

class AppDateTimeUtils {
  /// Date → 13-02-2026
  static String date(String? value) {
    if (value == null || value.isEmpty) return "-";
    try {
      final parsed = DateTime.parse(value);
      return DateFormat('dd-MM-yyyy').format(parsed);
    } catch (_) {
      return value;
    }
  }

  /// Time → 10:30 AM
  static String time(String? value) {
    if (value == null || value.isEmpty) return "-";
    try {
      final parsed = DateTime.parse(value);
      return DateFormat('hh:mm a').format(parsed);
    } catch (_) {
      return value;
    }
  }
}
