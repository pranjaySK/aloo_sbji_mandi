/// IST (Indian Standard Time) DateTime utility.
///
/// Ensures all displayed dates/times are in IST (UTC+5:30)
/// regardless of the user's device timezone or browser locale.

import 'package:intl/intl.dart';

/// IST offset: +5 hours 30 minutes
const Duration _istOffset = Duration(hours: 5, minutes: 30);

/// Extension on DateTime to convert to IST
extension ISTDateTime on DateTime {
  /// Convert this DateTime to Indian Standard Time (UTC+5:30).
  ///
  /// If the DateTime is already in UTC, it adds 5:30.
  /// If it's local time, it first converts to UTC then adds 5:30.
  DateTime toIST() {
    final utcTime = isUtc ? this : toUtc();
    return utcTime.add(_istOffset);
  }
}

/// Get current time in IST
DateTime nowIST() {
  return DateTime.now().toUtc().add(_istOffset);
}

/// Format a DateTime in IST with the given pattern.
///
/// Example:
/// ```dart
/// formatIST(someDate, 'dd MMM yyyy, hh:mm a')
/// // => "19 Feb 2026, 03:45 PM"
/// ```
String formatIST(DateTime dateTime, String pattern) {
  final istTime = dateTime.toIST();
  return DateFormat(pattern).format(istTime);
}

/// Format a DateTime in IST with a compact date pattern (dd MMM yyyy).
String formatISTDate(DateTime dateTime) {
  return formatIST(dateTime, 'dd MMM yyyy');
}

/// Format a DateTime in IST with time only (hh:mm a).
String formatISTTime(DateTime dateTime) {
  return formatIST(dateTime, 'hh:mm a');
}

/// Format a DateTime in IST with full date+time (dd MMM yyyy, hh:mm a).
String formatISTDateTime(DateTime dateTime) {
  return formatIST(dateTime, 'dd MMM yyyy, hh:mm a');
}
