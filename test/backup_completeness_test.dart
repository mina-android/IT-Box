import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:itbox/database/app_database.dart';
import 'package:itbox/database/database_helper.dart';
import 'package:itbox/models/laptop.dart';
import 'package:itbox/services/currency_service.dart';
import 'package:itbox/services/ticket_reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Backup & Restore Completeness', () {
    late AppDatabase db;
    late DatabaseHelper helper;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      AppDatabase.testInstance = db;
      helper = DatabaseHelper();
    });

    tearDown(() async {
      await db.close();
      AppDatabase.testInstance = null;
    });

    test('Full export/restore round-trips TicketReminders, CurrencyService in-memory, and triggers Drift watchCounts', () async {
      await CurrencyService().load();
      await CurrencyService().setCurrency('USD');
      await TicketReminderService().load();
      await TicketReminderService().setEnabled(true, sync: false);
      await TicketReminderService().toggleDay(DateTime.sunday, sync: false);
      await TicketReminderService().addTime(const TimeOfDay(hour: 15, minute: 45), sync: false);

      await helper.insertLaptop(const Laptop(
        laptopNumber: 'L-100',
        model: 'ThinkPad X1',
        condition: 'Good',
      ));

      final countsEvents = <Map<String, int>>[];
      final sub = helper.watchCounts().listen(countsEvents.add);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final backupJson = await helper.exportJson(includeVaultBinaries: true);

      // Mutate local state to verify restore overwrites everything cleanly
      await CurrencyService().setCurrency('EGP');
      await TicketReminderService().setEnabled(false, sync: false);
      await TicketReminderService().removeTime('15:45', sync: false);
      await helper.deleteTable('laptops');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await helper.importJson(backupJson);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(CurrencyService().currency, 'USD');
      expect(TicketReminderService().enabled, isTrue);
      expect(TicketReminderService().days, contains(DateTime.sunday));
      expect(TicketReminderService().times, contains('15:45'));
      expect(countsEvents.last['laptops'], 1);

      await sub.cancel();
    });

    test('Secondary org export does not leak default org switch chassis', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_switch_patch_chassis_v1', '[{"id":1,"name":"DefaultSwitch"}]');

      final jsonStr = await helper.exportJson(
        includeVaultBinaries: false,
        organizationId: 'org_secondary_123',
      );
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final exportedPrefs = decoded['prefs'] as Map<String, dynamic>;
      expect(exportedPrefs['custom_switch_patch_chassis_v1'], '');
    });

    test('Selective restore of switch_patch_ports restores chassis JSON even when restorePrefs is false', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        DatabaseHelper.scopedSwitchChassisKey(),
        '[{"id":9,"name":"RestoredSwitch"}]',
      );
      final jsonStr = await helper.exportJson(includeVaultBinaries: false);

      await prefs.setString(DatabaseHelper.scopedSwitchChassisKey(), '');
      await helper.importJsonSelective(
        jsonStr,
        {'switch_patch_ports'},
        restorePrefs: false,
      );

      expect(
        prefs.getString(DatabaseHelper.scopedSwitchChassisKey()),
        '[{"id":9,"name":"RestoredSwitch"}]',
      );
    });

    test('Selective backup of expenses embeds receipt_files and inspectBackupJson counts them', () async {
      final tempFile = File('${Directory.systemTemp.path}/test_receipt_itbox.jpg');
      await tempFile.writeAsBytes([1, 2, 3, 4, 5]);
      addTearDown(() async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });

      await helper.insertMap('expenses', {
        'date': '2026-11-25',
        'item': 'Patch Cable',
        'price': 50.0,
        'details': 'Cat6',
        'receipt_path': tempFile.path,
      });

      final jsonStr = await helper.exportJson(
        selectedTables: {'expenses'},
        includeVaultBinaries: true,
      );
      final summary = await helper.inspectBackupJson(jsonStr);
      expect(summary.isValid, isTrue);
      expect(summary.embeddedReceiptFilesCount, 1);
    });
  });
}
