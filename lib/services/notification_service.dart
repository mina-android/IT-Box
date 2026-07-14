import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const winInit = LinuxInitializationSettings(defaultActionName: 'Open');
      const initSettings = InitializationSettings(
        android: androidInit,
        linux: winInit,
      );

      await _plugin.initialize(settings: initSettings);

      if (Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.requestNotificationsPermission();
      }
      _initialized = true;
    } catch (e) {
      if (kDebugMode) print('NotificationService init error: $e');
    }
  }

  Future<void> scheduleOverdueReminder({
    required int borrowId,
    required String deviceName,
    required String employeeName,
    required DateTime dueDate,
  }) async {
    await init();
    try {
      // Schedule for 9:00 AM on due date, or +10 seconds if due date is today or already passed
      var scheduledDate = tz.TZDateTime(
        tz.local,
        dueDate.year,
        dueDate.month,
        dueDate.day,
        9,
        0,
      );

      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
      }

      const androidDetails = AndroidNotificationDetails(
        'overdue_channel',
        'Overdue Borrow Reminders',
        channelDescription: 'Notifications for borrowed devices passing their due date',
        importance: Importance.high,
        priority: Priority.high,
      );

      await _plugin.zonedSchedule(
        id: borrowId,
        title: 'Device Overdue: $deviceName',
        body: '$employeeName has not returned $deviceName (Due: ${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')})',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) print('Error scheduling reminder: $e');
    }
  }

  Future<void> cancelReminder(int borrowId) async {
    try {
      await _plugin.cancel(id: borrowId);
    } catch (e) {
      if (kDebugMode) print('Error canceling reminder: $e');
    }
  }
}
