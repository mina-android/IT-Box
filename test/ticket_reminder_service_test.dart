import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:itbox/services/notification_service.dart';
import 'package:itbox/services/ticket_reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TicketReminderService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads default weekdays (Mon-Fri) and 09:00 disabled by default', () async {
      final svc = TicketReminderService();
      await svc.load();

      expect(svc.enabled, isFalse);
      expect(svc.days, equals([1, 2, 3, 4, 5]));
      expect(svc.times, equals(['09:00']));
    });

    test('toggleDay adds, sorts, and removes weekdays and persists', () async {
      final svc = TicketReminderService();
      await svc.load();

      await svc.toggleDay(DateTime.sunday, sync: false);
      expect(svc.days, contains(DateTime.sunday));

      await svc.toggleDay(DateTime.monday, sync: false);
      expect(svc.days, isNot(contains(DateTime.monday)));

      // Re-load from SharedPreferences to verify persistence
      await svc.load();
      expect(svc.days, equals([2, 3, 4, 5, 7]));
    });

    test('addTime sorts chronologically, deduplicates, and removeTime deletes', () async {
      final svc = TicketReminderService();
      await svc.load();

      final added1 = await svc.addTime(const TimeOfDay(hour: 16, minute: 30), sync: false);
      final added2 = await svc.addTime(const TimeOfDay(hour: 7, minute: 15), sync: false);
      final dup = await svc.addTime(const TimeOfDay(hour: 9, minute: 0), sync: false);

      expect(added1, isTrue);
      expect(added2, isTrue);
      expect(dup, isFalse);
      expect(svc.times, equals(['07:15', '09:00', '16:30']));

      await svc.removeTime('09:00', sync: false);
      expect(svc.times, equals(['07:15', '16:30']));
    });

    test('setEnabled persists toggle state', () async {
      final svc = TicketReminderService();
      await svc.load();

      await svc.setEnabled(true, sync: false);
      expect(svc.enabled, isTrue);

      await svc.load();
      expect(svc.enabled, isTrue);
    });
  });

  group('NotificationService.nextWeeklyOccurrence', () {
    test('schedules later today when target time is in the future', () {
      // 2026-11-25 is a Wednesday (weekday == 3)
      final now = DateTime(2026, 11, 25, 8, 0);
      final next = NotificationService().nextWeeklyOccurrence(DateTime.wednesday, 9, 30, now);
      final expectedUtc = DateTime(2026, 11, 25, 9, 30).toUtc();

      expect(next.year, expectedUtc.year);
      expect(next.month, expectedUtc.month);
      expect(next.day, expectedUtc.day);
      expect(next.hour, expectedUtc.hour);
      expect(next.minute, expectedUtc.minute);
    });

    test('rolls to next week when target time today has already passed', () {
      final now = DateTime(2026, 11, 25, 10, 0);
      final next = NotificationService().nextWeeklyOccurrence(DateTime.wednesday, 9, 30, now);
      final expectedUtc = DateTime(2026, 12, 2, 9, 30).toUtc();

      expect(next.year, expectedUtc.year);
      expect(next.month, expectedUtc.month);
      expect(next.day, expectedUtc.day);
      expect(next.hour, expectedUtc.hour);
      expect(next.minute, expectedUtc.minute);
    });

    test('wraps across week boundary to upcoming Sunday', () {
      // 2026-11-25 (Wed) -> 2026-11-29 (Sun)
      final now = DateTime(2026, 11, 25, 10, 0);
      final next = NotificationService().nextWeeklyOccurrence(DateTime.sunday, 14, 15, now);
      final expectedUtc = DateTime(2026, 11, 29, 14, 15).toUtc();

      expect(next.year, expectedUtc.year);
      expect(next.month, expectedUtc.month);
      expect(next.day, expectedUtc.day);
      expect(next.hour, expectedUtc.hour);
      expect(next.minute, expectedUtc.minute);
    });
  });
}
