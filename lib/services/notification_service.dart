import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/borrow_log.dart';

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init() async {
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

      await _plugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (e) {
      if (kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
        print('NotificationService init error: $e');
      }
    }
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

  Future<bool> scheduleOverdueReminder({
    required int borrowId,
    required String deviceName,
    required String employeeName,
    required DateTime dueDate,
    required TimeOfDay reminderTime,
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
    if (tzDate == null) return false;

    await init();
    if (!_initialized) return false;
    await requestPermission();
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
        id: borrowId,
        title: 'Due today: $deviceName',
        body: '$employeeName is scheduled to return $deviceName (Due: $dateFormatted)',
        scheduledDate: tzDate,
        notificationDetails: const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (e) {
      if (kDebugMode) print('Error scheduling reminder: $e');
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
    if (!_initialized) return;
    try {
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
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
        print('Error reconciling reminders: $e');
      }
    }
  }

  Future<void> cancelReminder(int borrowId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: borrowId);
    } catch (e) {
      if (kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
        print('Error canceling reminder: $e');
      }
    }
  }
}
