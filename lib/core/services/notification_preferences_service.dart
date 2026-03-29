import 'package:shared_preferences/shared_preferences.dart';

/// User-configurable notification preferences (quiet hours, grouping, etc.).
class NotificationPreferencesService {
  NotificationPreferencesService._(this._prefs);

  static const String _keyPushEnabled = 'notif_push_enabled';
  static const String _keyGroupingEnabled = 'notif_grouping_enabled';
  static const String _keyQuietHoursEnabled = 'notif_quiet_hours_enabled';
  static const String _keyQuietStartHour = 'notif_quiet_start_hour';
  static const String _keyQuietStartMinute = 'notif_quiet_start_minute';
  static const String _keyQuietEndHour = 'notif_quiet_end_hour';
  static const String _keyQuietEndMinute = 'notif_quiet_end_minute';

  static NotificationPreferencesService? _instance;
  final SharedPreferences _prefs;

  static Future<NotificationPreferencesService> init() async {
    _instance ??= NotificationPreferencesService._(
      await SharedPreferences.getInstance(),
    );
    return _instance!;
  }

  bool get pushEnabled => _prefs.getBool(_keyPushEnabled) ?? true;
  bool get groupingEnabled => _prefs.getBool(_keyGroupingEnabled) ?? true;
  bool get quietHoursEnabled => _prefs.getBool(_keyQuietHoursEnabled) ?? false;

  int get quietStartHour => _prefs.getInt(_keyQuietStartHour) ?? 22;
  int get quietStartMinute => _prefs.getInt(_keyQuietStartMinute) ?? 0;
  int get quietEndHour => _prefs.getInt(_keyQuietEndHour) ?? 7;
  int get quietEndMinute => _prefs.getInt(_keyQuietEndMinute) ?? 0;

  Future<void> setPushEnabled(bool value) async {
    await _prefs.setBool(_keyPushEnabled, value);
  }

  Future<void> setGroupingEnabled(bool value) async {
    await _prefs.setBool(_keyGroupingEnabled, value);
  }

  Future<void> setQuietHoursEnabled(bool value) async {
    await _prefs.setBool(_keyQuietHoursEnabled, value);
  }

  Future<void> setQuietStart(TimeOfDayLite value) async {
    await _prefs.setInt(_keyQuietStartHour, value.hour);
    await _prefs.setInt(_keyQuietStartMinute, value.minute);
  }

  Future<void> setQuietEnd(TimeOfDayLite value) async {
    await _prefs.setInt(_keyQuietEndHour, value.hour);
    await _prefs.setInt(_keyQuietEndMinute, value.minute);
  }

  bool isInQuietHours(DateTime now) {
    if (!quietHoursEnabled) return false;
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = quietStartHour * 60 + quietStartMinute;
    final endMinutes = quietEndHour * 60 + quietEndMinute;

    // Same start/end means always silent when quiet-hours enabled.
    if (startMinutes == endMinutes) return true;

    // Regular interval (e.g., 10:00 -> 18:00)
    if (startMinutes < endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }

    // Overnight interval (e.g., 22:00 -> 07:00)
    return currentMinutes >= startMinutes || currentMinutes < endMinutes;
  }

  String quietHoursLabel() {
    final start = _formatTime(quietStartHour, quietStartMinute);
    final end = _formatTime(quietEndHour, quietEndMinute);
    return '$start - $end';
  }

  String _formatTime(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

/// Lightweight time struct to avoid importing Material into core logic.
class TimeOfDayLite {
  final int hour;
  final int minute;

  const TimeOfDayLite({required this.hour, required this.minute});

  @override
  String toString() => 'TimeOfDayLite(hour: $hour, minute: $minute)';
}
