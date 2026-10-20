// lib/database/database_helper.dart
import 'dart:convert';
import 'package:drift/drift.dart';
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
import 'package:flutter/foundation.dart';
import '../models/access_point.dart';
import '../models/wifi_network.dart';
import '../models/account_password.dart';
import '../models/other_device.dart';
import '../services/company_service.dart';

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class TableNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
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

  @Deprecated('Use typed Drift query builders and Companions instead')
  Future<int> updateMap(
      String table, Map<String, dynamic> map, String idCol, dynamic idVal) async {
    final keys = map.keys.where((k) => k != idCol).toList();
    final setClause = keys.map((k) => '$k = ?').join(', ');
    final sql = 'UPDATE $table SET $setClause WHERE $idCol = ?';
    final values = [
      ...keys.map((k) => Variable<Object>(map[k])),
      Variable<Object>(idVal)
    ];
    final res = await drift.customUpdate(sql, variables: values);
    notifyTableChanged(table);
    return res;
  }

  @Deprecated('Use typed Drift query builders instead')
  Future<int> deleteRow(String table, String idCol, dynamic idVal) async {
    final res = await drift.customUpdate('DELETE FROM $table WHERE $idCol = ?',
        variables: [Variable<Object>(idVal)]);
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
      );

  Printer _printerFromEntry(PrinterEntry e) => Printer(
        id: e.id,
        printerNumber: e.printerNumber,
        model: e.model,
        condition: e.condition,
        location: e.location,
      );

  PrintersCompanion _printerToCompanion(Printer p) => PrintersCompanion(
        id: p.id != null ? Value(p.id!) : const Value.absent(),
        printerNumber: Value(p.printerNumber),
        model: Value(p.model),
        condition: Value(p.condition),
        location: Value(p.location),
      );

  Electronic _electronicFromEntry(ElectronicEntry e) => Electronic(
        id: e.id,
        deviceNumber: e.deviceNumber,
        deviceName: e.deviceName,
        details: e.details,
        status: e.status,
        excludeFromBorrowing: e.excludeBorrowing == 1,
      );

  ElectronicsCompanion _electronicToCompanion(Electronic e) => ElectronicsCompanion(
        id: e.id != null ? Value(e.id!) : const Value.absent(),
        deviceNumber: Value(e.deviceNumber),
        deviceName: Value(e.deviceName),
        details: Value(e.details),
        status: Value(e.status),
        excludeBorrowing: Value(e.excludeFromBorrowing ? 1 : 0),
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

  LogEntriesCompanion _logEntryToCompanion(LogEntry le) => LogEntriesCompanion(
        id: le.id != null ? Value(le.id!) : const Value.absent(),
        date: Value(le.date),
        employeeId: le.employeeId != null ? Value(le.employeeId) : const Value.absent(),
        employeeName: Value(le.employeeName),
        problem: Value(le.problem),
        solution: Value(le.solution),
        state: Value(le.state),
        priority: Value(le.priority),
      );

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
      );

  AccessPointsCompanion _accessPointToCompanion(AccessPoint ap) => AccessPointsCompanion(
        id: ap.id != null ? Value(ap.id!) : const Value.absent(),
        deviceNumber: Value(ap.deviceNumber),
        model: Value(ap.model),
        portNumber: Value(ap.portNumber),
        location: Value(ap.location),
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

  Map<String, dynamic> _maintenanceEntryToMap(MaintenanceEntry e) => {
        'id': e.id,
        'device_type': e.deviceType,
        'device_id': e.deviceId,
        'date': e.date,
        'service_type': e.serviceType,
        'cost': e.cost,
        'details': e.details,
        'performed_by': e.performedBy,
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
      );

  Map<String, dynamic> _consumableEntryToMap(ConsumableEntry e) => {
        'id': e.id,
        'item_name': e.itemName,
        'category': e.category,
        'quantity': e.quantity,
        'minimum_threshold': e.minimumThreshold,
        'location': e.location,
        'unit_price': e.unitPrice,
      };

  ConsumablesCompanion _consumableToCompanion(Map<String, dynamic> m) => ConsumablesCompanion(
        id: m['id'] != null ? Value(m['id'] as int) : const Value.absent(),
        itemName: Value((m['item_name'] ?? '') as String),
        category: Value((m['category'] ?? 'General') as String),
        quantity: Value((m['quantity'] ?? 0) as int),
        minimumThreshold: Value((m['minimum_threshold'] ?? 5) as int),
        location: Value((m['location'] ?? '') as String),
        unitPrice: Value((m['unit_price'] as num? ?? 0.0).toDouble()),
      );

  Map<String, dynamic> _consumableLogEntryToMap(ConsumableLogEntry e) => {
        'id': e.id,
        'consumable_id': e.consumableId,
        'employee_id': e.employeeId,
        'change_amount': e.changeAmount,
        'reason': e.reason,
        'date': e.date,
      };

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

  Map<String, dynamic> _softDeleteEntryToMap(SoftDeleteEntry e) => {
        'id': e.id,
        'original_table': e.originalTable,
        'original_id': e.originalId,
        'display_name': e.displayName,
        'serialized_data': e.serializedData,
        'deleted_at': e.deletedAt,
      };

  SoftDeletesCompanion _softDeleteToCompanion(Map<String, dynamic> m) => SoftDeletesCompanion(
        id: m['id'] != null ? Value(m['id'] as int) : const Value.absent(),
        originalTable: Value((m['original_table'] ?? '') as String),
        originalId: Value((m['original_id'] ?? 0) as int),
        displayName: Value((m['display_name'] ?? '') as String),
        serializedData: Value((m['serialized_data'] ?? '') as String),
        deletedAt: Value((m['deleted_at'] ?? DateTime.now().toIso8601String()) as String),
      );

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
    final query = drift.select(drift.laptops)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.laptopNumber)]);
    return query.watch().map((rows) => rows.map(_laptopFromEntry).toList());
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
    final query = drift.select(drift.networkDevices)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceNumber)]);
    return query.watch().map((rows) => rows.map(_networkDeviceFromEntry).toList());
  }

  Future<int> updateNetworkDevice(NetworkDevice d) async {
    final rows = await (drift.update(drift.networkDevices)..where((tbl) => tbl.id.equals(d.id!)))
        .write(_networkDeviceToCompanion(d));
    notifyTableChanged('network_devices');
    return rows;
  }

  Future<int> updateNetworkDeviceStatus(int id, String s) async {
    final rows = await (drift.update(drift.networkDevices)..where((tbl) => tbl.id.equals(id)))
        .write(NetworkDevicesCompanion(status: Value(s)));
    notifyTableChanged('network_devices');
    return rows;
  }

  Future<int> deleteNetworkDevice(int id) async {
    final rows = await (drift.delete(drift.networkDevices)..where((tbl) => tbl.id.equals(id))).go();
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

  Stream<List<Printer>> watchPrinters() {
    final query = drift.select(drift.printers)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.printerNumber)]);
    return query.watch().map((rows) => rows.map(_printerFromEntry).toList());
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
    final query = drift.select(drift.electronics)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceNumber)]);
    return query.watch().map((rows) => rows.map(_electronicFromEntry).toList());
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

    final borrowsRow = await (drift.selectOnly(drift.borrowLogs)
          ..addColumns([borrowCountExp])
          ..where(drift.borrowLogs.employeeId.equals(employeeId) &
              drift.borrowLogs.isReturned.equals(0)))
        .getSingle();

    final emailsRow = await (drift.selectOnly(drift.emailAccounts)
          ..addColumns([emailCountExp])
          ..where(drift.emailAccounts.employeeId.equals(employeeId)))
        .getSingle();

    final logsRow = await (drift.selectOnly(drift.logEntries)
          ..addColumns([logCountExp])
          ..where(drift.logEntries.employeeId.equals(employeeId)))
        .getSingle();

    return {
      'active_borrows': borrowsRow.read(borrowCountExp) ?? 0,
      'emails': emailsRow.read(emailCountExp) ?? 0,
      'tickets': logsRow.read(logCountExp) ?? 0,
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
    final query = drift.select(drift.employees);
    if (search != null && search.trim().isNotEmpty) {
      final term = '%${search.trim().toLowerCase()}%';
      query.where((tbl) => tbl.name.lower().like(term) | tbl.phoneNumber.like(term));
    }
    query.orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);
    return query.watch().map((rows) => rows.map(_employeeFromEntry).toList());
  }

  Future<int> updateEmployee(Employee e) async {
    final rows = await (drift.update(drift.employees)..where((tbl) => tbl.id.equals(e.id!)))
        .write(_employeeToCompanion(e));
    notifyTableChanged('employees');
    return rows;
  }

  Future<int> deleteEmployee(int id) async {
    if (await getEmployeeActiveBorrowsCount(id) > 0) {
      throw StateError('Cannot delete employee while they have active borrowed devices.');
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
    final query = drift.select(drift.mifis)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceNumber)]);
    return query.watch().map((rows) => rows.map(_mifiFromEntry).toList());
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
        // Revert old device to Available only if oldLog was active AND no other active borrow exists
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

        // Mark new device as Borrowed only if newLog is active
        if (!newLog.isReturned) {
          if (newLog.deviceType.toLowerCase() == 'electronic') {
            await updateElectronicStatus(newLog.deviceId, 'Borrowed');
          } else if (newLog.deviceType.toLowerCase() == 'mifi') {
            await updateMiFiStatus(newLog.deviceId, 'Borrowed');
          }
        }
      } else if (returnStatusChanged) {
        if (newLog.isReturned) {
          // Changed from active to returned: check if any other active borrow exists
          final remaining = await (drift.select(drift.borrowLogs)
                ..where((tbl) =>
                    tbl.deviceType.lower().equals(newLog.deviceType.toLowerCase()) &
                    tbl.deviceId.equals(newLog.deviceId) &
                    tbl.isReturned.equals(0) &
                    tbl.id.equals(logId).not()))
              .get();
          if (remaining.isEmpty) {
            if (newLog.deviceType.toLowerCase() == 'electronic') {
              await updateElectronicStatus(newLog.deviceId, 'Available');
            } else if (newLog.deviceType.toLowerCase() == 'mifi') {
              await updateMiFiStatus(newLog.deviceId, 'Available');
            }
          }
        } else {
          // Changed from returned back to active borrow
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
      (tbl) => OrderingTerm.desc(tbl.outDate),
      (tbl) => OrderingTerm.desc(tbl.id),
    ]);
    final rows = await query.get();
    return rows.map(_borrowLogFromEntry).toList();
  }

  Stream<List<BorrowLog>> watchBorrowLogs({bool? activeOnly}) {
    final query = drift.select(drift.borrowLogs);
    if (activeOnly == true) {
      query.where((tbl) => tbl.isReturned.equals(0));
    }
    query.orderBy([
      (tbl) => OrderingTerm.desc(tbl.outDate),
      (tbl) => OrderingTerm.desc(tbl.id),
    ]);
    return query.watch().map((rows) => rows.map(_borrowLogFromEntry).toList());
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
              ..where(
                  (tbl) => tbl.status.equals('Borrowed').not() & tbl.id.isIn(activeElecIds)))
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

  Future<List<Expense>> getExpenses() async {
    final query = drift.select(drift.expenses)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
    final rows = await query.get();
    return rows.map(_expenseFromEntry).toList();
  }

  Stream<List<Expense>> watchExpenses({int? year, int? month}) {
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
    return query.watch().map((rows) => rows.map(_expenseFromEntry).toList());
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

  Future<List<Expense>> getExpensesByMonth(int year, int month) async {
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final query = drift.select(drift.expenses)
      ..where((tbl) => tbl.date.like('$prefix%'))
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

  // ── Bills ─────────────────────────────────────────────────────────────────
  Future<int> insertBill(Bill b) async {
    final id = await drift.into(drift.bills).insert(_billToCompanion(b));
    notifyTableChanged('bills');
    return id;
  }

  Future<List<Bill>> getBills() async {
    final query = drift.select(drift.bills)..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]);
    final rows = await query.get();
    return rows.map(_billFromEntry).toList();
  }

  Stream<List<Bill>> watchBills() {
    final query = drift.select(drift.bills)..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]);
    return query.watch().map((rows) => rows.map(_billFromEntry).toList());
  }

  Future<double> getTotalBills() async {
    final sumExp = drift.bills.price.sum();
    final query = drift.selectOnly(drift.bills)..addColumns([sumExp]);
    final row = await query.getSingle();
    return row.read(sumExp) ?? 0.0;
  }

  Stream<double> watchTotalBills() {
    final sumExp = drift.bills.price.sum();
    final query = drift.selectOnly(drift.bills)..addColumns([sumExp]);
    return query.watchSingle().map((row) => row.read(sumExp) ?? 0.0);
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

  // ── Email Accounts ────────────────────────────────────────────────────────
  Future<int> insertEmailAccount(EmailAccount e) async {
    final id = await drift.into(drift.emailAccounts).insert(_emailAccountToCompanion(e));
    notifyTableChanged('email_accounts');
    return id;
  }

  Future<List<EmailAccount>> getEmailAccounts() async {
    final query = drift.select(drift.emailAccounts)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.employeeName), (tbl) => OrderingTerm.asc(tbl.email)]);
    final rows = await query.get();
    return rows.map(_emailAccountFromEntry).toList();
  }

  Stream<List<EmailAccount>> watchEmailAccounts() {
    final query = drift.select(drift.emailAccounts)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.employeeName), (tbl) => OrderingTerm.asc(tbl.email)]);
    return query.watch().map((rows) => rows.map(_emailAccountFromEntry).toList());
  }

  Future<int> updateEmailAccount(EmailAccount e) async {
    final rows = await (drift.update(drift.emailAccounts)..where((tbl) => tbl.id.equals(e.id!)))
        .write(_emailAccountToCompanion(e));
    notifyTableChanged('email_accounts');
    return rows;
  }

  Future<int> deleteEmailAccount(int id) async {
    final rows = await (drift.delete(drift.emailAccounts)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('email_accounts');
    return rows;
  }

  // ── Log Entries ───────────────────────────────────────────────────────────
  Future<int> insertLogEntry(LogEntry e) async {
    final id = await drift.into(drift.logEntries).insert(_logEntryToCompanion(e));
    notifyTableChanged('log_entries');
    return id;
  }

  Future<List<LogEntry>> getLogEntries() async {
    final query = drift.select(drift.logEntries)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
    final rows = await query.get();
    return rows.map(_logEntryFromEntry).toList();
  }

  Stream<List<LogEntry>> watchLogEntries({String? stateFilter, int? year, int? month}) {
    final query = drift.select(drift.logEntries);
    if (stateFilter != null && stateFilter.isNotEmpty) {
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
  }

  Future<List<LogEntry>> getLogEntriesByYear(int year) async {
    final query = drift.select(drift.logEntries)
      ..where((tbl) => tbl.date.like('$year%'))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
    final rows = await query.get();
    return rows.map(_logEntryFromEntry).toList();
  }

  Future<List<LogEntry>> getLogEntriesByMonth(int year, int month) async {
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final query = drift.select(drift.logEntries)
      ..where((tbl) => tbl.date.like('$prefix%'))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
    final rows = await query.get();
    return rows.map(_logEntryFromEntry).toList();
  }

  Future<List<LogEntry>> getOpenLogEntries() async {
    final query = drift.select(drift.logEntries)
      ..where((tbl) => tbl.state.lower().equals('open'))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
    final rows = await query.get();
    return rows.map(_logEntryFromEntry).toList();
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

  Future<int> updateLogEntry(LogEntry e) async {
    final rows = await (drift.update(drift.logEntries)..where((tbl) => tbl.id.equals(e.id!)))
        .write(_logEntryToCompanion(e));
    notifyTableChanged('log_entries');
    return rows;
  }

  Future<int> deleteLogEntry(int id) async {
    final rows = await (drift.delete(drift.logEntries)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('log_entries');
    return rows;
  }

  // ── Subscriptions ─────────────────────────────────────────────────────────
  Future<int> insertSubscription(Subscription s) async {
    final id = await drift.into(drift.subscriptions).insert(_subscriptionToCompanion(s));
    notifyTableChanged('subscriptions');
    return id;
  }

  Future<List<Subscription>> getSubscriptions() async {
    final query = drift.select(drift.subscriptions)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]);
    final rows = await query.get();
    return rows.map(_subscriptionFromEntry).toList();
  }

  Stream<List<Subscription>> watchSubscriptions() {
    final query = drift.select(drift.subscriptions)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]);
    return query.watch().map((rows) => rows.map(_subscriptionFromEntry).toList());
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

  Stream<List<AccessPoint>> watchAccessPoints() {
    final query = drift.select(drift.accessPoints)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceNumber)]);
    return query.watch().map((rows) => rows.map(_accessPointFromEntry).toList());
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

  // ── Wi-Fi Networks ─────────────────────────────────────────────────────────
  Future<int> insertWifiNetwork(WifiNetwork w) async {
    final id = await drift.into(drift.wifiNetworks).insert(_wifiNetworkToCompanion(w));
    notifyTableChanged('wifi_networks');
    return id;
  }

  Future<List<WifiNetwork>> getWifiNetworks() async {
    final query = drift.select(drift.wifiNetworks)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.networkName.collate(Collate.noCase))]);
    final rows = await query.get();
    return rows.map(_wifiNetworkFromEntry).toList();
  }

  Stream<List<WifiNetwork>> watchWifiNetworks() {
    final query = drift.select(drift.wifiNetworks)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.networkName.collate(Collate.noCase))]);
    return query.watch().map((rows) => rows.map(_wifiNetworkFromEntry).toList());
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

  // ── Account Passwords ───────────────────────────────────────────────────────
  Future<int> insertAccountPassword(AccountPassword a) async {
    final id = await drift.into(drift.accountPasswords).insert(_accountPasswordToCompanion(a));
    notifyTableChanged('account_passwords');
    return id;
  }

  Future<List<AccountPassword>> getAccountPasswords() async {
    final query = drift.select(drift.accountPasswords)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.platform.collate(Collate.noCase))]);
    final rows = await query.get();
    return rows.map(_accountPasswordFromEntry).toList();
  }

  Stream<List<AccountPassword>> watchAccountPasswords() {
    final query = drift.select(drift.accountPasswords)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.platform.collate(Collate.noCase))]);
    return query.watch().map((rows) => rows.map(_accountPasswordFromEntry).toList());
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

  // ── Other Devices ──────────────────────────────────────────────────────────
  Future<int> insertOtherDevice(OtherDevice d) async {
    final id = await drift.into(drift.otherDevices).insert(_otherDeviceToCompanion(d));
    notifyTableChanged('other_devices');
    return id;
  }

  Future<List<OtherDevice>> getOtherDevices() async {
    final query = drift.select(drift.otherDevices)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceName.collate(Collate.noCase))]);
    final rows = await query.get();
    return rows.map(_otherDeviceFromEntry).toList();
  }

  Stream<List<OtherDevice>> watchOtherDevices() {
    final query = drift.select(drift.otherDevices)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.deviceName.collate(Collate.noCase))]);
    return query.watch().map((rows) => rows.map(_otherDeviceFromEntry).toList());
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

  Stream<List<Map<String, dynamic>>> watchMaintenanceLogsForDevice(
      String deviceType, int deviceId) {
    final query = drift.select(drift.deviceMaintenanceLogs)
      ..where((tbl) => tbl.deviceType.equals(deviceType) & tbl.deviceId.equals(deviceId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
    return query.watch().map((rows) => rows.map(_maintenanceEntryToMap).toList());
  }

  Future<int> deleteMaintenanceLog(int id) async {
    final rows = await (drift.delete(drift.deviceMaintenanceLogs)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('device_maintenance_logs');
    return rows;
  }

  // ── Consumables & Stock ───────────────────────────────────────────────────
  Future<int> insertConsumable(Map<String, dynamic> item) async {
    final id = await drift.into(drift.consumables).insert(_consumableToCompanion(item));
    notifyTableChanged('consumables');
    return id;
  }

  Future<List<Map<String, dynamic>>> getConsumables() async {
    final query = drift.select(drift.consumables)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.itemName)]);
    final rows = await query.get();
    return rows.map(_consumableEntryToMap).toList();
  }

  Stream<List<Map<String, dynamic>>> watchConsumables() {
    final query = drift.select(drift.consumables)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.itemName)]);
    return query.watch().map((rows) => rows.map(_consumableEntryToMap).toList());
  }

  Future<int> updateConsumable(Map<String, dynamic> item, int id) async {
    final rows = await (drift.update(drift.consumables)..where((tbl) => tbl.id.equals(id)))
        .write(_consumableToCompanion(item));
    notifyTableChanged('consumables');
    return rows;
  }

  Future<int> adjustConsumableQuantity(
      int consumableId, int delta, String reason, int? employeeId) async {
    return await drift.transaction(() async {
      final cur = await (drift.select(drift.consumables)..where((t) => t.id.equals(consumableId)))
          .getSingleOrNull();
      final currentQty = cur?.quantity ?? 0;
      final newQty = (currentQty + delta) < 0 ? 0 : (currentQty + delta);
      await (drift.update(drift.consumables)..where((t) => t.id.equals(consumableId)))
          .write(ConsumablesCompanion(quantity: Value(newQty)));
      notifyTableChanged('consumables');

      await drift.into(drift.consumableLogs).insert(ConsumableLogsCompanion(
            consumableId: Value(consumableId),
            employeeId: employeeId != null ? Value(employeeId) : const Value.absent(),
            changeAmount: Value(delta),
            reason: Value(reason),
            date: Value(DateTime.now().toIso8601String().split('T').first),
          ));
      notifyTableChanged('consumable_logs');
      return newQty;
    });
  }

  Future<int> deleteConsumable(int id) async {
    final rows = await (drift.delete(drift.consumables)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('consumables');
    return rows;
  }

  Future<List<Map<String, dynamic>>> getConsumableLogs(int consumableId) async {
    final query = drift.select(drift.consumableLogs)
      ..where((tbl) => tbl.consumableId.equals(consumableId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
    final rows = await query.get();
    return rows.map(_consumableLogEntryToMap).toList();
  }

  Stream<List<Map<String, dynamic>>> watchConsumableLogs(int consumableId) {
    final query = drift.select(drift.consumableLogs)
      ..where((tbl) => tbl.consumableId.equals(consumableId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date), (tbl) => OrderingTerm.desc(tbl.id)]);
    return query.watch().map((rows) => rows.map(_consumableLogEntryToMap).toList());
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

  Stream<List<Map<String, dynamic>>> watchStaticIps() {
    final query = drift.select(drift.staticIps)..orderBy([(tbl) => OrderingTerm.asc(tbl.ipAddress)]);
    return query.watch().map((rows) => rows.map(_staticIpEntryToMap).toList());
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

  // ── Switch Patch Ports ─────────────────────────────────────────────────────
  Future<int> insertSwitchPatchPort(Map<String, dynamic> port) async {
    final id = await drift.into(drift.switchPatchPorts).insert(_switchPatchPortToCompanion(port));
    notifyTableChanged('switch_patch_ports');
    return id;
  }

  Future<List<Map<String, dynamic>>> getSwitchPatchPorts(int switchId) async {
    final query = drift.select(drift.switchPatchPorts)
      ..where((tbl) => tbl.switchDeviceId.equals(switchId))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.portNumber)]);
    final rows = await query.get();
    return rows.map(_switchPatchPortEntryToMap).toList();
  }

  Stream<List<Map<String, dynamic>>> watchSwitchPatchPorts(int switchId) {
    final query = drift.select(drift.switchPatchPorts)
      ..where((tbl) => tbl.switchDeviceId.equals(switchId))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.portNumber)]);
    return query.watch().map((rows) => rows.map(_switchPatchPortEntryToMap).toList());
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

  // ── Audit Activities ───────────────────────────────────────────────────────
  Future<int> logAuditActivity(String action, String entityType,
      {int? entityId, required String description}) async {
    final id = await drift.into(drift.auditActivities).insert(
          AuditActivitiesCompanion(
            actionType: Value(action),
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

  Stream<List<Map<String, dynamic>>> watchAuditActivities({int limit = 100}) {
    final query = drift.select(drift.auditActivities)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)])
      ..limit(limit);
    return query.watch().map((rows) => rows.map(_auditActivityEntryToMap).toList());
  }

  Future<int> clearAuditActivities() async {
    final count = await drift.delete(drift.auditActivities).go();
    notifyTableChanged('audit_activities');
    return count;
  }

  // ── Soft Deletes ──────────────────────────────────────────────────────────
  Future<int> insertSoftDelete(Map<String, dynamic> sd) async {
    final id = await drift.into(drift.softDeletes).insert(_softDeleteToCompanion(sd));
    notifyTableChanged('soft_deletes');
    return id;
  }

  Future<List<Map<String, dynamic>>> getSoftDeletes() async {
    final query = drift.select(drift.softDeletes)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.deletedAt)]);
    final rows = await query.get();
    return rows.map(_softDeleteEntryToMap).toList();
  }

  Stream<List<Map<String, dynamic>>> watchSoftDeletes() {
    final query = drift.select(drift.softDeletes)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.deletedAt)]);
    return query.watch().map((rows) => rows.map(_softDeleteEntryToMap).toList());
  }

  Future<int> deleteSoftDelete(int id) async {
    final rows = await (drift.delete(drift.softDeletes)..where((tbl) => tbl.id.equals(id))).go();
    notifyTableChanged('soft_deletes');
    return rows;
  }


  // ── Backup / Restore ──────────────────────────────────────────────────────
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
    'consumables',
    'consumable_logs',
    'audit_activities',
    'soft_deletes',
  ];

  Future<String> exportJson() async {
    final prefs = await SharedPreferences.getInstance();
    final chassisJson = prefs.getString('custom_switch_patch_chassis_v1') ?? '';

    final map = <String, dynamic>{
      'version': 8,
      'exported_at': DateTime.now().toIso8601String(),
      'company_name': CompanyService().name,
      'prefs': {
        'custom_switch_patch_chassis_v1': chassisJson,
      },
    };

    for (final t in _allBackupTables) {
      map[t] = await query(t);
    }
    return jsonEncode(map);
  }

  Future<void> importJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    await batchScope(() async {
      await drift.transaction(() async {
        for (final t in _allBackupTables) {
          if (!data.containsKey(t) && !data.containsKey(t.toLowerCase())) continue;
          final dynamic rawList = data[t] ?? data[t.toLowerCase()];
          if (rawList is! List) continue;

          await deleteTable(t);

          // Get column allowlist from SQLite schema
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

    if (data.containsKey('company_name') && data['company_name'] != null) {
      final name = data['company_name'].toString();
      if (name.isNotEmpty) {
        await CompanyService().completeOnboarding(name);
      }
    }

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
    }

    await syncDeviceStatuses();
    final activeLogs = await getBorrowLogs();
    await NotificationService().reconcileReminders(activeLogs);
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
        (SELECT COUNT(*) FROM other_devices) AS other_devices
    ''').getSingle();

    return res.data.map((key, value) => MapEntry(key, value as int? ?? 0));
  }

  Stream<Map<String, int>> watchCounts() {
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
        (SELECT COUNT(*) FROM other_devices) AS other_devices
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
    }).watchSingle().map((row) => row.data.map((key, value) => MapEntry(key, value as int? ?? 0)));
  }
}
