// lib/database/database_helper.dart
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

import 'app_database.dart';
import '../models/laptop.dart';
import '../models/network_device.dart';
import '../models/printer.dart';
import '../models/electronic.dart';
import '../models/employee.dart';
import '../models/borrow_log.dart';
import '../models/mifi.dart';
import '../models/expense.dart';
import '../models/bill.dart';
import '../models/email_account.dart';
import '../models/log_entry.dart';
import '../models/subscription.dart';
import '../models/access_point.dart';
import '../models/wifi_network.dart';
import '../models/account_password.dart';
import '../models/other_device.dart';
import '../models/vendor_contact.dart';
import '../services/company_service.dart';
import '../services/theme_service.dart';
import '../services/notification_service.dart';
import '../services/backup_crypto_service.dart';

class TableNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Metadata and validation summary returned by [DatabaseHelper.inspectBackupJson].
class BackupManifestSummary {
  final int schemaVersion;
  final String appVersion;
  final String exportedAt;
  final String companyName;
  final Map<String, int> tableCounts;
  final bool hasLogo;
  final bool hasThemePrefs;
  final bool isEncrypted;
  final bool isValid;
  final String? validationError;

  const BackupManifestSummary({
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.companyName,
    required this.tableCounts,
    required this.hasLogo,
    required this.hasThemePrefs,
    required this.isEncrypted,
    required this.isValid,
    this.validationError,
  });
}

/// DatabaseHelper backed by Drift [AppDatabase] executing SQLite in a background isolate.
/// Preserves complete backward compatibility with all screens, services, and tests.
class DatabaseHelper extends ChangeNotifier {
  static final DatabaseHelper _i = DatabaseHelper._();
  factory DatabaseHelper() => _i;
  DatabaseHelper._();

  AppDatabase get drift => AppDatabase.instance;

  final Map<String, TableNotifier> _tableNotifiers = {};
  TableNotifier _tableNotifier(String t) => _tableNotifiers.putIfAbsent(t, TableNotifier.new);
  Listenable tables(Iterable<String> t) => Listenable.merge(t.map(_tableNotifier).toList());

  bool _batchNotification = false;
  final Set<String> _dirtyTables = {};
  Timer? _debounceTimer;
  final StreamController<void> _dbSwitchController = StreamController<void>.broadcast();

  Stream<T> _watchSwitchable<T>(Stream<T> Function() streamFactory) {
    late StreamController<T> controller;
    StreamSubscription<T>? innerSub;
    StreamSubscription<void>? switchSub;

    void attach() {
      innerSub?.cancel();
      innerSub = streamFactory().listen(
        (data) {
          if (!controller.isClosed) {
            controller.add(data);
          }
        },
        onError: (Object err, StackTrace st) {
          if (!controller.isClosed) {
            controller.addError(err, st);
          }
        },
      );
    }

    controller = StreamController<T>(
      onListen: () {
        attach();
        switchSub = _dbSwitchController.stream.listen((_) => attach());
      },
      onCancel: () async {
        await innerSub?.cancel();
        await switchSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Called after switching the active organization database instance.
  /// Re-binds all active watch*() streams and notifies every table listener without restart.
  Future<void> onDatabaseSwitched() async {
    await syncDeviceStatuses();
    _dbSwitchController.add(null);
    for (final notifier in _tableNotifiers.values) {
      notifier.notify();
    }
    notifyListeners();
  }

  /// Converts all stored financial amounts across expenses, bills, subscriptions,
  /// and maintenance logs by [factor] inside an atomic transaction.
  Future<void> convertAllFinancialAmounts(double factor) async {
    if (factor <= 0 || factor == 1.0) {
      return;
    }
    await drift.transaction(() async {
      await drift.customStatement('UPDATE expenses SET price = ROUND(price * ?, 2)', [factor]);
      await drift.customStatement('UPDATE bills SET price = ROUND(price * ?, 2)', [factor]);
      await drift.customStatement('UPDATE subscriptions SET price = ROUND(price * ?, 2)', [factor]);
      await drift.customStatement('UPDATE device_maintenance_logs SET cost = ROUND(cost * ?, 2)', [factor]);
    });
    notifyTableChanged('expenses');
    notifyTableChanged('bills');
    notifyTableChanged('subscriptions');
    notifyTableChanged('device_maintenance_logs');
    _dbSwitchController.add(null);
    notifyListeners();
  }

  void notifyTableChanged(String table) {
    _dirtyTables.add(table);
    if (_batchNotification) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 60), _flushNotifications);
  }

  void _flushNotifications() {
    if (_dirtyTables.isEmpty) return;
    final tablesToNotify = Set<String>.from(_dirtyTables);
    _dirtyTables.clear();
    for (final t in tablesToNotify) {
      _tableNotifiers[t]?.notify();
    }
    notifyListeners();
  }

  Future<T> batchScope<T>(Future<T> Function() action) async {
    _batchNotification = true;
    try {
      return await action();
    } finally {
      _batchNotification = false;
      _flushNotifications();
    }
  }

  /// Ensures database connection and runs initial self-healing status synchronization.
  Future<void> init() async {
    await syncDeviceStatuses();
  }

  // ── Generic Map Helpers ───────────────────────────────────────────────────
  @Deprecated('Use typed Drift query builders and Companions instead')
  Future<int> insertMap(String table, Map<String, dynamic> map) async {
    final keys = map.keys.toList();
    final placeholders = List.filled(keys.length, '?').join(', ');
    final cols = keys.join(', ');
    final sql = 'INSERT INTO $table ($cols) VALUES ($placeholders)';
    final values = keys.map((k) => Variable<Object>(map[k])).toList();
    final res = await drift.customInsert(sql, variables: values);
    notifyTableChanged(table);
    return res;
  }

  // ── Raw query compatibility for Settings & Exports ────────────────────────
  @Deprecated('Use typed Drift query builders instead')
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) async {
    var sql = 'SELECT * FROM $table';
    if (where != null && where.isNotEmpty) {
      sql += ' WHERE $where';
    }
    if (orderBy != null && orderBy.isNotEmpty) {
      sql += ' ORDER BY $orderBy';
    }
    final vars = whereArgs?.map((a) => Variable<Object>(a)).toList() ?? [];
    final rows = await drift.customSelect(sql, variables: vars).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
  }

  @Deprecated('Use typed Drift query builders instead')
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final vars = arguments?.map((a) => Variable<Object>(a)).toList() ?? [];
    final rows = await drift.customSelect(sql, variables: vars).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
  }

  @Deprecated('Use typed Drift query builders instead')
  Future<int> deleteTable(String table) async {
    final res = await drift.customUpdate('DELETE FROM $table');
    notifyTableChanged(table);
    return res;
  }

  // ── Typed Model Converters ────────────────────────────────────────────────
  Laptop _laptopFromEntry(LaptopEntry e) => Laptop(
        id: e.id,
        laptopNumber: e.laptopNumber,
        model: e.model,
        cpu: e.cpu,
        gpu: e.gpu,
        ram: e.ram,
        storage: e.storage,
        condition: e.condition,
        user: e.user,
        password: e.password,
        notes: e.notes,
        createdAt: e.createdAt != null ? DateTime.tryParse(e.createdAt!) : null,
      );

  LaptopsCompanion _laptopToCompanion(Laptop l) => LaptopsCompanion(
        id: l.id != null ? Value(l.id!) : const Value.absent(),
        laptopNumber: Value(l.laptopNumber),
        model: Value(l.model),
        cpu: Value(l.cpu),
        gpu: Value(l.gpu),
        ram: Value(l.ram),
        storage: Value(l.storage),
        condition: Value(l.condition),
        user: Value(l.user),
        password: Value(l.password),
        notes: Value(l.notes),
        createdAt: Value(l.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String()),
      );

  NetworkDevice _networkDeviceFromEntry(NetworkDeviceEntry e) => NetworkDevice(
        id: e.id,
        deviceNumber: e.deviceNumber,
        model: e.model,
        phoneNumber: e.phoneNumber,
        deviceLocation: e.deviceLocation,
        serviceProvider: e.serviceProvider,
        wifiName: e.wifiName,
        wifiPassword: e.wifiPassword,
        gateway: e.gateway,
        adminPassword: e.adminPassword,
        status: e.status,
        notes: e.notes,
      );

  NetworkDevicesCompanion _networkDeviceToCompanion(NetworkDevice d) => NetworkDevicesCompanion(
        id: d.id != null ? Value(d.id!) : const Value.absent(),
        deviceNumber: Value(d.deviceNumber),
        model: Value(d.model),
        phoneNumber: Value(d.phoneNumber),
        deviceLocation: Value(d.deviceLocation),
        serviceProvider: Value(d.serviceProvider),
        wifiName: Value(d.wifiName),
        wifiPassword: Value(d.wifiPassword),
        gateway: Value(d.gateway),
        adminPassword: Value(d.adminPassword),
        status: Value(d.status),
        notes: Value(d.notes),
      );

  Printer _printerFromEntry(PrinterEntry e) => Printer(
        id: e.id,
        printerNumber: e.printerNumber,
        model: e.model,
        condition: e.condition,
        location: e.location,
        notes: e.notes,
      );

  PrintersCompanion _printerToCompanion(Printer p) => PrintersCompanion(
        id: p.id != null ? Value(p.id!) : const Value.absent(),
        printerNumber: Value(p.printerNumber),
        model: Value(p.model),
        condition: Value(p.condition),
        location: Value(p.location),
        notes: Value(p.notes),
      );

  Electronic _electronicFromEntry(ElectronicEntry e) => Electronic(
        id: e.id,
        deviceNumber: e.deviceNumber,
        deviceName: e.deviceName,
        details: e.details,
        status: e.status,
        excludeFromBorrowing: e.excludeBorrowing == 1,
        notes: e.notes,
      );

  ElectronicsCompanion _electronicToCompanion(Electronic e) => ElectronicsCompanion(
        id: e.id != null ? Value(e.id!) : const Value.absent(),
        deviceNumber: Value(e.deviceNumber),
        deviceName: Value(e.deviceName),
        details: Value(e.details),
        status: Value(e.status),
        excludeBorrowing: Value(e.excludeFromBorrowing ? 1 : 0),
        notes: Value(e.notes),
      );

  Employee _employeeFromEntry(EmployeeEntry e) => Employee(
        id: e.id,
        name: e.name,
        phoneNumber: e.phoneNumber,
      );

  EmployeesCompanion _employeeToCompanion(Employee e) => EmployeesCompanion(
        id: e.id != null ? Value(e.id!) : const Value.absent(),
        name: Value(e.name),
        phoneNumber: Value(e.phoneNumber),
      );

  MiFi _mifiFromEntry(MiFiEntry e) => MiFi(
        id: e.id,
        deviceNumber: e.deviceNumber,
        model: e.model,
        phoneNumber: e.phoneNumber,
        wifiName: e.wifiName,
        wifiPassword: e.wifiPassword,
        quota: e.quota,
        serviceProvider: e.serviceProvider,
        gateway: e.gateway,
        adminPassword: e.adminPassword,
        status: e.status,
        excludeFromBorrowing: e.excludeBorrowing == 1,
        tag: e.tag,
        notes: e.notes,
      );

  MifisCompanion _mifiToCompanion(MiFi m) => MifisCompanion(
        id: m.id != null ? Value(m.id!) : const Value.absent(),
        deviceNumber: Value(m.deviceNumber),
        model: Value(m.model),
        phoneNumber: Value(m.phoneNumber),
        wifiName: Value(m.wifiName),
        wifiPassword: Value(m.wifiPassword),
        quota: Value(m.quota),
        serviceProvider: Value(m.serviceProvider),
        gateway: Value(m.gateway),
        adminPassword: Value(m.adminPassword),
        status: Value(m.status),
        excludeBorrowing: Value(m.excludeFromBorrowing ? 1 : 0),
        tag: Value(m.tag),
        notes: Value(m.notes),
      );

  BorrowLog _borrowLogFromEntry(BorrowLogEntry e) => BorrowLog(
        id: e.id,
        deviceType: e.deviceType,
        deviceId: e.deviceId,
        deviceName: e.deviceName,
        deviceNumber: e.deviceNumber,
        employeeId: e.employeeId,
        employeeName: e.employeeName,
        reason: e.reason,
        outDate: e.outDate,
        backDate: e.backDate,
        dueDate: e.dueDate,
        reminderTime: e.reminderTime,
        isReturned: e.isReturned == 1,
      );

  BorrowLogsCompanion _borrowLogToCompanion(BorrowLog l) => BorrowLogsCompanion(
        id: l.id != null ? Value(l.id!) : const Value.absent(),
        deviceType: Value(l.deviceType),
        deviceId: Value(l.deviceId),
        deviceName: Value(l.deviceName),
        deviceNumber: Value(l.deviceNumber),
        employeeId: Value(l.employeeId),
        employeeName: Value(l.employeeName),
        reason: Value(l.reason),
        outDate: Value(l.outDate),
        backDate: Value(l.backDate),
        dueDate: Value(l.dueDate),
        reminderTime: Value(l.reminderTime),
        isReturned: Value(l.isReturned ? 1 : 0),
      );

  Expense _expenseFromEntry(ExpenseEntry e) => Expense(
        id: e.id,
        date: e.date,
        item: e.item,
        price: e.price,
        details: e.details,
      );

  ExpensesCompanion _expenseToCompanion(Expense ex) => ExpensesCompanion(
        id: ex.id != null ? Value(ex.id!) : const Value.absent(),
        date: Value(ex.date),
        item: Value(ex.item),
        price: Value(ex.price),
        details: Value(ex.details),
      );

  Bill _billFromEntry(BillEntry e) => Bill(
        id: e.id,
        person: e.person,
        number: e.number,
        category: e.category,
        price: e.price,
        notes: e.notes,
      );

  BillsCompanion _billToCompanion(Bill b) => BillsCompanion(
        id: b.id != null ? Value(b.id!) : const Value.absent(),
        person: Value(b.person),
        number: Value(b.number),
        category: Value(b.category),
        price: Value(b.price),
        notes: Value(b.notes),
      );

  EmailAccount _emailAccountFromEntry(EmailAccountEntry e) => EmailAccount(
        id: e.id,
        employeeId: e.employeeId,
        employeeName: e.employeeName,
        email: e.email,
        password: e.password,
      );

  EmailAccountsCompanion _emailAccountToCompanion(EmailAccount ea) => EmailAccountsCompanion(
        id: ea.id != null ? Value(ea.id!) : const Value.absent(),
        employeeId: ea.employeeId != null ? Value(ea.employeeId) : const Value.absent(),
        employeeName: Value(ea.employeeName),
        email: Value(ea.email),
        password: Value(ea.password),
      );

  LogEntry _logEntryFromEntry(LogEntryTableEntry e) => LogEntry(
        id: e.id,
        date: e.date,
        employeeId: e.employeeId,
        employeeName: e.employeeName,
        problem: e.problem,
        solution: e.solution,
        state: e.state,
        priority: e.priority,
      );

  LogEntriesCompanion _logEntryToCompanion(LogEntry le) {
    String st = le.state.trim();
    if (st.toLowerCase() == 'resolved') {
      st = 'Resolved';
    } else if (st.toLowerCase() == 'closed') {
      st = 'Closed';
    } else {
      st = 'Open';
    }
    return LogEntriesCompanion(
        id: le.id != null ? Value(le.id!) : const Value.absent(),
        date: Value(le.date),
        employeeId: le.employeeId != null ? Value(le.employeeId) : const Value.absent(),
        employeeName: Value(le.employeeName),
        problem: Value(le.problem),
        solution: Value(le.solution),
        state: Value(st),
        priority: Value(le.priority),
      );
  }

  Subscription _subscriptionFromEntry(SubscriptionEntry e) => Subscription(
        id: e.id,
        service: e.service,
        type: e.type,
        price: e.price,
        renewalDate: e.renewalDate,
        notes: e.notes,
      );

  SubscriptionsCompanion _subscriptionToCompanion(Subscription s) => SubscriptionsCompanion(
        id: s.id != null ? Value(s.id!) : const Value.absent(),
        service: Value(s.service),
        type: Value(s.type),
        price: Value(s.price),
        renewalDate: Value(s.renewalDate),
        notes: Value(s.notes),
      );

  AccessPoint _accessPointFromEntry(AccessPointEntry e) => AccessPoint(
        id: e.id,
        deviceNumber: e.deviceNumber,
        model: e.model,
        portNumber: e.portNumber,
        location: e.location,
        notes: e.notes,
      );

  AccessPointsCompanion _accessPointToCompanion(AccessPoint ap) => AccessPointsCompanion(
        id: ap.id != null ? Value(ap.id!) : const Value.absent(),
        deviceNumber: Value(ap.deviceNumber),
        model: Value(ap.model),
        portNumber: Value(ap.portNumber),
        location: Value(ap.location),
        notes: Value(ap.notes),
      );

  WifiNetwork _wifiNetworkFromEntry(WifiNetworkEntry e) => WifiNetwork(
        id: e.id,
        networkName: e.networkName,
        password: e.password,
        phoneNumber: e.phoneNumber,
        locationDevice: e.locationDevice,
        adminUsername: e.adminUsername,
        adminPassword: e.adminPassword,
        notes: e.notes,
        createdAt: e.createdAt,
      );

  WifiNetworksCompanion _wifiNetworkToCompanion(WifiNetwork wn) => WifiNetworksCompanion(
        id: wn.id != null ? Value(wn.id!) : const Value.absent(),
        networkName: Value(wn.networkName),
        password: Value(wn.password),
        phoneNumber: Value(wn.phoneNumber),
        locationDevice: Value(wn.locationDevice),
        adminUsername: Value(wn.adminUsername),
        adminPassword: Value(wn.adminPassword),
        notes: Value(wn.notes),
        createdAt: Value(wn.createdAt ?? DateTime.now().toIso8601String()),
      );

  AccountPassword _accountPasswordFromEntry(AccountPasswordEntry e) => AccountPassword(
        id: e.id,
        platform: e.platform,
        emailUsername: e.emailUsername,
        password: e.password,
        createdAt: e.createdAt,
      );

  AccountPasswordsCompanion _accountPasswordToCompanion(AccountPassword ap) => AccountPasswordsCompanion(
        id: ap.id != null ? Value(ap.id!) : const Value.absent(),
        platform: Value(ap.platform),
        emailUsername: Value(ap.emailUsername),
        password: Value(ap.password),
        createdAt: Value(ap.createdAt ?? DateTime.now().toIso8601String()),
      );

  OtherDevice _otherDeviceFromEntry(OtherDeviceEntry e) => OtherDevice(
        id: e.id,
        deviceType: e.deviceType,
        deviceName: e.deviceName,
        model: e.model,
        notes: e.notes,
        createdAt: e.createdAt,
      );

  OtherDevicesCompanion _otherDeviceToCompanion(OtherDevice od) => OtherDevicesCompanion(
        id: od.id != null ? Value(od.id!) : const Value.absent(),
        deviceType: Value(od.deviceType),
        deviceName: Value(od.deviceName),
        model: Value(od.model),
        notes: Value(od.notes),
        createdAt: Value(od.createdAt ?? DateTime.now().toIso8601String()),
      );

  VendorContact _vendorContactFromEntry(VendorContactEntry e) => VendorContact(
        id: e.id,
        contactType: e.contactType,
        name: e.name,
        company: e.company,
        role: e.role,
        phoneNumber: e.phoneNumber,
        email: e.email,
        portalUrl: e.portalUrl,
        accountNumber: e.accountNumber,
        notes: e.notes,
        createdAt: e.createdAt,
      );

  VendorContactsCompanion _vendorContactToCompanion(VendorContact v) => VendorContactsCompanion(
        id: v.id != null ? Value(v.id!) : const Value.absent(),
        contactType: Value(v.contactType),
        name: Value(v.name),
        company: Value(v.company),
        role: Value(v.role),
        phoneNumber: Value(v.phoneNumber),
        email: Value(v.email),
        portalUrl: Value(v.portalUrl),
        accountNumber: Value(v.accountNumber),
        notes: Value(v.notes),
        createdAt: Value(v.createdAt ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> _maintenanceEntryToMap(MaintenanceEntry e) => {
        'id': e.id,
        'device_type': e.deviceType,
        'device_id': e.deviceId,
        'date': e.date,
        'service_type': e.serviceType,
        'cost': e.cost,
        'details': e.details,
        'performed_by': e.performedBy,
        'is_planned': e.isPlanned,
        'planned_date': e.plannedDate,
      };

  DeviceMaintenanceLogsCompanion _maintenanceLogToCompanion(Map<String, dynamic> m) =>
      DeviceMaintenanceLogsCompanion(
        id: m['id'] != null ? Value(m['id'] as int) : const Value.absent(),
        deviceType: Value((m['device_type'] ?? '') as String),
        deviceId: Value((m['device_id'] ?? 0) as int),
        date: Value((m['date'] ?? '') as String),
        serviceType: Value((m['service_type'] ?? 'Maintenance') as String),
        cost: Value((m['cost'] as num? ?? 0.0).toDouble()),
        details: Value((m['details'] ?? '') as String),
        performedBy: Value((m['performed_by'] ?? '') as String),
        isPlanned: Value((m['is_planned'] as num? ?? 0).toInt()),
        plannedDate: Value((m['planned_date'] ?? '') as String),
      );

  Map<String, dynamic> _staticIpEntryToMap(StaticIpEntry e) => {
        'id': e.id,
        'ip_address': e.ipAddress,
        'subnet_mask': e.subnetMask,
        'assigned_device': e.assignedDevice,
        'device_type': e.deviceType,
        'mac_address': e.macAddress,
        'notes': e.notes,
      };

  StaticIpsCompanion _staticIpToCompanion(Map<String, dynamic> m) => StaticIpsCompanion(
        id: m['id'] != null ? Value(m['id'] as int) : const Value.absent(),
        ipAddress: Value((m['ip_address'] ?? '') as String),
        subnetMask: Value((m['subnet_mask'] ?? '255.255.255.0') as String),
        assignedDevice: Value((m['assigned_device'] ?? '') as String),
        deviceType: Value((m['device_type'] ?? 'Other') as String),
        macAddress: Value((m['mac_address'] ?? '') as String),
        notes: Value((m['notes'] ?? '') as String),
      );

  Map<String, dynamic> _switchPatchPortEntryToMap(SwitchPatchPortEntry e) => {
        'id': e.id,
        'switch_device_id': e.switchDeviceId,
        'port_number': e.portNumber,
        'connected_device': e.connectedDevice,
        'destination_room': e.destinationRoom,
        'vlan': e.vlan,
        'status': e.status,
      };

  SwitchPatchPortsCompanion _switchPatchPortToCompanion(Map<String, dynamic> m) =>
      SwitchPatchPortsCompanion(
        id: m['id'] != null ? Value(m['id'] as int) : const Value.absent(),
        switchDeviceId: Value((m['switch_device_id'] ?? 0) as int),
        portNumber: Value((m['port_number'] ?? 0) as int),
        connectedDevice: Value((m['connected_device'] ?? '') as String),
        destinationRoom: Value((m['destination_room'] ?? '') as String),
        vlan: Value((m['vlan'] ?? '1') as String),
        status: Value((m['status'] ?? 'Active') as String),
      );

  Map<String, dynamic> _auditActivityEntryToMap(AuditActivityEntry e) => {
        'id': e.id,
        'action_type': e.actionType,
        'entity_type': e.entityType,
        'entity_id': e.entityId,
        'description': e.description,
        'timestamp': e.timestamp,
      };

  // ── Laptops ───────────────────────────────────────────────────────────────
  Future<int> insertLaptop(Laptop l) async {
    final id = await drift.into(drift.laptops).insert(_laptopToCompanion(l));
    notifyTableChanged('laptops');
    return id;
  }

  Future<List<Laptop>> getLaptops() async {
    final query = drift.select(drift.laptops)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.laptopNumber)]);
    final rows = await query.get();
    return rows.map(_laptopFromEntry).toList();
  }

  Stream<List<Laptop>> watchLaptops() {
    return _watchSwitchable(() {
      final query = drift.select(drift.laptops)
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.laptopNumber)]);
      return query.watch().map((rows) => rows.map(_laptopFromEntry).toList());
    });
  }

  Future<int> updateLaptop(Laptop l) async {
    final rows = await (drift.update(drift.laptops)..where((tbl) => tbl.id.equals(l.id!)))
        .write(_laptopToCompanion(l));
    notifyTableChanged('laptops');
    return rows;
  }

  Future<int> deleteLaptop(int id) async {
    final rows = await (drift.delete(drift.laptops)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('laptops');
    return rows;
  }

  // ── Network Devices ───────────────────────────────────────────────────────
  Future<int> insertNetworkDevice(NetworkDevice d) async {
    final id = await drift.into(drift.networkDevices).insert(_networkDeviceToCompanion(d));
    notifyTableChanged('network_devices');
    return id;
  }

  Future<List<NetworkDevice>> getNetworkDevices() async {
    final query = drift.select(drift.networkDevices)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceNumber)]);
    final rows = await query.get();
    return rows.map(_networkDeviceFromEntry).toList();
  }

  Stream<List<NetworkDevice>> watchNetworkDevices() {
    return _watchSwitchable(() {
      final query = drift.select(drift.networkDevices)
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceNumber)]);
      return query.watch().map((rows) => rows.map(_networkDeviceFromEntry).toList());
    });
  }

  Future<int> updateNetworkDevice(NetworkDevice d) async {
    final rows = await (drift.update(drift.networkDevices)..where((tbl) => tbl.id.equals(d.id!)))
        .write(_networkDeviceToCompanion(d));
    notifyTableChanged('network_devices');
    return rows;
  }

  Future<int> deleteNetworkDevice(int id) async {
    final rows = await (drift.delete(drift.networkDevices)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('network_devices');
    return rows;
  }

  Future<int> updateNetworkDeviceStatus(int id, String s) async {
    final rows = await (drift.update(drift.networkDevices)..where((tbl) => tbl.id.equals(id)))
        .write(NetworkDevicesCompanion(status: Value(s)));
    notifyTableChanged('network_devices');
    return rows;
  }

  // ── Printers ──────────────────────────────────────────────────────────────
  Future<int> insertPrinter(Printer p) async {
    final id = await drift.into(drift.printers).insert(_printerToCompanion(p));
    notifyTableChanged('printers');
    return id;
  }

  Future<List<Printer>> getPrinters() async {
    final query = drift.select(drift.printers)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.printerNumber)]);
    final rows = await query.get();
    return rows.map(_printerFromEntry).toList();
  }

  Future<int> updatePrinter(Printer p) async {
    final rows = await (drift.update(drift.printers)..where((tbl) => tbl.id.equals(p.id!)))
        .write(_printerToCompanion(p));
    notifyTableChanged('printers');
    return rows;
  }

  Future<int> deletePrinter(int id) async {
    final rows = await (drift.delete(drift.printers)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('printers');
    return rows;
  }

  // ── Electronics ───────────────────────────────────────────────────────────
  Future<int> insertElectronic(Electronic e) async {
    final id = await drift.into(drift.electronics).insert(_electronicToCompanion(e));
    notifyTableChanged('electronics');
    return id;
  }

  Future<List<Electronic>> getElectronics() async {
    final query = drift.select(drift.electronics)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceNumber)]);
    final rows = await query.get();
    return rows.map(_electronicFromEntry).toList();
  }

  Stream<List<Electronic>> watchElectronics() {
    return _watchSwitchable(() {
      final query = drift.select(drift.electronics)
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceNumber)]);
      return query.watch().map((rows) => rows.map(_electronicFromEntry).toList());
    });
  }

  Future<int> updateElectronic(Electronic e) async {
    final rows = await (drift.update(drift.electronics)..where((tbl) => tbl.id.equals(e.id!)))
        .write(_electronicToCompanion(e));
    notifyTableChanged('electronics');
    return rows;
  }

  Future<int> updateElectronicStatus(int id, String s) async {
    final rows = await (drift.update(drift.electronics)..where((tbl) => tbl.id.equals(id)))
        .write(ElectronicsCompanion(status: Value(s)));
    notifyTableChanged('electronics');
    return rows;
  }

  Future<bool> isDeviceBorrowed(String deviceType, int deviceId) async {
    final countExp = drift.borrowLogs.id.count();
    final query = drift.selectOnly(drift.borrowLogs)
      ..addColumns([countExp])
      ..where(drift.borrowLogs.deviceType.lower().equals(deviceType.toLowerCase()) &
          drift.borrowLogs.deviceId.equals(deviceId) &
          drift.borrowLogs.isReturned.equals(0));
    final row = await query.getSingle();
    return (row.read(countExp) ?? 0) > 0;
  }

  Future<int> getEmployeeActiveBorrowsCount(int employeeId) async {
    final countExp = drift.borrowLogs.id.count();
    final query = drift.selectOnly(drift.borrowLogs)
      ..addColumns([countExp])
      ..where(drift.borrowLogs.employeeId.equals(employeeId) &
          drift.borrowLogs.isReturned.equals(0));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<Map<String, int>> getEmployeeDependentCounts(int employeeId) async {
    final borrowCountExp = drift.borrowLogs.id.count();
    final emailCountExp = drift.emailAccounts.id.count();
    final logCountExp = drift.logEntries.id.count();

    // Check active borrows
    final borrowsRow = await (drift.selectOnly(drift.borrowLogs)
          ..addColumns([borrowCountExp])
          ..where(drift.borrowLogs.employeeId.equals(employeeId) &
              drift.borrowLogs.isReturned.equals(0)))
        .getSingle();

    // Check email accounts assigned
    final emailsRow = await (drift.selectOnly(drift.emailAccounts)
          ..addColumns([emailCountExp])
          ..where(drift.emailAccounts.employeeId.equals(employeeId)))
        .getSingle();

    // Check tickets logged
    final logsRow = await (drift.selectOnly(drift.logEntries)
          ..addColumns([logCountExp])
          ..where(drift.logEntries.employeeId.equals(employeeId)))
        .getSingle();

    // Check assigned laptops
    final emp = await (drift.select(drift.employees)..where((tbl) => tbl.id.equals(employeeId))).getSingleOrNull();
    int laptopsCount = 0;
    if (emp != null && emp.name.isNotEmpty) {
      final laptopCountExp = drift.laptops.id.count();
      final lRow = await (drift.selectOnly(drift.laptops)
            ..addColumns([laptopCountExp])
            ..where(drift.laptops.user.lower().equals(emp.name.toLowerCase())))
          .getSingle();
      laptopsCount = lRow.read(laptopCountExp) ?? 0;
    }

    return {
      'active_borrows': borrowsRow.read(borrowCountExp) ?? 0,
      'emails': emailsRow.read(emailCountExp) ?? 0,
      'tickets': logsRow.read(logCountExp) ?? 0,
      'laptops': laptopsCount,
    };
  }

  Future<int> deleteElectronic(int id) async {
    if (await isDeviceBorrowed('electronic', id)) {
      throw StateError(
          'Cannot delete electronic device while it is actively borrowed. Please mark it returned first.');
    }
    final rows = await (drift.delete(drift.electronics)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('electronics');
    return rows;
  }

  // ── Employees ─────────────────────────────────────────────────────────────
  Future<int> insertEmployee(Employee e) async {
    final id = await drift.into(drift.employees).insert(_employeeToCompanion(e));
    notifyTableChanged('employees');
    return id;
  }

  Future<List<Employee>> getEmployees() async {
    final query = drift.select(drift.employees)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);
    final rows = await query.get();
    return rows.map(_employeeFromEntry).toList();
  }

  Stream<List<Employee>> watchEmployees({String? search}) {
    return _watchSwitchable(() {
      final query = drift.select(drift.employees);
      if (search != null && search.trim().isNotEmpty) {
        final term = '%${search.trim().toLowerCase()}%';
        query.where((tbl) => tbl.name.lower().like(term) | tbl.phoneNumber.like(term));
      }
      query.orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);
      return query.watch().map((rows) => rows.map(_employeeFromEntry).toList());
    });
  }

  /// Updates an employee and cascades any name changes to laptops.user,
  /// email_accounts.employee_name, borrow_logs.employee_name, and log_entries.employee_name.
  Future<int> updateEmployee(Employee e) async {
    return await drift.transaction(() async {
      final oldEmp = await (drift.select(drift.employees)..where((tbl) => tbl.id.equals(e.id!)))
          .getSingleOrNull();
      final oldName = oldEmp?.name ?? '';

      final rows = await (drift.update(drift.employees)..where((tbl) => tbl.id.equals(e.id!)))
          .write(_employeeToCompanion(e));

      if (oldName.isNotEmpty && oldName != e.name) {
        // Cascade to assigned laptops
        await (drift.update(drift.laptops)..where((tbl) => tbl.user.equals(oldName)))
            .write(LaptopsCompanion(user: Value(e.name)));

        // Cascade to linked email accounts
        await (drift.update(drift.emailAccounts)
              ..where((tbl) => tbl.employeeId.equals(e.id!) | tbl.employeeName.equals(oldName)))
            .write(EmailAccountsCompanion(employeeName: Value(e.name)));

        // Cascade to borrow logs
        await (drift.update(drift.borrowLogs)
              ..where((tbl) => tbl.employeeId.equals(e.id!) | tbl.employeeName.equals(oldName)))
            .write(BorrowLogsCompanion(employeeName: Value(e.name)));

        // Cascade to log entries
        await (drift.update(drift.logEntries)
              ..where((tbl) => tbl.employeeId.equals(e.id!) | tbl.employeeName.equals(oldName)))
            .write(LogEntriesCompanion(employeeName: Value(e.name)));

        notifyTableChanged('laptops');
        notifyTableChanged('email_accounts');
        notifyTableChanged('borrow_logs');
        notifyTableChanged('log_entries');
      }

      notifyTableChanged('employees');
      return rows;
    });
  }

  /// Deletes an employee only if they have no active borrows, assigned laptops, or linked email accounts.
  Future<int> deleteEmployee(int id) async {
    final deps = await getEmployeeDependentCounts(id);
    final activeBorrows = deps['active_borrows'] ?? 0;
    final laptops = deps['laptops'] ?? 0;
    final emails = deps['emails'] ?? 0;

    if (activeBorrows > 0) {
      throw StateError('Cannot delete employee while they have active borrowed devices.');
    }
    if (laptops > 0) {
      throw StateError('Cannot delete employee while they have assigned laptops. Unassign laptop(s) first.');
    }
    if (emails > 0) {
      throw StateError('Cannot delete employee while linked to active email accounts. Unlink email(s) first.');
    }

    final rows = await (drift.delete(drift.employees)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('employees');
    return rows;
  }

  // ── MiFis ─────────────────────────────────────────────────────────────────
  Future<int> insertMiFi(MiFi m) async {
    final id = await drift.into(drift.mifis).insert(_mifiToCompanion(m));
    notifyTableChanged('mifis');
    return id;
  }

  Future<List<MiFi>> getMiFis() async {
    final query = drift.select(drift.mifis)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceNumber)]);
    final rows = await query.get();
    return rows.map(_mifiFromEntry).toList();
  }

  Stream<List<MiFi>> watchMiFis() {
    return _watchSwitchable(() {
      final query = drift.select(drift.mifis)
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceNumber)]);
      return query.watch().map((rows) => rows.map(_mifiFromEntry).toList());
    });
  }

  Future<int> updateMiFi(MiFi m) async {
    final rows = await (drift.update(drift.mifis)..where((tbl) => tbl.id.equals(m.id!)))
        .write(_mifiToCompanion(m));
    notifyTableChanged('mifis');
    return rows;
  }

  Future<int> updateMiFiStatus(int id, String s) async {
    final rows = await (drift.update(drift.mifis)..where((tbl) => tbl.id.equals(id)))
        .write(MifisCompanion(status: Value(s)));
    notifyTableChanged('mifis');
    return rows;
  }

  Future<int> deleteMiFi(int id) async {
    if (await isDeviceBorrowed('mifi', id)) {
      throw StateError(
          'Cannot delete MiFi device while it is actively borrowed. Please mark it returned first.');
    }
    final rows = await (drift.delete(drift.mifis)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('mifis');
    return rows;
  }

  // ── Borrow Logs ───────────────────────────────────────────────────────────
  Future<int> insertBorrowLog(BorrowLog log) async {
    return await drift.transaction(() async {
      final id = await drift.into(drift.borrowLogs).insert(_borrowLogToCompanion(log));
      if (!log.isReturned) {
        switch (log.deviceType.toLowerCase()) {
          case 'electronic':
            await updateElectronicStatus(log.deviceId, 'Borrowed');
          case 'mifi':
            await updateMiFiStatus(log.deviceId, 'Borrowed');
        }
      }
      notifyTableChanged('borrow_logs');
      return id;
    });
  }

  Future<int> updateBorrowLog(int logId, BorrowLog newLog) async {
    return await drift.transaction(() async {
      final oldRow = await (drift.select(drift.borrowLogs)..where((tbl) => tbl.id.equals(logId)))
          .getSingleOrNull();
      if (oldRow == null) {
        return 0;
      }

      final oldLog = _borrowLogFromEntry(oldRow);

      await (drift.update(drift.borrowLogs)..where((tbl) => tbl.id.equals(logId)))
          .write(_borrowLogToCompanion(newLog).copyWith(id: Value(logId)));
      notifyTableChanged('borrow_logs');

      final deviceChanged = oldLog.deviceType.toLowerCase() != newLog.deviceType.toLowerCase() ||
          oldLog.deviceId != newLog.deviceId;
      final returnStatusChanged = oldLog.isReturned != newLog.isReturned;

      if (deviceChanged) {
        if (!oldLog.isReturned) {
          final remainingOld = await (drift.select(drift.borrowLogs)
                ..where((tbl) =>
                    tbl.deviceType.lower().equals(oldLog.deviceType.toLowerCase()) &
                    tbl.deviceId.equals(oldLog.deviceId) &
                    tbl.isReturned.equals(0) &
                    tbl.id.equals(logId).not()))
              .get();
          if (remainingOld.isEmpty) {
            if (oldLog.deviceType.toLowerCase() == 'electronic') {
              await updateElectronicStatus(oldLog.deviceId, 'Available');
            } else if (oldLog.deviceType.toLowerCase() == 'mifi') {
              await updateMiFiStatus(oldLog.deviceId, 'Available');
            }
          }
        }

        if (!newLog.isReturned) {
          if (newLog.deviceType.toLowerCase() == 'electronic') {
            await updateElectronicStatus(newLog.deviceId, 'Borrowed');
          } else if (newLog.deviceType.toLowerCase() == 'mifi') {
            await updateMiFiStatus(newLog.deviceId, 'Borrowed');
          }
        }
      } else if (returnStatusChanged) {
        if (newLog.isReturned) {
          final remainingActive = await (drift.select(drift.borrowLogs)
                ..where((tbl) =>
                    tbl.deviceType.lower().equals(newLog.deviceType.toLowerCase()) &
                    tbl.deviceId.equals(newLog.deviceId) &
                    tbl.isReturned.equals(0) &
                    tbl.id.equals(logId).not()))
              .get();
          if (remainingActive.isEmpty) {
            if (newLog.deviceType.toLowerCase() == 'electronic') {
              await updateElectronicStatus(newLog.deviceId, 'Available');
            } else if (newLog.deviceType.toLowerCase() == 'mifi') {
              await updateMiFiStatus(newLog.deviceId, 'Available');
            }
          }
        } else {
          if (newLog.deviceType.toLowerCase() == 'electronic') {
            await updateElectronicStatus(newLog.deviceId, 'Borrowed');
          } else if (newLog.deviceType.toLowerCase() == 'mifi') {
            await updateMiFiStatus(newLog.deviceId, 'Borrowed');
          }
        }
      }

      return 1;
    });
  }

  Future<List<BorrowLog>> getBorrowLogs({bool? activeOnly}) async {
    final query = drift.select(drift.borrowLogs);
    if (activeOnly == true) {
      query.where((tbl) => tbl.isReturned.equals(0));
    }
    query.orderBy([
      (tbl) => OrderingTerm.asc(tbl.isReturned),
      (tbl) => OrderingTerm.desc(tbl.id),
    ]);
    final rows = await query.get();
    return rows.map(_borrowLogFromEntry).toList();
  }

  Stream<List<BorrowLog>> watchBorrowLogs({bool? activeOnly}) {
    return _watchSwitchable(() {
      final query = drift.select(drift.borrowLogs);
      if (activeOnly == true) {
        query.where((tbl) => tbl.isReturned.equals(0));
      }
      query.orderBy([
        (tbl) => OrderingTerm.asc(tbl.isReturned),
        (tbl) => OrderingTerm.desc(tbl.id),
      ]);
      return query.watch().map((rows) => rows.map(_borrowLogFromEntry).toList());
    });
  }

  Future<void> markReturned(
      int logId, int deviceId, String deviceType, String backDate) async {
    await drift.transaction(() async {
      await (drift.update(drift.borrowLogs)..where((tbl) => tbl.id.equals(logId))).write(
        BorrowLogsCompanion(
          isReturned: const Value(1),
          backDate: Value(backDate),
        ),
      );
      notifyTableChanged('borrow_logs');

      final remaining = await (drift.select(drift.borrowLogs)
            ..where((tbl) =>
                tbl.deviceType.lower().equals(deviceType.toLowerCase()) &
                tbl.deviceId.equals(deviceId) &
                tbl.isReturned.equals(0)))
          .get();
      if (remaining.isEmpty) {
        switch (deviceType.toLowerCase()) {
          case 'electronic':
            await updateElectronicStatus(deviceId, 'Available');
          case 'mifi':
            await updateMiFiStatus(deviceId, 'Available');
        }
      }
    });
    await NotificationService().cancelReminder(logId);
  }

  Future<int> deleteBorrowLog(int id) async {
    final res = await drift.transaction(() async {
      final logRow = await (drift.select(drift.borrowLogs)..where((tbl) => tbl.id.equals(id)))
          .getSingleOrNull();

      if (logRow != null) {
        final log = _borrowLogFromEntry(logRow);
        final count =
            await (drift.delete(drift.borrowLogs)..where((tbl) => tbl.id.equals(id))).go();
        notifyTableChanged('borrow_logs');

        if (!log.isReturned) {
          final remaining = await (drift.select(drift.borrowLogs)
                ..where((tbl) =>
                    tbl.deviceType.lower().equals(log.deviceType.toLowerCase()) &
                    tbl.deviceId.equals(log.deviceId) &
                    tbl.isReturned.equals(0)))
              .get();

          if (remaining.isEmpty) {
            if (log.deviceType.toLowerCase() == 'electronic') {
              await updateElectronicStatus(log.deviceId, 'Available');
            } else if (log.deviceType.toLowerCase() == 'mifi') {
              await updateMiFiStatus(log.deviceId, 'Available');
            }
          }
        }
        return count;
      }
      final count =
          await (drift.delete(drift.borrowLogs)..where((tbl) => tbl.id.equals(id))).go();
      notifyTableChanged('borrow_logs');
      return count;
    });
    await NotificationService().cancelReminder(id);
    return res;
  }

  Future<void> syncDeviceStatuses() async {
    await drift.transaction(() async {
      final activeMifiQuery = drift.selectOnly(drift.borrowLogs)
        ..addColumns([drift.borrowLogs.deviceId])
        ..where(drift.borrowLogs.deviceType.lower().equals('mifi') &
            drift.borrowLogs.isReturned.equals(0));
      final activeMifiRows = await activeMifiQuery.get();
      final activeMifiIds =
          activeMifiRows.map((r) => r.read(drift.borrowLogs.deviceId)!).toSet();

      final activeElecQuery = drift.selectOnly(drift.borrowLogs)
        ..addColumns([drift.borrowLogs.deviceId])
        ..where(drift.borrowLogs.deviceType.lower().equals('electronic') &
            drift.borrowLogs.isReturned.equals(0));
      final activeElecRows = await activeElecQuery.get();
      final activeElecIds =
          activeElecRows.map((r) => r.read(drift.borrowLogs.deviceId)!).toSet();

      // Update Mifis
      if (activeMifiIds.isEmpty) {
        await (drift.update(drift.mifis)..where((tbl) => tbl.status.equals('Borrowed')))
            .write(const MifisCompanion(status: Value('Available')));
      } else {
        await (drift.update(drift.mifis)
              ..where((tbl) => tbl.status.equals('Borrowed') & tbl.id.isNotIn(activeMifiIds)))
            .write(const MifisCompanion(status: Value('Available')));
        await (drift.update(drift.mifis)
              ..where((tbl) => tbl.status.equals('Borrowed').not() & tbl.id.isIn(activeMifiIds)))
            .write(const MifisCompanion(status: Value('Borrowed')));
      }

      // Update Electronics
      if (activeElecIds.isEmpty) {
        await (drift.update(drift.electronics)..where((tbl) => tbl.status.equals('Borrowed')))
            .write(const ElectronicsCompanion(status: Value('Available')));
      } else {
        await (drift.update(drift.electronics)
              ..where((tbl) => tbl.status.equals('Borrowed') & tbl.id.isNotIn(activeElecIds)))
            .write(const ElectronicsCompanion(status: Value('Available')));
        await (drift.update(drift.electronics)
              ..where((tbl) => tbl.status.equals('Borrowed').not() & tbl.id.isIn(activeElecIds)))
            .write(const ElectronicsCompanion(status: Value('Borrowed')));
      }
    });
    notifyTableChanged('mifis');
    notifyTableChanged('electronics');
  }

  // ── Expenses ──────────────────────────────────────────────────────────────
  Future<int> insertExpense(Expense e) async {
    final id = await drift.into(drift.expenses).insert(_expenseToCompanion(e));
    notifyTableChanged('expenses');
    return id;
  }

  Future<List<Expense>> getExpenses({int? year, int? month}) async {
    final query = drift.select(drift.expenses);
    if (year != null) {
      if (month != null) {
        final prefix = '$year-${month.toString().padLeft(2, '0')}';
        query.where((tbl) => tbl.date.like('$prefix%'));
      } else {
        query.where((tbl) => tbl.date.like('$year%'));
      }
    }
    query.orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
    final rows = await query.get();
    return rows.map(_expenseFromEntry).toList();
  }

  Future<int> updateExpense(Expense e) async {
    final rows = await (drift.update(drift.expenses)..where((tbl) => tbl.id.equals(e.id!)))
        .write(_expenseToCompanion(e));
    notifyTableChanged('expenses');
    return rows;
  }

  Future<int> deleteExpense(int id) async {
    final rows = await (drift.delete(drift.expenses)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('expenses');
    return rows;
  }

  Future<List<Expense>> getExpensesByYear(int year) async {
    final query = drift.select(drift.expenses)
      ..where((tbl) => tbl.date.like('$year%'))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]);
    final rows = await query.get();
    return rows.map(_expenseFromEntry).toList();
  }

  Future<List<int>> getExpenseYears() async {
    final yearExp = drift.expenses.date.substr(1, 4);
    final query = drift.selectOnly(drift.expenses, distinct: true)
      ..addColumns([yearExp])
      ..orderBy([OrderingTerm.desc(yearExp)]);
    final rows = await query.get();
    return rows
        .map((r) => int.tryParse(r.read(yearExp) ?? '') ?? 0)
        .where((y) => y > 0)
        .toList();
  }

  Future<double> getTotalExpenses({int? year, int? month}) async {
    final sumExp = drift.expenses.price.sum();
    final query = drift.selectOnly(drift.expenses)..addColumns([sumExp]);
    if (year != null) {
      if (month != null) {
        final prefix = '$year-${month.toString().padLeft(2, '0')}';
        query.where(drift.expenses.date.like('$prefix%'));
      } else {
        query.where(drift.expenses.date.like('$year%'));
      }
    }
    final row = await query.getSingle();
    return row.read(sumExp) ?? 0.0;
  }

  Stream<double> watchTotalExpenses({int? year, int? month}) {
    return _watchSwitchable(() {
      final sumExp = drift.expenses.price.sum();
      final query = drift.selectOnly(drift.expenses)..addColumns([sumExp]);
      if (year != null) {
        if (month != null) {
          final prefix = '$year-${month.toString().padLeft(2, '0')}';
          query.where(drift.expenses.date.like('$prefix%'));
        } else {
          query.where(drift.expenses.date.like('$year%'));
        }
      }
      return query.watchSingle().map((row) => row.read(sumExp) ?? 0.0);
    });
  }

  // ── Bills ─────────────────────────────────────────────────────────────────
  Future<int> insertBill(Bill b) async {
    final id = await drift.into(drift.bills).insert(_billToCompanion(b));
    notifyTableChanged('bills');
    return id;
  }

  Future<List<Bill>> getBills() async {
    final query = drift.select(drift.bills)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.person)]);
    final rows = await query.get();
    return rows.map(_billFromEntry).toList();
  }

  Future<int> updateBill(Bill b) async {
    final rows = await (drift.update(drift.bills)..where((tbl) => tbl.id.equals(b.id!)))
        .write(_billToCompanion(b));
    notifyTableChanged('bills');
    return rows;
  }

  Future<int> deleteBill(int id) async {
    final rows = await (drift.delete(drift.bills)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('bills');
    return rows;
  }

  Future<double> getTotalBills() async {
    final sumExp = drift.bills.price.sum();
    final query = drift.selectOnly(drift.bills)..addColumns([sumExp]);
    final row = await query.getSingle();
    return row.read(sumExp) ?? 0.0;
  }

  Stream<double> watchTotalBills() {
    return _watchSwitchable(() {
      final sumExp = drift.bills.price.sum();
      final query = drift.selectOnly(drift.bills)..addColumns([sumExp]);
      return query.watchSingle().map((row) => row.read(sumExp) ?? 0.0);
    });
  }

  // ── Email Accounts ────────────────────────────────────────────────────────
  Future<int> insertEmailAccount(EmailAccount a) async {
    final id = await drift.into(drift.emailAccounts).insert(_emailAccountToCompanion(a));
    notifyTableChanged('email_accounts');
    return id;
  }

  Future<List<EmailAccount>> getEmailAccounts() async {
    final query = drift.select(drift.emailAccounts)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.email)]);
    final rows = await query.get();
    return rows.map(_emailAccountFromEntry).toList();
  }

  Future<int> updateEmailAccount(EmailAccount a) async {
    final rows = await (drift.update(drift.emailAccounts)..where((tbl) => tbl.id.equals(a.id!)))
        .write(_emailAccountToCompanion(a));
    notifyTableChanged('email_accounts');
    return rows;
  }

  Future<int> deleteEmailAccount(int id) async {
    final rows = await (drift.delete(drift.emailAccounts)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('email_accounts');
    return rows;
  }

  // ── Log Entries ───────────────────────────────────────────────────────────
  Future<int> insertLogEntry(LogEntry l) async {
    final id = await drift.into(drift.logEntries).insert(_logEntryToCompanion(l));
    notifyTableChanged('log_entries');
    return id;
  }

  Future<List<LogEntry>> getLogEntries({String? stateFilter, int? year, int? month}) async {
    final query = drift.select(drift.logEntries);
    if (stateFilter != null && stateFilter != 'All') {
      query.where((tbl) => tbl.state.lower().equals(stateFilter.toLowerCase()));
    }
    if (year != null) {
      if (month != null) {
        final prefix = '$year-${month.toString().padLeft(2, '0')}';
        query.where((tbl) => tbl.date.like('$prefix%'));
      } else {
        query.where((tbl) => tbl.date.like('$year%'));
      }
    }
    query.orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
    final rows = await query.get();
    return rows.map(_logEntryFromEntry).toList();
  }

  Stream<List<LogEntry>> watchLogEntries({String? stateFilter, int? year, int? month}) {
    return _watchSwitchable(() {
      final query = drift.select(drift.logEntries);
      if (stateFilter != null && stateFilter != 'All') {
        query.where((tbl) => tbl.state.lower().equals(stateFilter.toLowerCase()));
      }
      if (year != null) {
        if (month != null) {
          final prefix = '$year-${month.toString().padLeft(2, '0')}';
          query.where((tbl) => tbl.date.like('$prefix%'));
        } else {
          query.where((tbl) => tbl.date.like('$year%'));
        }
      }
      query.orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
      return query.watch().map((rows) => rows.map(_logEntryFromEntry).toList());
    });
  }

  Future<List<LogEntry>> getLogEntriesByYear(int year) async {
    return getLogEntries(year: year);
  }

  Future<List<LogEntry>> getLogEntriesByMonth(int year, int month) async {
    return getLogEntries(year: year, month: month);
  }

  Future<List<LogEntry>> getOpenLogEntries() async {
    final query = drift.select(drift.logEntries)
      ..where((tbl) => tbl.state.lower().equals('open'))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
    final rows = await query.get();
    return rows.map(_logEntryFromEntry).toList();
  }

  Future<int> updateLogEntry(LogEntry l) async {
    final rows = await (drift.update(drift.logEntries)..where((tbl) => tbl.id.equals(l.id!)))
        .write(_logEntryToCompanion(l));
    notifyTableChanged('log_entries');
    return rows;
  }

  Future<int> deleteLogEntry(int id) async {
    final rows = await (drift.delete(drift.logEntries)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('log_entries');
    return rows;
  }

  Future<List<int>> getLogYears() async {
    final yearExp = drift.logEntries.date.substr(1, 4);
    final query = drift.selectOnly(drift.logEntries, distinct: true)
      ..addColumns([yearExp])
      ..orderBy([OrderingTerm.desc(yearExp)]);
    final rows = await query.get();
    return rows
        .map((r) => int.tryParse(r.read(yearExp) ?? '') ?? 0)
        .where((y) => y > 0)
        .toList();
  }

  // ── Subscriptions ─────────────────────────────────────────────────────────
  Future<int> insertSubscription(Subscription s) async {
    final id = await drift.into(drift.subscriptions).insert(_subscriptionToCompanion(s));
    notifyTableChanged('subscriptions');
    return id;
  }

  Future<List<Subscription>> getSubscriptions() async {
    final query = drift.select(drift.subscriptions)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.service)]);
    final rows = await query.get();
    return rows.map(_subscriptionFromEntry).toList();
  }

  Future<int> updateSubscription(Subscription s) async {
    final rows = await (drift.update(drift.subscriptions)..where((tbl) => tbl.id.equals(s.id!)))
        .write(_subscriptionToCompanion(s));
    notifyTableChanged('subscriptions');
    return rows;
  }

  Future<int> deleteSubscription(int id) async {
    final rows = await (drift.delete(drift.subscriptions)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('subscriptions');
    return rows;
  }

  // ── Access Points ─────────────────────────────────────────────────────────
  Future<int> insertAccessPoint(AccessPoint a) async {
    final id = await drift.into(drift.accessPoints).insert(_accessPointToCompanion(a));
    notifyTableChanged('access_points');
    return id;
  }

  Future<List<AccessPoint>> getAccessPoints() async {
    final query = drift.select(drift.accessPoints)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceNumber)]);
    final rows = await query.get();
    return rows.map(_accessPointFromEntry).toList();
  }

  Future<int> updateAccessPoint(AccessPoint a) async {
    final rows = await (drift.update(drift.accessPoints)..where((tbl) => tbl.id.equals(a.id!)))
        .write(_accessPointToCompanion(a));
    notifyTableChanged('access_points');
    return rows;
  }

  Future<int> deleteAccessPoint(int id) async {
    final rows = await (drift.delete(drift.accessPoints)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('access_points');
    return rows;
  }

  // ── Wi-Fi Networks (Credentials Vault) ────────────────────────────────────
  Future<int> insertWifiNetwork(WifiNetwork w) async {
    final id = await drift.into(drift.wifiNetworks).insert(_wifiNetworkToCompanion(w));
    notifyTableChanged('wifi_networks');
    return id;
  }

  Future<List<WifiNetwork>> getWifiNetworks() async {
    final query = drift.select(drift.wifiNetworks)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.networkName)]);
    final rows = await query.get();
    return rows.map(_wifiNetworkFromEntry).toList();
  }

  Future<int> updateWifiNetwork(WifiNetwork w) async {
    final rows = await (drift.update(drift.wifiNetworks)..where((tbl) => tbl.id.equals(w.id!)))
        .write(_wifiNetworkToCompanion(w));
    notifyTableChanged('wifi_networks');
    return rows;
  }

  Future<int> deleteWifiNetwork(int id) async {
    final rows = await (drift.delete(drift.wifiNetworks)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('wifi_networks');
    return rows;
  }

  // ── Account Passwords (Credentials Vault) ─────────────────────────────────
  Future<int> insertAccountPassword(AccountPassword a) async {
    final id = await drift.into(drift.accountPasswords).insert(_accountPasswordToCompanion(a));
    notifyTableChanged('account_passwords');
    return id;
  }

  Future<List<AccountPassword>> getAccountPasswords() async {
    final query = drift.select(drift.accountPasswords)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.platform)]);
    final rows = await query.get();
    return rows.map(_accountPasswordFromEntry).toList();
  }

  Future<int> updateAccountPassword(AccountPassword a) async {
    final rows = await (drift.update(drift.accountPasswords)..where((tbl) => tbl.id.equals(a.id!)))
        .write(_accountPasswordToCompanion(a));
    notifyTableChanged('account_passwords');
    return rows;
  }

  Future<int> deleteAccountPassword(int id) async {
    final rows = await (drift.delete(drift.accountPasswords)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('account_passwords');
    return rows;
  }

  // ── Other Devices ─────────────────────────────────────────────────────────
  Future<int> insertOtherDevice(OtherDevice d) async {
    final id = await drift.into(drift.otherDevices).insert(_otherDeviceToCompanion(d));
    notifyTableChanged('other_devices');
    return id;
  }

  Future<List<OtherDevice>> getOtherDevices() async {
    final query = drift.select(drift.otherDevices)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceName)]);
    final rows = await query.get();
    return rows.map(_otherDeviceFromEntry).toList();
  }

  Future<int> updateOtherDevice(OtherDevice d) async {
    final rows = await (drift.update(drift.otherDevices)..where((tbl) => tbl.id.equals(d.id!)))
        .write(_otherDeviceToCompanion(d));
    notifyTableChanged('other_devices');
    return rows;
  }

  Future<int> deleteOtherDevice(int id) async {
    final rows = await (drift.delete(drift.otherDevices)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('other_devices');
    return rows;
  }

  // ── Vendor Contacts (IT Runbook) ──────────────────────────────────────────
  Future<int> insertVendorContact(VendorContact v) async {
    final id = await drift.into(drift.vendorContacts).insert(_vendorContactToCompanion(v));
    notifyTableChanged('vendor_contacts');
    return id;
  }

  Future<List<VendorContact>> getVendorContacts({String? contactType}) async {
    final query = drift.select(drift.vendorContacts);
    if (contactType != null && contactType.isNotEmpty && contactType != 'All') {
      query.where((tbl) => tbl.contactType.equals(contactType));
    }
    query.orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);
    final rows = await query.get();
    return rows.map(_vendorContactFromEntry).toList();
  }

  Future<int> updateVendorContact(VendorContact v) async {
    final rows = await (drift.update(drift.vendorContacts)..where((tbl) => tbl.id.equals(v.id!)))
        .write(_vendorContactToCompanion(v));
    notifyTableChanged('vendor_contacts');
    return rows;
  }

  Future<int> deleteVendorContact(int id) async {
    final rows = await (drift.delete(drift.vendorContacts)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('vendor_contacts');
    return rows;
  }

  // ── Maintenance Logs ───────────────────────────────────────────────────────
  Future<int> insertMaintenanceLog(Map<String, dynamic> log) async {
    final id = await drift.into(drift.deviceMaintenanceLogs).insert(_maintenanceLogToCompanion(log));
    notifyTableChanged('device_maintenance_logs');
    return id;
  }

  Future<List<Map<String, dynamic>>> getMaintenanceLogsForDevice(
      String deviceType, int deviceId) async {
    final query = drift.select(drift.deviceMaintenanceLogs)
      ..where((tbl) => tbl.deviceType.equals(deviceType) & tbl.deviceId.equals(deviceId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
    final rows = await query.get();
    return rows.map(_maintenanceEntryToMap).toList();
  }

  /// Retrieve all maintenance logs across all devices (useful for maintenance calendar & schedules).
  Future<List<Map<String, dynamic>>> getAllMaintenanceLogs() async {
    final query = drift.select(drift.deviceMaintenanceLogs)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
    final rows = await query.get();
    return rows.map(_maintenanceEntryToMap).toList();
  }

  Future<int> deleteMaintenanceLog(int id) async {
    final rows = await (drift.delete(drift.deviceMaintenanceLogs)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('device_maintenance_logs');
    return rows;
  }

  // ── Static IPs (IPAM) ─────────────────────────────────────────────────────
  Future<int> insertStaticIp(Map<String, dynamic> ip) async {
    final id = await drift.into(drift.staticIps).insert(_staticIpToCompanion(ip));
    notifyTableChanged('static_ips');
    return id;
  }

  Future<List<Map<String, dynamic>>> getStaticIps() async {
    final query = drift.select(drift.staticIps)..orderBy([(tbl) => OrderingTerm.asc(tbl.ipAddress)]);
    final rows = await query.get();
    return rows.map(_staticIpEntryToMap).toList();
  }

  Future<int> updateStaticIp(Map<String, dynamic> ip, int id) async {
    final rows = await (drift.update(drift.staticIps)..where((tbl) => tbl.id.equals(id)))
        .write(_staticIpToCompanion(ip));
    notifyTableChanged('static_ips');
    return rows;
  }

  Future<int> deleteStaticIp(int id) async {
    final rows = await (drift.delete(drift.staticIps)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('static_ips');
    return rows;
  }

  // ── Switch Patch Ports ────────────────────────────────────────────────────
  Future<int> insertSwitchPatchPort(Map<String, dynamic> port) async {
    final id = await drift.into(drift.switchPatchPorts).insert(_switchPatchPortToCompanion(port));
    notifyTableChanged('switch_patch_ports');
    return id;
  }

  Future<List<Map<String, dynamic>>> getSwitchPatchPorts(int switchDeviceId) async {
    final query = drift.select(drift.switchPatchPorts)
      ..where((tbl) => tbl.switchDeviceId.equals(switchDeviceId))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.portNumber)]);
    final rows = await query.get();
    return rows.map(_switchPatchPortEntryToMap).toList();
  }

  Future<int> updateSwitchPatchPort(Map<String, dynamic> port, int id) async {
    final rows = await (drift.update(drift.switchPatchPorts)..where((tbl) => tbl.id.equals(id)))
        .write(_switchPatchPortToCompanion(port));
    notifyTableChanged('switch_patch_ports');
    return rows;
  }

  Future<int> deleteSwitchPatchPort(int id) async {
    final rows = await (drift.delete(drift.switchPatchPorts)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('switch_patch_ports');
    return rows;
  }

  Future<int> deleteSwitchPatchPortsForSwitch(int switchId) async {
    final rows = await (drift.delete(drift.switchPatchPorts)..where((tbl) => tbl.switchDeviceId.equals(switchId))).go();
    notifyTableChanged('switch_patch_ports');
    return rows;
  }

  // ── Audit Activities ──────────────────────────────────────────────────────
  Future<int> logAuditActivity(
    String actionType,
    String entityType, {
    int? entityId,
    required String description,
  }) async {
    final id = await drift.into(drift.auditActivities).insert(
          AuditActivitiesCompanion(
            actionType: Value(actionType),
            entityType: Value(entityType),
            entityId: entityId != null ? Value(entityId) : const Value.absent(),
            description: Value(description),
            timestamp: Value(DateTime.now().toIso8601String()),
          ),
        );
    notifyTableChanged('audit_activities');
    return id;
  }

  Future<List<Map<String, dynamic>>> getAuditActivities({int limit = 100}) async {
    final query = drift.select(drift.auditActivities)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(_auditActivityEntryToMap).toList();
  }

  Future<int> clearAuditActivities() async {
    final count = await drift.delete(drift.auditActivities).go();
    notifyTableChanged('audit_activities');
    return count;
  }

  // ── Backup / Restore (Schema v15: 21 Lockstep Tables) ──────────────────────
  static const List<String> _allBackupTables = [
    'laptops',
    'network_devices',
    'printers',
    'electronics',
    'employees',
    'borrow_logs',
    'mifis',
    'expenses',
    'bills',
    'email_accounts',
    'log_entries',
    'subscriptions',
    'access_points',
    'wifi_networks',
    'account_passwords',
    'other_devices',
    'static_ips',
    'switch_patch_ports',
    'device_maintenance_logs',
    'vendor_contacts',
    'audit_activities',
  ];

  static const Map<String, List<String>> restoreDependencyGroups = {
    'borrow_logs': ['employees', 'mifis', 'electronics'],
    'device_maintenance_logs': ['laptops', 'network_devices', 'printers', 'electronics', 'mifis'],
  };

  /// Exports an offline backup JSON payload containing all 21 tables,
  /// embedded company logo image, complete theme preferences, table manifest,
  /// and SHA-256 integrity checksum. Optionally encrypts the output with AES-256-GCM.
  Future<String> exportJson({String? passphrase}) async {
    final prefs = await SharedPreferences.getInstance();
    final chassisJson = prefs.getString('custom_switch_patch_chassis_v1') ?? '';

    // Encode company logo file to base64 if present
    String logoBase64 = '';
    String logoExt = 'png';
    if (CompanyService().hasLogo) {
      final logoFile = File(CompanyService().logoPath);
      if (logoFile.existsSync()) {
        try {
          final bytes = await logoFile.readAsBytes();
          logoBase64 = base64Encode(bytes);
          logoExt = logoFile.path.split('.').last;
        } catch (_) {}
      }
    }

    final tableManifest = <String, int>{};
    final tableData = <String, dynamic>{};

    for (final t in _allBackupTables) {
      final rows = await query(t);
      tableData[t] = rows;
      tableManifest[t] = rows.length;
    }

    final payload = <String, dynamic>{
      'version': AppDatabase.currentVersion,
      'app_version': '1.1.0+5',
      'exported_at': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
      'company_name': CompanyService().name,
      'manifest': tableManifest,
      'prefs': {
        'custom_switch_patch_chassis_v1': chassisJson,
        'company_logo_base64': logoBase64,
        'company_logo_ext': logoExt,
        'themeMode': ThemeService().themeMode,
        'themeSeed': ThemeService().themeSeed,
        'appFont': ThemeService().appFont,
        'amoledSurfaces': ThemeService().amoledSurfaces,
        'dynamicColorEnabled': ThemeService().dynamicColorEnabled,
      },
      ...tableData,
    };

    // Calculate integrity checksum over canonical json content
    final rawJson = jsonEncode(payload);
    final sha256 = BackupCryptoService().computeSha256(rawJson);
    payload['sha256'] = sha256;

    final finalPlaintext = jsonEncode(payload);

    if (passphrase != null && passphrase.trim().isNotEmpty) {
      return await BackupCryptoService().encryptBackup(finalPlaintext, passphrase.trim());
    }

    return finalPlaintext;
  }

  /// Inspects and validates a backup string (plaintext JSON or AES-encrypted envelope)
  /// without mutating the database, returning a structured summary.
  Future<BackupManifestSummary> inspectBackupJson(String rawJson, {String? passphrase}) async {
    final crypto = BackupCryptoService();
    final isEnc = crypto.isEncryptedBackup(rawJson);
    String jsonStr = rawJson;

    if (isEnc) {
      if (passphrase == null || passphrase.isEmpty) {
        return const BackupManifestSummary(
          schemaVersion: 0,
          appVersion: '',
          exportedAt: '',
          companyName: '',
          tableCounts: {},
          hasLogo: false,
          hasThemePrefs: false,
          isEncrypted: true,
          isValid: false,
          validationError: 'Backup is encrypted. Passphrase required.',
        );
      }
      try {
        jsonStr = await crypto.decryptBackup(rawJson, passphrase);
      } catch (e) {
        return const BackupManifestSummary(
          schemaVersion: 0,
          appVersion: '',
          exportedAt: '',
          companyName: '',
          tableCounts: {},
          hasLogo: false,
          hasThemePrefs: false,
          isEncrypted: true,
          isValid: false,
          validationError: 'Incorrect password or corrupted encrypted backup.',
        );
      }
    }

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
        return const BackupManifestSummary(
          schemaVersion: 0,
          appVersion: '',
          exportedAt: '',
          companyName: '',
          tableCounts: {},
          hasLogo: false,
          hasThemePrefs: false,
          isEncrypted: false,
          isValid: false,
          validationError: 'Invalid or empty backup file format.',
        );
      }

      final version = (decoded['version'] as num?)?.toInt() ?? 0;
      if (version > AppDatabase.currentVersion) {
        return BackupManifestSummary(
          schemaVersion: version,
          appVersion: decoded['app_version']?.toString() ?? '',
          exportedAt: decoded['exported_at']?.toString() ?? '',
          companyName: decoded['company_name']?.toString() ?? '',
          tableCounts: {},
          hasLogo: false,
          hasThemePrefs: false,
          isEncrypted: isEnc,
          isValid: false,
          validationError: 'Incompatible backup created by a newer version (Schema v$version).',
        );
      }

      // Verify SHA-256 digest if present
      if (decoded.containsKey('sha256')) {
        final expectedHash = decoded['sha256'] as String;
        final payloadWithoutHash = Map<String, dynamic>.from(decoded)..remove('sha256');
        final calculated = crypto.computeSha256(jsonEncode(payloadWithoutHash));
        if (calculated.toLowerCase() != expectedHash.toLowerCase()) {
          return BackupManifestSummary(
            schemaVersion: version,
            appVersion: decoded['app_version']?.toString() ?? '',
            exportedAt: decoded['exported_at']?.toString() ?? '',
            companyName: decoded['company_name']?.toString() ?? '',
            tableCounts: {},
            hasLogo: false,
            hasThemePrefs: false,
            isEncrypted: isEnc,
            isValid: false,
            validationError: 'Backup integrity checksum failed. File may be corrupted or modified.',
          );
        }
      }

      final tableCounts = <String, int>{};
      for (final t in _allBackupTables) {
        if (decoded.containsKey(t) && decoded[t] is List) {
          tableCounts[t] = (decoded[t] as List).length;
        }
      }

      final prefs = (decoded['prefs'] is Map) ? decoded['prefs'] as Map : {};
      final hasLogo = (prefs['company_logo_base64'] as String?)?.isNotEmpty ?? false;
      final hasThemePrefs = prefs.containsKey('themeMode');

      return BackupManifestSummary(
        schemaVersion: version,
        appVersion: decoded['app_version']?.toString() ?? '',
        exportedAt: decoded['exported_at']?.toString() ?? '',
        companyName: decoded['company_name']?.toString() ?? '',
        tableCounts: tableCounts,
        hasLogo: hasLogo,
        hasThemePrefs: hasThemePrefs,
        isEncrypted: isEnc,
        isValid: true,
      );
    } catch (e) {
      return BackupManifestSummary(
        schemaVersion: 0,
        appVersion: '',
        exportedAt: '',
        companyName: '',
        tableCounts: {},
        hasLogo: false,
        hasThemePrefs: false,
        isEncrypted: isEnc,
        isValid: false,
        validationError: 'Failed to parse backup content: $e',
      );
    }
  }

  /// Restores all or selectively chosen tables from a backup string with atomic transaction rollback.
  Future<void> importJson(String jsonStr, {String? passphrase}) async {
    await importJsonSelective(jsonStr, _allBackupTables.toSet(), passphrase: passphrase);
  }

  /// Restores only [selectedTables] from a verified backup string.
  Future<void> importJsonSelective(
    String jsonStr,
    Set<String> selectedTables, {
    String? passphrase,
  }) async {
    final summary = await inspectBackupJson(jsonStr, passphrase: passphrase);
    if (!summary.isValid) {
      throw StateError(summary.validationError ?? 'Invalid backup file.');
    }

    String plaintext = jsonStr;
    if (summary.isEncrypted) {
      plaintext = await BackupCryptoService().decryptBackup(jsonStr, passphrase!);
    }

    final data = jsonDecode(plaintext) as Map<String, dynamic>;

    await batchScope(() async {
      await drift.transaction(() async {
        for (final t in selectedTables) {
          if (!data.containsKey(t) && !data.containsKey(t.toLowerCase())) continue;
          final dynamic rawList = data[t] ?? data[t.toLowerCase()];
          if (rawList is! List) continue;

          await deleteTable(t);

          final pragma = await drift.customSelect('PRAGMA table_info($t)').get();
          final allowedCols = pragma.map((r) => r.data['name'] as String).toSet();

          for (final row in rawList) {
            if (row is! Map) continue;
            final filteredRow = <String, dynamic>{};
            row.forEach((key, value) {
              final kStr = key.toString();
              if (allowedCols.contains(kStr)) {
                filteredRow[kStr] = value;
              }
            });
            if (filteredRow.isNotEmpty) {
              await insertMap(t, filteredRow);
            }
          }
        }
      });
    });

    // Restore branding if present
    if (data.containsKey('company_name') && data['company_name'] != null) {
      final name = data['company_name'].toString();
      if (name.isNotEmpty) {
        await CompanyService().completeOnboarding(name);
      }
    }

    // Restore preferences, logo, and theme tokens if present
    if (data.containsKey('prefs') && data['prefs'] is Map) {
      final prefsMap = data['prefs'] as Map;
      final prefs = await SharedPreferences.getInstance();

      if (prefsMap.containsKey('custom_switch_patch_chassis_v1') &&
          prefsMap['custom_switch_patch_chassis_v1'] != null) {
        await prefs.setString(
          'custom_switch_patch_chassis_v1',
          prefsMap['custom_switch_patch_chassis_v1'].toString(),
        );
      }

      // Restore base64 logo to local storage
      final logoBase64 = prefsMap['company_logo_base64']?.toString();
      if (logoBase64 != null && logoBase64.isNotEmpty) {
        try {
          final ext = prefsMap['company_logo_ext']?.toString() ?? 'png';
          final docsDir = await getApplicationDocumentsDirectory();
          final destFile = File('${docsDir.path}/company_logo.$ext');
          await destFile.writeAsBytes(base64Decode(logoBase64));
          await CompanyService().setCompanyLogo(destFile.path);
        } catch (_) {}
      }

      // Restore theme settings
      final theme = ThemeService();
      if (prefsMap.containsKey('themeMode')) await theme.updateSetting('themeMode', prefsMap['themeMode']);
      if (prefsMap.containsKey('themeSeed')) await theme.updateSetting('themeSeed', prefsMap['themeSeed']);
      if (prefsMap.containsKey('appFont')) await theme.updateSetting('appFont', prefsMap['appFont']);
      if (prefsMap.containsKey('amoledSurfaces')) await theme.updateSetting('amoledSurfaces', prefsMap['amoledSurfaces'] == true);
      if (prefsMap.containsKey('dynamicColorEnabled')) await theme.updateSetting('dynamicColorEnabled', prefsMap['dynamicColorEnabled'] == true);
    }

    await syncDeviceStatuses();
    final activeLogs = await getBorrowLogs();
    await NotificationService().reconcileReminders(activeLogs);

    // Foreign key integrity check
    await drift.customSelect('PRAGMA foreign_key_check').get();
  }

  Future<Map<String, int>> getCounts() async {
    final res = await drift.customSelect('''
      SELECT
        (SELECT COUNT(*) FROM laptops) AS laptops,
        (SELECT COUNT(*) FROM network_devices) AS network_devices,
        (SELECT COUNT(*) FROM printers) AS printers,
        (SELECT COUNT(*) FROM electronics) AS electronics,
        (SELECT COUNT(*) FROM employees) AS employees,
        (SELECT COUNT(*) FROM mifis) AS mifis,
        (SELECT COUNT(*) FROM expenses) AS expenses,
        (SELECT COUNT(*) FROM bills) AS bills,
        (SELECT COUNT(*) FROM email_accounts) AS email_accounts,
        (SELECT COUNT(*) FROM borrow_logs WHERE is_returned=0) AS active_borrows,
        (SELECT COUNT(*) FROM borrow_logs WHERE is_returned=0 AND due_date IS NOT NULL AND due_date != '' AND due_date < date('now')) AS overdue_borrows,
        (SELECT COUNT(*) FROM log_entries) AS log_entries,
        (SELECT COUNT(*) FROM log_entries WHERE state='Open') AS open_log_entries,
        (SELECT COUNT(*) FROM subscriptions) AS subscriptions,
        (SELECT COUNT(*) FROM access_points) AS access_points,
        (SELECT COUNT(*) FROM wifi_networks) AS wifi_networks,
        (SELECT COUNT(*) FROM account_passwords) AS account_passwords,
        (SELECT COUNT(*) FROM other_devices) AS other_devices,
        (SELECT COUNT(*) FROM vendor_contacts) AS vendor_contacts
    ''').getSingle();

    return res.data.map((key, value) => MapEntry(key, value as int? ?? 0));
  }

  Stream<Map<String, int>> watchCounts() {
    return _watchSwitchable(() {
      return drift.customSelect('''
        SELECT
          (SELECT COUNT(*) FROM laptops) AS laptops,
          (SELECT COUNT(*) FROM network_devices) AS network_devices,
          (SELECT COUNT(*) FROM printers) AS printers,
          (SELECT COUNT(*) FROM electronics) AS electronics,
          (SELECT COUNT(*) FROM employees) AS employees,
          (SELECT COUNT(*) FROM mifis) AS mifis,
          (SELECT COUNT(*) FROM expenses) AS expenses,
          (SELECT COUNT(*) FROM bills) AS bills,
          (SELECT COUNT(*) FROM email_accounts) AS email_accounts,
          (SELECT COUNT(*) FROM borrow_logs WHERE is_returned=0) AS active_borrows,
          (SELECT COUNT(*) FROM borrow_logs WHERE is_returned=0 AND due_date IS NOT NULL AND due_date != '' AND due_date < date('now')) AS overdue_borrows,
          (SELECT COUNT(*) FROM log_entries) AS log_entries,
          (SELECT COUNT(*) FROM log_entries WHERE state='Open') AS open_log_entries,
          (SELECT COUNT(*) FROM subscriptions) AS subscriptions,
          (SELECT COUNT(*) FROM access_points) AS access_points,
          (SELECT COUNT(*) FROM wifi_networks) AS wifi_networks,
          (SELECT COUNT(*) FROM account_passwords) AS account_passwords,
          (SELECT COUNT(*) FROM other_devices) AS other_devices,
          (SELECT COUNT(*) FROM vendor_contacts) AS vendor_contacts
      ''', readsFrom: {
        drift.laptops,
        drift.networkDevices,
        drift.printers,
        drift.electronics,
        drift.employees,
        drift.mifis,
        drift.expenses,
        drift.bills,
        drift.emailAccounts,
        drift.borrowLogs,
        drift.logEntries,
        drift.subscriptions,
        drift.accessPoints,
        drift.wifiNetworks,
        drift.accountPasswords,
        drift.otherDevices,
        drift.vendorContacts,
      }).watchSingle().map((row) => row.data.map((key, value) => MapEntry(key, value as int? ?? 0)));
    });
  }
}
