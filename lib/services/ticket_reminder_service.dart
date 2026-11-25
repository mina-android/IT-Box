import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// Persists and coordinates recurring Ticket Logging Reminder schedules.
///
/// Users choose active weekdays (`1 = Mon` .. `7 = Sun`) and any number of
/// shared clock times (`"HH:mm"` 24-hour strings). Each `(weekday, time)` pair
/// is scheduled as a weekly recurring local notification whose tap opens the
/// New Ticket form directly.
class TicketReminderService extends ChangeNotifier {
  static final TicketReminderService _i = TicketReminderService._();
  factory TicketReminderService() => _i;
  TicketReminderService._();

  static const _kEnabledKey = 'ticket_reminders_enabled';
  static const _kDaysKey = 'ticket_reminders_days';
  static const _kTimesKey = 'ticket_reminders_times';

  static const List<int> defaultDays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];
  static const List<String> defaultTimes = ['09:00'];

  bool _enabled = false;
  List<int> _days = List.from(defaultDays);
  List<String> _times = List.from(defaultTimes);
  bool _loaded = false;

  bool get enabled => _enabled;
  List<int> get days => List.unmodifiable(_days);
  List<String> get times => List.unmodifiable(_times);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabledKey) ?? false;

    final rawDays = prefs.getStringList(_kDaysKey);
    if (rawDays != null) {
      final parsed = rawDays
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
          .toSet()
          .toList()
        ..sort();
      _days = parsed;
    } else {
      _days = List.from(defaultDays);
    }

    final rawTimes = prefs.getStringList(_kTimesKey);
    if (rawTimes != null) {
      _times = _normalizeTimes(rawTimes);
    } else {
      _times = List.from(defaultTimes);
    }

    _loaded = true;
    notifyListeners();
  }

  static List<String> _normalizeTimes(Iterable<String> raw) {
    final valid = <String>{};
    for (final t in raw) {
      final parts = t.split(':');
      if (parts.length != 2) {
        continue;
      }
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        valid.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
      }
    }
    final list = valid.toList()..sort();
    return list;
  }

  static String formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay? parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) {
      return null;
    }
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, _enabled);
    await prefs.setStringList(_kDaysKey, _days.map((d) => d.toString()).toList());
    await prefs.setStringList(_kTimesKey, _times);
  }

  Future<void> setEnabled(bool value, {bool sync = true}) async {
    _enabled = value;
    await _persist();
    notifyListeners();
    if (sync) {
      if (value) {
        await NotificationService().requestPermission();
      }
      await syncNotifications();
    }
  }

  Future<void> toggleDay(int weekday, {bool sync = true}) async {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      return;
    }
    if (_days.contains(weekday)) {
      _days.remove(weekday);
    } else {
      _days.add(weekday);
      _days.sort();
    }
    await _persist();
    notifyListeners();
    if (sync) {
      await syncNotifications();
    }
  }

  Future<bool> addTime(TimeOfDay time, {bool sync = true}) async {
    final formatted = formatTimeOfDay(time);
    if (_times.contains(formatted)) {
      return false;
    }
    _times = _normalizeTimes([..._times, formatted]);
    await _persist();
    notifyListeners();
    if (sync) {
      await syncNotifications();
    }
    return true;
  }

  Future<void> removeTime(String hhmm, {bool sync = true}) async {
    _times.remove(hhmm);
    await _persist();
    notifyListeners();
    if (sync) {
      await syncNotifications();
    }
  }

  Future<void> syncNotifications() async {
    await NotificationService().syncTicketReminders(
      enabled: _enabled,
      days: _days,
      times: _times,
    );
  }
}
