import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:itbox/database/app_database.dart';
import 'package:itbox/database/database_helper.dart';
import 'package:itbox/models/borrow_log.dart';
import 'package:itbox/models/electronic.dart';
import 'package:itbox/models/employee.dart';
import 'package:itbox/models/expense.dart';
import 'package:itbox/models/mifi.dart';
import 'package:itbox/models/email_account.dart';
import 'package:itbox/models/log_entry.dart';
import 'package:itbox/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BorrowLog isOverdue Logic', () {
    test('Calculates overdue status accurately based on reference date', () {
      const log = BorrowLog(
        id: 1,
        employeeId: 1,
        employeeName: 'Ahmed Ali',
        deviceName: 'Barcode Scanner',
        deviceType: 'Electronic',
        deviceId: 10,
        deviceNumber: 'E-01',
        reason: 'Audit',
        outDate: '2026-05-01',
        dueDate: '2026-05-10',
        isReturned: false,
      );

      // Before due date
      expect(log.isOverdue(DateTime(2026, 5, 9)), false);
      // On due date
      expect(log.isOverdue(DateTime(2026, 5, 10)), false);
      // After due date
      expect(log.isOverdue(DateTime(2026, 5, 11)), true);

      // Returned log is never overdue
      const returnedLog = BorrowLog(
        id: 2,
        employeeId: 1,
        employeeName: 'Ahmed Ali',
        deviceName: 'Barcode Scanner',
        deviceType: 'Electronic',
        deviceId: 10,
        deviceNumber: 'E-01',
        reason: 'Audit',
        outDate: '2026-05-01',
        dueDate: '2026-05-10',
        backDate: '2026-05-15',
        isReturned: true,
      );
      expect(returnedLog.isOverdue(DateTime(2026, 5, 20)), false);

      // Null or empty dueDate is never overdue
      const indefiniteLog = BorrowLog(
        id: 3,
        employeeId: 2,
        employeeName: 'Sara John',
        deviceName: 'Adapter',
        deviceType: 'Electronic',
        deviceId: 11,
        deviceNumber: 'E-02',
        reason: 'Field Work',
        outDate: '2026-05-01',
        dueDate: null,
        isReturned: false,
      );
      expect(indefiniteLog.isOverdue(DateTime(2026, 5, 20)), false);

      // Invalid date string does not throw
      const malformedLog = BorrowLog(
        id: 4,
        employeeId: 2,
        employeeName: 'Sara John',
        deviceName: 'Adapter',
        deviceType: 'Electronic',
        deviceId: 11,
        deviceNumber: 'E-02',
        reason: 'Field Work',
        outDate: '2026-05-01',
        dueDate: 'not-a-date',
        isReturned: false,
      );
      expect(malformedLog.isOverdue(DateTime(2026, 5, 20)), false);
    });
  });

  group('Database Lifecycle & Integrity', () {
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

    test('Schema migration v15 creates tables and indexes correctly', () async {
      expect(db.schemaVersion, 15);
      final count = await helper.getCounts();
      expect(count['electronics'], 0);
      expect(count['employees'], 0);
      expect(count['active_borrows'], 0);
      expect(count['vendor_contacts'], 0);
    });

    test('Full Borrow lifecycle: borrow, conflict checks, return, and status healing', () async {
      // 1. Create electronic device and employee
      final devId = await helper.insertElectronic(const Electronic(
        deviceNumber: 'DEV-100',
        deviceName: 'Fluke Multimeter',
        status: 'Available',
      ));
      final empId = await helper.insertEmployee(const Employee(
        name: 'Mahmoud IT',
        phoneNumber: '0100000000',
      ));

      expect(devId, isPositive);
      expect(empId, isPositive);

      // Verify device initially available
      var devs = await helper.getElectronics();
      expect(devs.first.status, 'Available');
      expect(await helper.isDeviceBorrowed('Electronic', devId), false);
      expect(await helper.getEmployeeActiveBorrowsCount(empId), 0);

      // 2. Borrow device
      final logId = await helper.insertBorrowLog(BorrowLog(
        employeeId: empId,
        employeeName: 'Mahmoud IT',
        deviceName: 'Fluke Multimeter',
        deviceType: 'Electronic',
        deviceId: devId,
        deviceNumber: 'DEV-100',
        reason: 'Testing Panels',
        outDate: '2026-05-01',
        dueDate: '2026-05-05',
        isReturned: false,
      ));

      expect(logId, isPositive);

      // Device status automatically synced to 'Borrowed'
      devs = await helper.getElectronics();
      expect(devs.first.status, 'Borrowed');
      expect(await helper.isDeviceBorrowed('Electronic', devId), true);
      expect(await helper.getEmployeeActiveBorrowsCount(empId), 1);

      // 3. Mark returned
      await helper.markReturned(logId, devId, 'Electronic', '2026-05-04');

      // Device status automatically returned to 'Available'
      devs = await helper.getElectronics();
      expect(devs.first.status, 'Available');
      expect(await helper.isDeviceBorrowed('Electronic', devId), false);
      expect(await helper.getEmployeeActiveBorrowsCount(empId), 0);

      // 4. Test bidirectional status healing
      // Artificially corrupt device status to Borrowed when no active borrow exists
      await db.customUpdate("UPDATE electronics SET status = 'Borrowed' WHERE id = ?", variables: [Variable.withInt(devId)]);
      devs = await helper.getElectronics();
      expect(devs.first.status, 'Borrowed');

      await helper.syncDeviceStatuses();
      devs = await helper.getElectronics();
      expect(devs.first.status, 'Available');
    });

    test('Atomic rollback: transactions roll back all operations on failure', () async {
      await helper.insertElectronic(const Electronic(
        deviceNumber: 'DEV-200',
        deviceName: 'Crimper',
        status: 'Available',
      ));

      try {
        await helper.drift.transaction(() async {
          await helper.insertElectronic(const Electronic(
            deviceNumber: 'DEV-201',
            deviceName: 'Punch Down Tool',
            status: 'Available',
          ));
          throw Exception('Intentional failure to test rollback');
        });
      } catch (_) {}

      final devs = await helper.getElectronics();
      expect(devs.length, 1);
      expect(devs.first.deviceNumber, 'DEV-200');
    });

    test('JSON Backup and Restore round-trip preserves all tables and custom prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_switch_patch_chassis_v1', '[{"id":99,"name":"Custom Rack"}]');

      await helper.insertElectronic(const Electronic(
        deviceNumber: 'DEV-300',
        deviceName: 'Oscilloscope',
        status: 'Available',
      ));
      await helper.insertEmployee(const Employee(
        name: 'Sara Engineer',
        phoneNumber: '0123456789',
      ));
      await helper.insertExpense(const Expense(
        date: '2026-05-01',
        item: 'Cat6 Cable Reel',
        price: 1500.0,
      ));

      // Export JSON
      final jsonString = await helper.exportJson();
      expect(jsonString.contains('DEV-300'), true);
      expect(jsonString.contains('Sara Engineer'), true);
      expect(jsonString.contains('Cat6 Cable Reel'), true);
      expect(jsonString.contains('Custom Rack'), true);

      // Clear tables and prefs
      await helper.deleteTable('electronics');
      await helper.deleteTable('employees');
      await helper.deleteTable('expenses');
      await prefs.remove('custom_switch_patch_chassis_v1');

      expect((await helper.getElectronics()).isEmpty, true);
      expect((await helper.getEmployees()).isEmpty, true);
      expect((await helper.getExpenses()).isEmpty, true);
      expect(prefs.getString('custom_switch_patch_chassis_v1'), null);

      // Import JSON
      await helper.importJson(jsonString);

      final restoredDevs = await helper.getElectronics();
      final restoredEmps = await helper.getEmployees();
      final restoredExpenses = await helper.getExpenses();

      expect(restoredDevs.length, 1);
      expect(restoredDevs.first.deviceNumber, 'DEV-300');
      expect(restoredEmps.length, 1);
      expect(restoredEmps.first.name, 'Sara Engineer');
      expect(restoredExpenses.length, 1);
      expect(restoredExpenses.first.item, 'Cat6 Cable Reel');
      expect(prefs.getString('custom_switch_patch_chassis_v1'), '[{"id":99,"name":"Custom Rack"}]');
    });

    test('Active borrows block deletion of Electronic, MiFi, and Employee', () async {
      final devId = await helper.insertElectronic(const Electronic(
        deviceNumber: 'DEV-400',
        deviceName: 'Spectrum Analyzer',
        status: 'Available',
      ));
      final mifiId = await helper.insertMiFi(const MiFi(
        deviceNumber: 'MIFI-100',
        model: 'Huawei E5577',
        status: 'Available',
      ));
      final empId = await helper.insertEmployee(const Employee(
        name: 'Tarek Engineer',
        phoneNumber: '0111111111',
      ));

      // Borrow the electronic device
      final log1 = await helper.insertBorrowLog(BorrowLog(
        employeeId: empId,
        employeeName: 'Tarek Engineer',
        deviceName: 'Spectrum Analyzer',
        deviceType: 'Electronic',
        deviceId: devId,
        deviceNumber: 'DEV-400',
        reason: 'Network Analysis',
        outDate: '2026-05-01',
        isReturned: false,
      ));
      expect(log1, isPositive);

      // Borrow the MiFi
      final log2 = await helper.insertBorrowLog(BorrowLog(
        employeeId: empId,
        employeeName: 'Tarek Engineer',
        deviceName: 'Huawei E5577',
        deviceType: 'MiFi',
        deviceId: mifiId,
        deviceNumber: 'MIFI-100',
        reason: 'Site Survey',
        outDate: '2026-05-01',
        isReturned: false,
      ));
      expect(log2, isPositive);

      // Attempting to delete the borrowed electronic device must throw StateError
      expect(
        () => helper.deleteElectronic(devId),
        throwsA(isA<StateError>()),
      );

      // Attempting to delete the borrowed MiFi must throw StateError
      expect(
        () => helper.deleteMiFi(mifiId),
        throwsA(isA<StateError>()),
      );

      // Attempting to delete the employee with active borrows must throw StateError
      expect(
        () => helper.deleteEmployee(empId),
        throwsA(isA<StateError>()),
      );

      // Add dependent email and log entry
      await helper.insertEmailAccount(EmailAccount(
        email: 'tarek@company.com',
        password: 'pass',
        employeeId: empId,
      ));
      await helper.insertLogEntry(LogEntry(
        date: '2026-05-01',
        problem: 'Laptop fan noise',
        employeeId: empId,
      ));

      final depCounts = await helper.getEmployeeDependentCounts(empId);
      expect(depCounts['active_borrows'], 2);
      expect(depCounts['emails'], 1);
      expect(depCounts['tickets'], 1);

      // Returning devices allows safe deletion
      await helper.markReturned(log1, devId, 'Electronic', '2026-05-02');
      await helper.markReturned(log2, mifiId, 'MiFi', '2026-05-02');

      final depCountsAfterReturn = await helper.getEmployeeDependentCounts(empId);
      expect(depCountsAfterReturn['active_borrows'], 0);

      // Now deleting electronic succeeds
      await helper.deleteElectronic(devId);
      expect((await helper.getElectronics()).where((e) => e.id == devId).isEmpty, true);

      // Deleting MiFi succeeds
      await helper.deleteMiFi(mifiId);
      expect((await helper.getMiFis()).where((m) => m.id == mifiId).isEmpty, true);

      // Attempting to delete employee while linked to email fails (C4 guard)
      expect(() => helper.deleteEmployee(empId), throwsA(isA<StateError>()));

      // Clean up linked email
      final emails = await helper.getEmailAccounts();
      final empEmail = emails.firstWhere((e) => e.employeeId == empId);
      await helper.deleteEmailAccount(empEmail.id!);

      // Now deleting employee succeeds
      await helper.deleteEmployee(empId);
      expect((await helper.getEmployees()).where((e) => e.id == empId).isEmpty, true);
    });
  });

  group('Notification Timezone Handling & Safety', () {
    test('toUtcTZDate schedules future dates and rejects past dates correctly', () {
      final service = NotificationService();
      final nowRef = DateTime(2026, 5, 1, 8, 0);

      // Target in future on same day
      final futureSameDay = service.toUtcTZDate(DateTime(2026, 5, 1), 10, 0, nowRef);
      expect(futureSameDay, isNotNull);

      // Target in past on same day
      final pastSameDay = service.toUtcTZDate(DateTime(2026, 5, 1), 7, 0, nowRef);
      expect(pastSameDay, isNull);

      // Target on future date
      final futureDate = service.toUtcTZDate(DateTime(2026, 10, 31), 9, 0, nowRef);
      expect(futureDate, isNotNull);
      expect(futureDate!.year, 2026);
      expect(futureDate.month, 10);
      expect(futureDate.day, 31);
    });

    test('Uninitialized NotificationService methods do not throw LateInitializationError', () async {
      final service = NotificationService();
      // Should complete without throwing LateInitializationError
      await service.cancelReminder(999);
      await service.reconcileReminders([]);
    });
  });
}
