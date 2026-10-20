import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:itbox/database/app_database.dart';
import 'package:itbox/database/database_helper.dart';
import 'package:itbox/models/laptop.dart';
import 'package:itbox/models/network_device.dart';
import 'package:itbox/models/printer.dart';
import 'package:itbox/models/electronic.dart';
import 'package:itbox/models/employee.dart';
import 'package:itbox/models/borrow_log.dart';
import 'package:itbox/models/mifi.dart';
import 'package:itbox/models/expense.dart';
import 'package:itbox/models/bill.dart';
import 'package:itbox/models/email_account.dart';
import 'package:itbox/models/log_entry.dart';
import 'package:itbox/models/subscription.dart';
import 'package:itbox/models/access_point.dart';
import 'package:itbox/models/wifi_network.dart';
import 'package:itbox/models/account_password.dart';
import 'package:itbox/models/other_device.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('Phase 1: Pilot Phase - borrow_logs & log_entries typed streams & CRUD', () {
    test('watchBorrowLogs emits immediately and reacts to insert, return, and delete', () async {
      final emittedLists = <List<BorrowLog>>[];
      final sub = helper.watchBorrowLogs().listen(emittedLists.add);

      // Allow initial stream emission
      await pumpEventQueue();
      expect(emittedLists.length, 1);
      expect(emittedLists.last, isEmpty);

      // 1. Insert an active borrow log
      final logId = await helper.insertBorrowLog(const BorrowLog(
        deviceType: 'Electronic',
        deviceId: 1,
        deviceName: 'Oscilloscope',
        deviceNumber: 'E-01',
        employeeId: 10,
        employeeName: 'Eng. Tamer',
        reason: 'Lab Testing',
        outDate: '2026-06-01',
        dueDate: '2026-06-10',
        isReturned: false,
      ));

      await pumpEventQueue();
      expect(emittedLists.length, greaterThanOrEqualTo(2));
      expect(emittedLists.last.length, 1);
      expect(emittedLists.last.first.id, logId);
      expect(emittedLists.last.first.isReturned, false);

      // 2. Mark returned
      await helper.markReturned(logId, 1, 'Electronic', '2026-06-05');
      await pumpEventQueue();
      expect(emittedLists.last.first.isReturned, true);
      expect(emittedLists.last.first.backDate, '2026-06-05');

      // 3. Delete borrow log
      await helper.deleteBorrowLog(logId);
      await pumpEventQueue();
      expect(emittedLists.last, isEmpty);

      await sub.cancel();
    });

    test('watchBorrowLogs with activeOnly filter filters returned logs reactively', () async {
      final activeEmissions = <List<BorrowLog>>[];
      final sub = helper.watchBorrowLogs(activeOnly: true).listen(activeEmissions.add);

      await pumpEventQueue();
      expect(activeEmissions.last, isEmpty);

      final id1 = await helper.insertBorrowLog(const BorrowLog(
        deviceType: 'MiFi',
        deviceId: 5,
        deviceName: 'Huawei MiFi',
        deviceNumber: 'M-01',
        employeeId: 2,
        employeeName: 'Sara',
        reason: 'Remote Work',
        outDate: '2026-06-01',
        isReturned: false,
      ));

      await pumpEventQueue();
      expect(activeEmissions.last.length, 1);

      await helper.markReturned(id1, 5, 'MiFi', '2026-06-02');
      await pumpEventQueue();
      expect(activeEmissions.last, isEmpty);

      await sub.cancel();
    });

    test('watchLogEntries emits and filters by state and period', () async {
      final emissions = <List<LogEntry>>[];
      final sub = helper.watchLogEntries().listen(emissions.add);

      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      final id = await helper.insertLogEntry(const LogEntry(
        date: '2026-05-15',
        employeeId: 1,
        employeeName: 'Omar',
        problem: 'Printer jam',
        solution: 'Replaced roller',
        state: 'Open',
        priority: 'High',
      ));

      await pumpEventQueue();
      expect(emissions.last.length, 1);
      expect(emissions.last.first.problem, 'Printer jam');

      // Test year and month getters
      final years = await helper.getLogYears();
      expect(years, contains(2026));

      final byYear = await helper.getLogEntriesByYear(2026);
      expect(byYear.length, 1);

      final byMonth = await helper.getLogEntriesByMonth(2026, 5);
      expect(byMonth.length, 1);

      // Update log entry
      await helper.updateLogEntry(LogEntry(
        id: id,
        date: '2026-05-15',
        employeeId: 1,
        employeeName: 'Omar',
        problem: 'Printer jam',
        solution: 'Replaced roller and cleaned tray',
        state: 'Closed',
        priority: 'Low',
      ));

      await pumpEventQueue();
      expect(emissions.last.first.state, 'Closed');
      expect(emissions.last.first.solution, 'Replaced roller and cleaned tray');

      await helper.deleteLogEntry(id);
      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      await sub.cancel();
    });
  });

  group('Phase 2: Core Hardware Inventory (laptops, mifis, electronics)', () {
    test('Laptops typed CRUD and watchLaptops stream', () async {
      final emissions = <List<Laptop>>[];
      final sub = helper.watchLaptops().listen(emissions.add);

      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      final id = await helper.insertLaptop(const Laptop(
        laptopNumber: 'L-001',
        model: 'ThinkPad T14',
        cpu: 'Core i7',
        ram: '16GB',
        storage: '512GB SSD',
        condition: 'Good',
      ));

      await pumpEventQueue();
      expect(emissions.last.length, 1);
      expect(emissions.last.first.laptopNumber, 'L-001');

      await helper.updateLaptop(Laptop(
        id: id,
        laptopNumber: 'L-001',
        model: 'ThinkPad T14 Gen 2',
        cpu: 'Core i7',
        ram: '32GB',
        storage: '1TB SSD',
      ));

      await pumpEventQueue();
      expect(emissions.last.first.model, 'ThinkPad T14 Gen 2');
      expect(emissions.last.first.ram, '32GB');

      await helper.deleteLaptop(id);
      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      await sub.cancel();
    });

    test('MiFis typed CRUD and watchMiFis stream', () async {
      final emissions = <List<MiFi>>[];
      final sub = helper.watchMiFis().listen(emissions.add);

      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      final id = await helper.insertMiFi(const MiFi(
        deviceNumber: 'MIFI-01',
        model: 'ZTE 4G',
        status: 'Available',
      ));

      await pumpEventQueue();
      expect(emissions.last.length, 1);

      await helper.updateMiFiStatus(id, 'Borrowed');
      await pumpEventQueue();
      expect(emissions.last.first.status, 'Borrowed');

      await helper.updateMiFiStatus(id, 'Available');
      await pumpEventQueue();
      expect(emissions.last.first.status, 'Available');

      await helper.deleteMiFi(id);
      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      await sub.cancel();
    });

    test('Electronics typed CRUD and watchElectronics stream', () async {
      final emissions = <List<Electronic>>[];
      final sub = helper.watchElectronics().listen(emissions.add);

      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      final id = await helper.insertElectronic(const Electronic(
        deviceNumber: 'ELEC-01',
        deviceName: 'Projector',
        status: 'Available',
      ));

      await pumpEventQueue();
      expect(emissions.last.length, 1);

      await helper.updateElectronicStatus(id, 'Borrowed');
      await pumpEventQueue();
      expect(emissions.last.first.status, 'Borrowed');

      await helper.updateElectronicStatus(id, 'Available');
      await pumpEventQueue();
      expect(emissions.last.first.status, 'Available');

      await helper.deleteElectronic(id);
      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      await sub.cancel();
    });
  });

  group('Phase 3: Secondary Inventory & Networks', () {
    test('NetworkDevices typed CRUD and watchNetworkDevices stream', () async {
      final emissions = <List<NetworkDevice>>[];
      final sub = helper.watchNetworkDevices().listen(emissions.add);

      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      final id = await helper.insertNetworkDevice(const NetworkDevice(
        deviceNumber: 'NET-01',
        model: 'Cisco 2960',
        status: 'Available',
      ));

      await pumpEventQueue();
      expect(emissions.last.length, 1);

      await helper.updateNetworkDeviceStatus(id, 'In Use');
      await pumpEventQueue();
      expect(emissions.last.first.status, 'In Use');

      await helper.deleteNetworkDevice(id);
      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      await sub.cancel();
    });

    test('Printers, AccessPoints, OtherDevices, WifiNetworks typed streams', () async {
      // Printers
      final pId = await helper.insertPrinter(const Printer(
        printerNumber: 'P-01',
        model: 'HP LaserJet Pro',
      ));
      final printers = await helper.getPrinters();
      expect(printers.length, 1);
      expect(printers.first.printerNumber, 'P-01');

      // Access Points
      final apId = await helper.insertAccessPoint(const AccessPoint(
        deviceNumber: 'AP-01',
        model: 'UniFi U6 Pro',
      ));
      final aps = await helper.getAccessPoints();
      expect(aps.length, 1);
      expect(aps.first.deviceNumber, 'AP-01');

      // Other Devices
      final odId = await helper.insertOtherDevice(const OtherDevice(
        deviceType: 'Monitor',
        deviceName: 'Dell 27 4K',
      ));
      final ods = await helper.getOtherDevices();
      expect(ods.length, 1);
      expect(ods.first.deviceName, 'Dell 27 4K');

      // Wi-Fi Networks
      final wnId = await helper.insertWifiNetwork(const WifiNetwork(
        networkName: 'Guest-WiFi',
        password: 'securePassword123',
      ));
      final wns = await helper.getWifiNetworks();
      expect(wns.length, 1);
      expect(wns.first.networkName, 'Guest-WiFi');

      // Clean up
      await helper.deletePrinter(pId);
      await helper.deleteAccessPoint(apId);
      await helper.deleteOtherDevice(odId);
      await helper.deleteWifiNetwork(wnId);

      expect(await helper.getPrinters(), isEmpty);
      expect(await helper.getAccessPoints(), isEmpty);
      expect(await helper.getOtherDevices(), isEmpty);
      expect(await helper.getWifiNetworks(), isEmpty);
    });
  });

  group('Phase 4: Operations & Financial Ledger', () {
    test('Employees, EmailAccounts, AccountPasswords, StaticIps, Expenses, Bills, Subscriptions', () async {
      // Employees
      final empId = await helper.insertEmployee(const Employee(name: 'Ali Hani', phoneNumber: '0111111111'));
      expect((await helper.getEmployees()).length, 1);

      // Email Accounts
      final emailId = await helper.insertEmailAccount(EmailAccount(
        employeeId: empId,
        employeeName: 'Ali Hani',
        email: 'ali@company.local',
        password: 'password123',
      ));
      expect((await helper.getEmailAccounts()).length, 1);

      // Account Passwords
      final passId = await helper.insertAccountPassword(const AccountPassword(
        platform: 'GitHub',
        emailUsername: 'itbox-admin',
        password: 'token_abc123',
      ));
      expect((await helper.getAccountPasswords()).length, 1);

      // Static IPs
      final ipId = await helper.insertStaticIp({
        'ip_address': '192.168.1.100',
        'subnet_mask': '255.255.255.0',
        'assigned_device': 'Main Server',
        'device_type': 'Server',
      });
      expect((await helper.getStaticIps()).length, 1);

      // Expenses
      final expId = await helper.insertExpense(const Expense(
        date: '2026-04-10',
        item: 'HDMI Cables',
        price: 250.0,
      ));
      expect((await helper.getExpenses()).length, 1);
      expect((await helper.getExpensesByYear(2026)).length, 1);
      expect(await helper.getExpenseYears(), contains(2026));

      // Bills
      final billId = await helper.insertBill(const Bill(
        number: '0120000000',
        category: 'Landline Internet',
        price: 600.0,
      ));
      expect((await helper.getBills()).length, 1);

      // Subscriptions
      final subId = await helper.insertSubscription(const Subscription(
        service: 'Google Workspace',
        type: 'Monthly',
        price: 15.0,
      ));
      expect((await helper.getSubscriptions()).length, 1);

      // Clean up
      await helper.deleteSubscription(subId);
      await helper.deleteBill(billId);
      await helper.deleteExpense(expId);
      await helper.deleteStaticIp(ipId);
      await helper.deleteAccountPassword(passId);
      await helper.deleteEmailAccount(emailId);
      await helper.deleteEmployee(empId);

      expect(await helper.getEmployees(), isEmpty);
      expect(await helper.getEmailAccounts(), isEmpty);
      expect(await helper.getAccountPasswords(), isEmpty);
      expect(await helper.getStaticIps(), isEmpty);
      expect(await helper.getExpenses(), isEmpty);
      expect(await helper.getBills(), isEmpty);
      expect(await helper.getSubscriptions(), isEmpty);
    });
  });

  group('Phase 5: Technical Matrix, Maintenance & System Auditing', () {
    test('SwitchPatchPorts, MaintenanceLogs, Consumables, AuditActivities, SoftDeletes', () async {
      // Switch Patch Ports
      await helper.insertSwitchPatchPort({
        'switch_device_id': 1,
        'port_number': 1,
        'connected_device': 'AP-01',
        'destination_room': 'Meeting Room 1',
        'vlan': '10',
        'status': 'Active',
      });
      final ports = await helper.getSwitchPatchPorts(1);
      expect(ports.length, 1);
      expect(ports.first['port_number'], 1);

      // Maintenance Logs
      final mId = await helper.insertMaintenanceLog({
        'device_type': 'laptop',
        'device_id': 1,
        'date': '2026-06-01',
        'service_type': 'Thermal Paste',
        'cost': 150.0,
        'details': 'Repasted CPU/GPU',
        'performed_by': 'Eng. Karim',
      });
      final mLogs = await helper.getMaintenanceLogsForDevice('laptop', 1);
      expect(mLogs.length, 1);
      expect(mLogs.first['service_type'], 'Thermal Paste');
      await helper.deleteMaintenanceLog(mId);
      expect(await helper.getMaintenanceLogsForDevice('laptop', 1), isEmpty);

      // Consumables & Stock
      final cId = await helper.insertConsumable({
        'item_name': 'RJ45 Connectors',
        'category': 'Networking',
        'quantity': 100,
        'minimum_threshold': 20,
        'location': 'Cabinet B',
        'unit_price': 1.5,
      });
      expect((await helper.getConsumables()).length, 1);

      // Adjust quantity
      final newQty = await helper.adjustConsumableQuantity(cId, -15, 'Patch cables creation', null);
      expect(newQty, 85);
      final cLogs = await helper.getConsumableLogs(cId);
      expect(cLogs.length, 1);
      expect(cLogs.first['change_amount'], -15);
      await helper.deleteConsumable(cId);
      expect(await helper.getConsumables(), isEmpty);

      // Audit Activities
      final aId = await helper.logAuditActivity('CHECKOUT', 'MiFi', entityId: 5, description: 'Checked out to Sara');
      expect(aId, isPositive);
      final audits = await helper.getAuditActivities(limit: 10);
      expect(audits.length, 1);
      expect(audits.first['action_type'], 'CHECKOUT');
      final clearedCount = await helper.clearAuditActivities();
      expect(clearedCount, 1);
      final emptyAudits = await helper.getAuditActivities(limit: 10);
      expect(emptyAudits.isEmpty, isTrue);

      // Soft Deletes
      final sdId = await helper.insertSoftDelete({
        'original_table': 'laptops',
        'original_id': 99,
        'display_name': 'ThinkPad T480',
        'serialized_data': '{"id": 99, "laptop_number": "L-99"}',
        'deleted_at': DateTime.now().toIso8601String(),
      });
      expect(sdId, isPositive);
      final sds = await helper.getSoftDeletes();
      expect(sds.length, 1);
      expect(sds.first['original_table'], 'laptops');
      await helper.deleteSoftDelete(sdId);
      expect(await helper.getSoftDeletes(), isEmpty);

      // Port Deletions (Phase 5 typed deletion)
      final port1Id = await helper.insertSwitchPatchPort({
        'switch_device_id': 2,
        'port_number': 1,
        'connected_device': 'Router',
      });
      await helper.insertSwitchPatchPort({
        'switch_device_id': 2,
        'port_number': 2,
        'connected_device': 'Printer',
      });
      expect((await helper.getSwitchPatchPorts(2)).length, 2);

      await helper.deleteSwitchPatchPort(port1Id);
      expect((await helper.getSwitchPatchPorts(2)).length, 1);

      await helper.deleteSwitchPatchPortsForSwitch(2);
      expect((await helper.getSwitchPatchPorts(2)), isEmpty);
    });
  });

  group('Phase 4 & Edge Cases: Aggregations, Directory Search, WatchCounts, and Status Synchronization', () {
    test('updateBorrowLog synchronizes device status when return status toggles without changing device', () async {
      final devId = await helper.insertElectronic(const Electronic(
        deviceNumber: 'ELEC-99',
        deviceName: 'Soldering Station',
        status: 'Available',
      ));

      // Borrow the device
      final logId = await helper.insertBorrowLog(BorrowLog(
        deviceType: 'Electronic',
        deviceId: devId,
        deviceName: 'Soldering Station',
        deviceNumber: 'ELEC-99',
        employeeId: 10,
        employeeName: 'Ahmed Tech',
        reason: 'Repair',
        outDate: '2026-06-01',
        isReturned: false,
      ));

      expect((await helper.getElectronics()).first.status, 'Borrowed');

      // Update borrow log to mark returned WITHOUT changing device
      await helper.updateBorrowLog(
        logId,
        BorrowLog(
          id: logId,
          deviceType: 'Electronic',
          deviceId: devId,
          deviceName: 'Soldering Station',
          deviceNumber: 'ELEC-99',
          employeeId: 10,
          employeeName: 'Ahmed Tech',
          reason: 'Repair',
          outDate: '2026-06-01',
          backDate: '2026-06-03',
          isReturned: true,
        ),
      );

      // Status should have healed to 'Available'
      expect((await helper.getElectronics()).first.status, 'Available');

      // Re-open borrow log (mark as active again)
      await helper.updateBorrowLog(
        logId,
        BorrowLog(
          id: logId,
          deviceType: 'Electronic',
          deviceId: devId,
          deviceName: 'Soldering Station',
          deviceNumber: 'ELEC-99',
          employeeId: 10,
          employeeName: 'Ahmed Tech',
          reason: 'Repair',
          outDate: '2026-06-01',
          isReturned: false,
        ),
      );

      // Status should have reverted to 'Borrowed'
      expect((await helper.getElectronics()).first.status, 'Borrowed');

      // Clean up
      await helper.deleteBorrowLog(logId);
      expect((await helper.getElectronics()).first.status, 'Available');
      await helper.deleteElectronic(devId);
    });

    test('Typed financial aggregations getTotalExpenses, watchTotalExpenses, getTotalBills, watchTotalBills', () async {
      final expEmissions = <double>[];
      final expSub = helper.watchTotalExpenses(year: 2026, month: 7).listen(expEmissions.add);

      final billEmissions = <double>[];
      final billSub = helper.watchTotalBills().listen(billEmissions.add);

      await pumpEventQueue();
      expect(expEmissions.last, 0.0);
      expect(billEmissions.last, 0.0);

      // Insert expense in July 2026
      final e1 = await helper.insertExpense(const Expense(
        date: '2026-07-05',
        item: 'Screwdriver Set',
        price: 350.50,
      ));
      final e2 = await helper.insertExpense(const Expense(
        date: '2026-07-15',
        item: 'Thermal Pad',
        price: 150.00,
      ));
      // Expense in different month
      final e3 = await helper.insertExpense(const Expense(
        date: '2026-08-01',
        item: 'Label Rolls',
        price: 500.00,
      ));

      await pumpEventQueue();
      expect(await helper.getTotalExpenses(year: 2026, month: 7), 500.50);
      expect(await helper.getTotalExpenses(year: 2026), 1000.50);
      expect(expEmissions.last, 500.50);

      // Insert bills
      final b1 = await helper.insertBill(const Bill(
        number: '111',
        category: 'ISP',
        price: 1200.0,
      ));
      final b2 = await helper.insertBill(const Bill(
        number: '222',
        category: 'Electricity',
        price: 800.0,
      ));

      await pumpEventQueue();
      expect(await helper.getTotalBills(), 2000.0);
      expect(billEmissions.last, 2000.0);

      await helper.deleteExpense(e1);
      await helper.deleteExpense(e2);
      await helper.deleteExpense(e3);
      await helper.deleteBill(b1);
      await helper.deleteBill(b2);

      await expSub.cancel();
      await billSub.cancel();
    });

    test('watchCounts emits reactively across all tables', () async {
      final countEmissions = <Map<String, int>>[];
      final sub = helper.watchCounts().listen(countEmissions.add);

      await pumpEventQueue();
      expect(countEmissions.last['laptops'], 0);

      final lId = await helper.insertLaptop(const Laptop(laptopNumber: 'L-1', model: 'Dell'));
      await pumpEventQueue();
      expect(countEmissions.last['laptops'], 1);

      await helper.deleteLaptop(lId);
      await pumpEventQueue();
      expect(countEmissions.last['laptops'], 0);

      await sub.cancel();
    });

    test('watchEmployees with search query filters reactively', () async {
      final results = <List<Employee>>[];
      final sub = helper.watchEmployees(search: 'ahmed').listen(results.add);

      await pumpEventQueue();
      expect(results.last, isEmpty);

      final e1 = await helper.insertEmployee(const Employee(name: 'Ahmed Hassan', phoneNumber: '0101111111'));
      final e2 = await helper.insertEmployee(const Employee(name: 'Sara Nour', phoneNumber: '0102222222'));

      await pumpEventQueue();
      expect(results.last.length, 1);
      expect(results.last.first.name, 'Ahmed Hassan');

      await helper.deleteEmployee(e1);
      await helper.deleteEmployee(e2);
      await sub.cancel();
    });

    test('getOpenLogEntries matches open tickets case-insensitively', () async {
      final id1 = await helper.insertLogEntry(const LogEntry(
        date: '2026-06-01',
        problem: 'Issue A',
        state: 'Open',
      ));
      final id2 = await helper.insertLogEntry(const LogEntry(
        date: '2026-06-02',
        problem: 'Issue B',
        state: 'open',
      ));
      final id3 = await helper.insertLogEntry(const LogEntry(
        date: '2026-06-03',
        problem: 'Issue C',
        state: 'Closed',
      ));

      final openLogs = await helper.getOpenLogEntries();
      expect(openLogs.length, 2);

      await helper.deleteLogEntry(id1);
      await helper.deleteLogEntry(id2);
      await helper.deleteLogEntry(id3);
    });
  });
}
