import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:itbox/database/app_database.dart';
import 'package:itbox/database/database_helper.dart';
import 'package:itbox/models/borrow_log.dart';
import 'package:itbox/models/electronic.dart';
import 'package:itbox/models/employee.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BorrowLog Notes & Schema v17', () {
    test('BorrowLog model round-trips notes via toMap, fromMap, and copyWith', () {
      const log = BorrowLog(
        id: 7,
        deviceType: 'electronic',
        deviceId: 2,
        deviceName: 'USB-C Hub',
        deviceNumber: 'E-02',
        employeeId: 4,
        employeeName: 'Sara',
        reason: 'Conference',
        notes: 'Includes HDMI adapter',
        outDate: '2026-11-25',
      );

      final mapped = log.toMap();
      expect(mapped['notes'], 'Includes HDMI adapter');

      final restored = BorrowLog.fromMap(mapped);
      expect(restored.notes, 'Includes HDMI adapter');

      final updated = restored.copyWith(notes: 'Returned with case');
      expect(updated.notes, 'Returned with case');
    });

    test('DatabaseHelper persists and retrieves borrow_logs.notes on Schema v17', () async {
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase(NativeDatabase.memory());
      AppDatabase.testInstance = db;
      final helper = DatabaseHelper();

      final empId = await helper.insertEmployee(const Employee(name: 'Omar', phoneNumber: '0100'));
      final elId = await helper.insertElectronic(const Electronic(
        deviceNumber: 'E-99',
        deviceName: 'Projector',
        details: '4K',
      ));

      final logId = await helper.insertBorrowLog(BorrowLog(
        deviceType: 'electronic',
        deviceId: elId,
        deviceName: 'Projector',
        deviceNumber: 'E-99',
        employeeId: empId,
        employeeName: 'Omar',
        reason: 'Boardroom presentation',
        notes: 'Includes remote & power cable',
        outDate: '2026-11-25',
      ));

      final logs = await helper.getBorrowLogs();
      final saved = logs.firstWhere((l) => l.id == logId);
      expect(saved.notes, 'Includes remote & power cable');

      await helper.updateBorrowLog(
        logId,
        saved.copyWith(notes: 'Updated note: HDMI cable added'),
      );
      final updatedLogs = await helper.getBorrowLogs();
      expect(
        updatedLogs.firstWhere((l) => l.id == logId).notes,
        'Updated note: HDMI cable added',
      );

      await db.close();
      AppDatabase.testInstance = null;
    });
  });
}
