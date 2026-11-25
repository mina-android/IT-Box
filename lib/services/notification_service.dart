import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/borrow_log.dart';
import 'company_service.dart';
import 'ticket_reminder_service.dart';

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  static const String ticketReminderPayload = 'ticket_reminder';
  static const String _scheduledTicketIdsKey = 'scheduled_ticket_reminder_ids';
  static const int _ticketIdBase = 0x60000000;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  void Function(String? payload)? _onNotificationTap;
  bool get isInitialized => _initialized;

  Future<void> init({void Function(String? payload)? onNotificationTap}) async {
    if (onNotificationTap != null) {
      _onNotificationTap = onNotificationTap;
    }
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      AndroidInitializationSettings? androidInit;
      LinuxInitializationSettings? linuxInit;

      if (Platform.isAndroid) {
        androidInit = const AndroidInitializationSettings('@drawable/ic_stat_mono');
      } else if (Platform.isLinux) {
        linuxInit = const LinuxInitializationSettings(defaultActionName: 'Open');
      }

      final initSettings = InitializationSettings(
        android: androidInit,
        linux: linuxInit,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _onNotificationTap?.call(response.payload);
        },
      );
      _initialized = true;
    } catch (e) {
      if (kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
        print('NotificationService init error: $e');
      }
    }
  }

  Future<String?> getLaunchNotificationPayload() async {
    await init();
    if (!_initialized) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        return details.notificationResponse?.payload;
      }
    } catch (_) {}
    return null;
  }

  Future<bool?> requestPermission() async {
    await init();
    if (!_initialized) return null;
    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidImpl?.requestNotificationsPermission();
    }
    return null;
  }

  int _scopedNotificationId(int borrowId) {
    final orgPrefix = CompanyService().activeOrganizationId.hashCode & 0x7FFF;
    return (orgPrefix << 16) ^ (borrowId & 0xFFFF);
  }

  Future<bool> scheduleOverdueReminder({
    required int borrowId,
    required String deviceName,
    required String employeeName,
    required DateTime dueDate,
    required TimeOfDay reminderTime,
    bool skipPermissionRequest = false,
  }) async {
    tz.TZDateTime? tzDate = toUtcTZDate(dueDate, reminderTime.hour, reminderTime.minute);
    
    // C10: If target instant has already passed today, schedule immediate notification 1 minute out
    if (tzDate == null) {
      final now = DateTime.now();
      final isDueToday = dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day;
      if (isDueToday) {
        final oneMinOut = now.add(const Duration(minutes: 1));
        tzDate = toUtcTZDate(oneMinOut, oneMinOut.hour, oneMinOut.minute);
      }
    }
    if (tzDate == null) {
      return false;
    }

    await init();
    if (!_initialized) {
      return false;
    }
    if (!skipPermissionRequest) {
      await requestPermission();
    }
    try {
      const androidDetails = AndroidNotificationDetails(
        'overdue_channel',
        'Overdue Borrow Reminders',
        channelDescription: 'Notifications for borrowed devices passing their due date',
        importance: Importance.high,
        priority: Priority.high,
      );

      final dateFormatted = '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
      await _plugin.zonedSchedule(
        id: _scopedNotificationId(borrowId),
        title: 'Due today: $deviceName',
        body: '$employeeName is scheduled to return $deviceName (Due: $dateFormatted)',
        scheduledDate: tzDate,
        notificationDetails: const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling reminder: $e');
      }
      return false;
    }
  }

  tz.TZDateTime? toUtcTZDate(DateTime date, int hour, int minute, [DateTime? nowReference]) {
    try {
      tz_data.initializeTimeZones();
    } catch (_) {}
    // Dart DateTime constructor applies correct DST and timezone rules for the target date
    final local = DateTime(date.year, date.month, date.day, hour, minute);
    final utc = local.toUtc();
    final tzDate = tz.TZDateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute);
    final ref = nowReference != null
        ? tz.TZDateTime.from(nowReference.toUtc(), tz.UTC)
        : tz.TZDateTime.now(tz.UTC);
    if (tzDate.isBefore(ref)) return null;
    return tzDate;
  }

  Future<void> reconcileReminders(List<BorrowLog> logs) async {
    await init();
    if (!_initialized) {
      return;
    }
    try {
      await requestPermission();
      await _plugin.cancelAll();
      for (final log in logs) {
        if (!log.isReturned && log.dueDate != null && log.dueDate!.isNotEmpty && log.id != null) {
          final due = DateTime.tryParse(log.dueDate!);
          if (due != null) {
            TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0);
            if (log.reminderTime != null && log.reminderTime!.isNotEmpty) {
              final parts = log.reminderTime!.split(':');
              if (parts.length == 2) {
                reminderTime = TimeOfDay(
                  hour: int.tryParse(parts[0]) ?? 9,
                  minute: int.tryParse(parts[1]) ?? 0,
                );
              }
            }
            await scheduleOverdueReminder(
              borrowId: log.id!,
              deviceName: log.deviceName,
              employeeName: log.employeeName,
              dueDate: due,
              reminderTime: reminderTime,
              skipPermissionRequest: true,
            );
          }
        }
      }
      await TicketReminderService().syncNotifications();
    } catch (e) {
      if (kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
        print('Error reconciling reminders: $e');
      }
    }
  }

  /// Computes the next local wall-clock occurrence for [weekday] (`1 = Mon`..`7 = Sun`)
  /// and [hour]:[minute], returning a UTC [tz.TZDateTime] suitable for `zonedSchedule`.
  tz.TZDateTime nextWeeklyOccurrence(
    int weekday,
    int hour,
    int minute, [
    DateTime? nowReference,
  ]) {
    try {
      tz_data.initializeTimeZones();
    } catch (_) {}
    final now = nowReference ?? DateTime.now();
    var daysUntil = (weekday - now.weekday) % 7;
    var candidate = DateTime(now.year, now.month, now.day, hour, minute)
        .add(Duration(days: daysUntil));
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    final utc = candidate.toUtc();
    return tz.TZDateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute);
  }

  Future<void> cancelTicketReminders() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_scheduledTicketIdsKey) ?? const [];
    if (_initialized) {
      for (final rawId in existing) {
        final id = int.tryParse(rawId);
        if (id != null) {
          try {
            await _plugin.cancel(id: id);
          } catch (_) {}
        }
      }
    }
    await prefs.remove(_scheduledTicketIdsKey);
  }

  Future<void> syncTicketReminders({
    required bool enabled,
    required List<int> days,
    required List<String> times,
  }) async {
    await cancelTicketReminders();
    if (!enabled || days.isEmpty || times.isEmpty) {
      return;
    }
    await init();
    if (!_initialized) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'ticket_reminders_channel',
      'Ticket Logging Reminders',
      channelDescription: 'Scheduled reminders to log IT support tickets',
      importance: Importance.high,
      priority: Priority.high,
    );

    final scheduledIds = <String>[];
    for (final weekday in days) {
      if (weekday < DateTime.monday || weekday > DateTime.sunday) {
        continue;
      }
      for (int i = 0; i < times.length; i++) {
        final parsed = TicketReminderService.parseTime(times[i]);
        if (parsed == null) {
          continue;
        }
        final id = _ticketIdBase + (weekday * 1000) + i;
        final scheduledDate = nextWeeklyOccurrence(weekday, parsed.hour, parsed.minute);
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: 'Time to Log IT Tickets',
            body: 'Tap to record any open or resolved IT support tickets.',
            scheduledDate: scheduledDate,
            notificationDetails: const NotificationDetails(android: androidDetails),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: ticketReminderPayload,
          );
          scheduledIds.add(id.toString());
        } catch (e) {
          if (kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
            print('Error scheduling ticket reminder ($id): $e');
          }
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_scheduledTicketIdsKey, scheduledIds);
  }

  Future<void> cancelReminder(int borrowId) async {
    await init();
    if (!_initialized) {
      return;
    }
    try {
      await _plugin.cancel(id: _scopedNotificationId(borrowId));
    } catch (e) {
      if (kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
        print('Error canceling reminder: $e');
      }
    }
  }
}
