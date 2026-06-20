import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
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

class DatabaseHelper {
  static final DatabaseHelper _i = DatabaseHelper._();
  factory DatabaseHelper() => _i;
  DatabaseHelper._();
  static Database? _db;

  Future<Database> get db async { _db ??= await _open(); return _db!; }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'itbox.db');
    return openDatabase(path, version: 6, onCreate: _create, onUpgrade: _upgrade,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'));
  }

  Future<void> _create(Database db, int v) async {
    await db.execute('''CREATE TABLE laptops(id INTEGER PRIMARY KEY AUTOINCREMENT,
      laptop_number TEXT NOT NULL,model TEXT NOT NULL,cpu TEXT DEFAULT '',gpu TEXT DEFAULT '',
      ram TEXT DEFAULT '',storage TEXT DEFAULT '',condition TEXT DEFAULT 'Good',
      user TEXT DEFAULT '',password TEXT DEFAULT '',created_at TEXT)''');
    await db.execute('''CREATE TABLE network_devices(id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_number TEXT NOT NULL,model TEXT NOT NULL,phone_number TEXT DEFAULT '',
      device_location TEXT DEFAULT '',service_provider TEXT DEFAULT '',
      wifi_name TEXT DEFAULT '',wifi_password TEXT DEFAULT '',
      gateway TEXT DEFAULT '',admin_password TEXT DEFAULT '',status TEXT DEFAULT 'Available')''');
    await db.execute('''CREATE TABLE printers(id INTEGER PRIMARY KEY AUTOINCREMENT,
      printer_number TEXT NOT NULL,model TEXT NOT NULL,condition TEXT DEFAULT 'Good',location TEXT DEFAULT '')''');
    await db.execute('''CREATE TABLE electronics(id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_number TEXT NOT NULL,device_name TEXT NOT NULL,details TEXT DEFAULT '',status TEXT DEFAULT 'Available')''');
    await db.execute('''CREATE TABLE employees(id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,phone_number TEXT DEFAULT '')''');
    await db.execute('''CREATE TABLE borrow_logs(id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_type TEXT NOT NULL,device_id INTEGER NOT NULL,device_name TEXT NOT NULL,
      device_number TEXT NOT NULL,employee_id INTEGER NOT NULL,employee_name TEXT NOT NULL,
      reason TEXT DEFAULT '',out_date TEXT NOT NULL,back_date TEXT,is_returned INTEGER DEFAULT 0)''');
    await db.execute('''CREATE TABLE mifis(id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_number TEXT NOT NULL,model TEXT NOT NULL,phone_number TEXT DEFAULT '',
      wifi_name TEXT DEFAULT '',wifi_password TEXT DEFAULT '',quota TEXT DEFAULT '',
      service_provider TEXT DEFAULT '',gateway TEXT DEFAULT '',admin_password TEXT DEFAULT '',
      status TEXT DEFAULT 'Available')''');
    await db.execute('''CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,item TEXT NOT NULL,price REAL DEFAULT 0.0,details TEXT DEFAULT '')''');
    await db.execute('''CREATE TABLE bills(id INTEGER PRIMARY KEY AUTOINCREMENT,
      person TEXT DEFAULT '',number TEXT NOT NULL,category TEXT NOT NULL,
      price REAL DEFAULT 0.0,notes TEXT DEFAULT '')''');
    await db.execute('''CREATE TABLE email_accounts(id INTEGER PRIMARY KEY AUTOINCREMENT,
      employee_id INTEGER,employee_name TEXT DEFAULT '',email TEXT NOT NULL,password TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE log_entries(id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,employee_id INTEGER,employee_name TEXT DEFAULT '',
      problem TEXT NOT NULL,solution TEXT DEFAULT '')''');
  }

  Future<void> _upgrade(Database db, int old, int next) async {
    if (old < 2) {
      try {
        await db.execute('''CREATE TABLE network_devices_v2(id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_number TEXT NOT NULL,model TEXT NOT NULL,phone_number TEXT DEFAULT '',
          device_location TEXT DEFAULT '',service_provider TEXT DEFAULT '',
          wifi_name TEXT DEFAULT '',wifi_password TEXT DEFAULT '',
          gateway TEXT DEFAULT '',admin_password TEXT DEFAULT '',status TEXT DEFAULT 'Available')''');
        await db.execute('''INSERT INTO network_devices_v2(id,device_number,model,phone_number,device_location,service_provider,status)
          SELECT id,device_number,model,phone_number,device_location,COALESCE(service_provider,''),COALESCE(status,'Available')
          FROM network_devices''');
        await db.execute('DROP TABLE network_devices');
        await db.execute('ALTER TABLE network_devices_v2 RENAME TO network_devices');
      } catch (_) {}
      await db.execute('''CREATE TABLE IF NOT EXISTS mifis(id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_number TEXT NOT NULL,model TEXT NOT NULL,phone_number TEXT DEFAULT '',
        wifi_name TEXT DEFAULT '',wifi_password TEXT DEFAULT '',quota TEXT DEFAULT '',
        service_provider TEXT DEFAULT '',gateway TEXT DEFAULT '',admin_password TEXT DEFAULT '',
        status TEXT DEFAULT 'Available')''');
      await db.execute('''CREATE TABLE IF NOT EXISTS expenses(id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,item TEXT NOT NULL,price REAL DEFAULT 0.0,details TEXT DEFAULT '')''');
    }
    if (old < 3) {
      try { await db.execute("ALTER TABLE mifis ADD COLUMN status TEXT DEFAULT 'Available'"); } catch (_) {}
    }
    if (old < 4) {
      await db.execute('''CREATE TABLE IF NOT EXISTS bills(id INTEGER PRIMARY KEY AUTOINCREMENT,
        person TEXT DEFAULT '',number TEXT NOT NULL,category TEXT NOT NULL,
        price REAL DEFAULT 0.0,notes TEXT DEFAULT '')''');
      await db.execute('''CREATE TABLE IF NOT EXISTS email_accounts(id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,employee_name TEXT DEFAULT '',email TEXT NOT NULL,password TEXT NOT NULL)''');
    }
    if (old < 5) {
      // Rebuild bills without the date column
      try {
        await db.execute('''CREATE TABLE bills_v5(id INTEGER PRIMARY KEY AUTOINCREMENT,
          person TEXT DEFAULT '',number TEXT NOT NULL,category TEXT NOT NULL,
          price REAL DEFAULT 0.0,notes TEXT DEFAULT '')''');
        await db.execute('''INSERT INTO bills_v5(id,person,number,category,price,notes)
          SELECT id,person,number,category,price,COALESCE(notes,'') FROM bills''');
        await db.execute('DROP TABLE bills');
        await db.execute('ALTER TABLE bills_v5 RENAME TO bills');
      } catch (_) {
        // Table may not have had date column (fresh v4 install) — no-op
      }
    }
    if (old < 6) {
      await db.execute('''CREATE TABLE IF NOT EXISTS log_entries(id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,employee_id INTEGER,employee_name TEXT DEFAULT '',
        problem TEXT NOT NULL,solution TEXT DEFAULT '')''');
    }
  }

  // Laptops
  Future<int> insertLaptop(Laptop l) async => (await db).insert('laptops', l.toMap());
  Future<List<Laptop>> getLaptops() async =>
    ((await db).query('laptops',orderBy:'laptop_number ASC')).then((r)=>r.map(Laptop.fromMap).toList());
  Future<int> updateLaptop(Laptop l) async =>
    (await db).update('laptops',l.toMap(),where:'id=?',whereArgs:[l.id]);
  Future<int> deleteLaptop(int id) async =>
    (await db).delete('laptops',where:'id=?',whereArgs:[id]);

  // Network Devices
  Future<int> insertNetworkDevice(NetworkDevice d) async =>
    (await db).insert('network_devices',d.toMap());
  Future<List<NetworkDevice>> getNetworkDevices() async =>
    ((await db).query('network_devices',orderBy:'device_number ASC')).then((r)=>r.map(NetworkDevice.fromMap).toList());
  Future<int> updateNetworkDevice(NetworkDevice d) async =>
    (await db).update('network_devices',d.toMap(),where:'id=?',whereArgs:[d.id]);
  Future<int> updateNetworkDeviceStatus(int id,String s) async =>
    (await db).update('network_devices',{'status':s},where:'id=?',whereArgs:[id]);
  Future<int> deleteNetworkDevice(int id) async =>
    (await db).delete('network_devices',where:'id=?',whereArgs:[id]);

  // Printers
  Future<int> insertPrinter(Printer p) async => (await db).insert('printers',p.toMap());
  Future<List<Printer>> getPrinters() async =>
    ((await db).query('printers',orderBy:'printer_number ASC')).then((r)=>r.map(Printer.fromMap).toList());
  Future<int> updatePrinter(Printer p) async =>
    (await db).update('printers',p.toMap(),where:'id=?',whereArgs:[p.id]);
  Future<int> deletePrinter(int id) async =>
    (await db).delete('printers',where:'id=?',whereArgs:[id]);

  // Electronics
  Future<int> insertElectronic(Electronic e) async =>
    (await db).insert('electronics',e.toMap());
  Future<List<Electronic>> getElectronics() async =>
    ((await db).query('electronics',orderBy:'device_number ASC')).then((r)=>r.map(Electronic.fromMap).toList());
  Future<int> updateElectronic(Electronic e) async =>
    (await db).update('electronics',e.toMap(),where:'id=?',whereArgs:[e.id]);
  Future<int> updateElectronicStatus(int id,String s) async =>
    (await db).update('electronics',{'status':s},where:'id=?',whereArgs:[id]);
  Future<int> deleteElectronic(int id) async =>
    (await db).delete('electronics',where:'id=?',whereArgs:[id]);

  // Employees
  Future<int> insertEmployee(Employee e) async =>
    (await db).insert('employees',e.toMap());
  Future<List<Employee>> getEmployees() async =>
    ((await db).query('employees',orderBy:'name ASC')).then((r)=>r.map(Employee.fromMap).toList());
  Future<int> updateEmployee(Employee e) async =>
    (await db).update('employees',e.toMap(),where:'id=?',whereArgs:[e.id]);
  Future<int> deleteEmployee(int id) async =>
    (await db).delete('employees',where:'id=?',whereArgs:[id]);

  // MiFis
  Future<int> insertMiFi(MiFi m) async => (await db).insert('mifis',m.toMap());
  Future<List<MiFi>> getMiFis() async =>
    ((await db).query('mifis',orderBy:'device_number ASC')).then((r)=>r.map(MiFi.fromMap).toList());
  Future<int> updateMiFi(MiFi m) async =>
    (await db).update('mifis',m.toMap(),where:'id=?',whereArgs:[m.id]);
  Future<int> updateMiFiStatus(int id,String s) async =>
    (await db).update('mifis',{'status':s},where:'id=?',whereArgs:[id]);
  Future<int> deleteMiFi(int id) async =>
    (await db).delete('mifis',where:'id=?',whereArgs:[id]);

  // Borrow Logs
  Future<int> insertBorrowLog(BorrowLog log) async {
    final database = await db;
    final id = await database.insert('borrow_logs',log.toMap());
    switch(log.deviceType) {
      case 'electronic': await updateElectronicStatus(log.deviceId,'Borrowed');
      case 'mifi': await updateMiFiStatus(log.deviceId,'Borrowed');
    }
    return id;
  }
  Future<List<BorrowLog>> getBorrowLogs() async =>
    ((await db).query('borrow_logs',orderBy:'out_date DESC,id DESC')).then((r)=>r.map(BorrowLog.fromMap).toList());
  Future<void> markReturned(int logId,int deviceId,String deviceType,String backDate) async {
    final database = await db;
    await database.update('borrow_logs',{'is_returned':1,'back_date':backDate},where:'id=?',whereArgs:[logId]);
    switch(deviceType) {
      case 'electronic': await updateElectronicStatus(deviceId,'Available');
      case 'mifi': await updateMiFiStatus(deviceId,'Available');
    }
  }
  Future<int> deleteBorrowLog(int id) async =>
    (await db).delete('borrow_logs',where:'id=?',whereArgs:[id]);

  // Expenses
  Future<int> insertExpense(Expense e) async => (await db).insert('expenses',e.toMap());
  Future<List<Expense>> getExpenses() async =>
    ((await db).query('expenses',orderBy:'date DESC,id DESC')).then((r)=>r.map(Expense.fromMap).toList());
  Future<int> updateExpense(Expense e) async =>
    (await db).update('expenses',e.toMap(),where:'id=?',whereArgs:[e.id]);
  Future<int> deleteExpense(int id) async =>
    (await db).delete('expenses',where:'id=?',whereArgs:[id]);
  Future<List<Expense>> getExpensesByYear(int year) async =>
    ((await db).query('expenses',where:"date LIKE '$year%'",orderBy:'date DESC')).then((r)=>r.map(Expense.fromMap).toList());
  Future<List<Expense>> getExpensesByMonth(int year,int month) async {
    final prefix='$year-${month.toString().padLeft(2,'0')}';
    return ((await db).query('expenses',where:"date LIKE '$prefix%'",orderBy:'date DESC')).then((r)=>r.map(Expense.fromMap).toList());
  }
  Future<List<int>> getExpenseYears() async {
    final rows = await (await db).rawQuery("SELECT DISTINCT substr(date,1,4) as y FROM expenses ORDER BY y DESC");
    return rows.map((r)=>int.tryParse(r['y'] as String? ?? '')??0).where((y)=>y>0).toList();
  }

  // Bills
  Future<int> insertBill(Bill b) async => (await db).insert('bills',b.toMap());
  Future<List<Bill>> getBills() async =>
    ((await db).query('bills',orderBy:'id DESC')).then((r)=>r.map(Bill.fromMap).toList());
  Future<int> updateBill(Bill b) async =>
    (await db).update('bills',b.toMap(),where:'id=?',whereArgs:[b.id]);
  Future<int> deleteBill(int id) async =>
    (await db).delete('bills',where:'id=?',whereArgs:[id]);

  // Email Accounts
  Future<int> insertEmailAccount(EmailAccount e) async =>
    (await db).insert('email_accounts',e.toMap());
  Future<List<EmailAccount>> getEmailAccounts() async =>
    ((await db).query('email_accounts',orderBy:'employee_name ASC,email ASC')).then((r)=>r.map(EmailAccount.fromMap).toList());
  Future<int> updateEmailAccount(EmailAccount e) async =>
    (await db).update('email_accounts',e.toMap(),where:'id=?',whereArgs:[e.id]);
  Future<int> deleteEmailAccount(int id) async =>
    (await db).delete('email_accounts',where:'id=?',whereArgs:[id]);

  // Log Entries
  Future<int> insertLogEntry(LogEntry e) async => (await db).insert('log_entries', e.toMap());
  Future<List<LogEntry>> getLogEntries() async =>
    ((await db).query('log_entries', orderBy: 'date DESC,id DESC')).then((r) => r.map(LogEntry.fromMap).toList());
  Future<List<LogEntry>> getLogEntriesByYear(int year) async =>
    ((await db).query('log_entries', where: "date LIKE '$year%'", orderBy: 'date DESC,id DESC'))
      .then((r) => r.map(LogEntry.fromMap).toList());
  Future<List<LogEntry>> getLogEntriesByMonth(int year, int month) async {
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    return ((await db).query('log_entries', where: "date LIKE '$prefix%'", orderBy: 'date DESC,id DESC'))
      .then((r) => r.map(LogEntry.fromMap).toList());
  }
  Future<List<int>> getLogYears() async {
    final rows = await (await db).rawQuery("SELECT DISTINCT substr(date,1,4) as y FROM log_entries ORDER BY y DESC");
    return rows.map((r) => int.tryParse(r['y'] as String? ?? '') ?? 0).where((y) => y > 0).toList();
  }
  Future<int> updateLogEntry(LogEntry e) async =>
    (await db).update('log_entries', e.toMap(), where: 'id=?', whereArgs: [e.id]);
  Future<int> deleteLogEntry(int id) async =>
    (await db).delete('log_entries', where: 'id=?', whereArgs: [id]);

  // Backup / Restore
  Future<String> exportJson() async {
    final database = await db;
    return jsonEncode({
      'version':4,'exported_at':DateTime.now().toIso8601String(),
      'laptops':await database.query('laptops'),
      'network_devices':await database.query('network_devices'),
      'printers':await database.query('printers'),
      'electronics':await database.query('electronics'),
      'employees':await database.query('employees'),
      'borrow_logs':await database.query('borrow_logs'),
      'mifis':await database.query('mifis'),
      'expenses':await database.query('expenses'),
      'bills':await database.query('bills'),
      'email_accounts':await database.query('email_accounts'),
      'log_entries':await database.query('log_entries'),
    });
  }

  Future<void> importJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String,dynamic>;
    final database = await db;
    await database.transaction((txn) async {
      for (final t in ['borrow_logs','laptops','network_devices','printers',
          'electronics','employees','mifis','expenses','bills','email_accounts','log_entries']) {
        await txn.delete(t);
        final rows = data[t] as List<dynamic>? ?? [];
        for (final row in rows) {
          await txn.insert(t,Map<String,dynamic>.from(row as Map));
        }
      }
    });
  }

  Future<Map<String,int>> getCounts() async {
    final database = await db;
    int c(List<Map> r) => r.first.values.first as int;
    return {
      'laptops':c(await database.rawQuery('SELECT COUNT(*) FROM laptops')),
      'network_devices':c(await database.rawQuery('SELECT COUNT(*) FROM network_devices')),
      'printers':c(await database.rawQuery('SELECT COUNT(*) FROM printers')),
      'electronics':c(await database.rawQuery('SELECT COUNT(*) FROM electronics')),
      'employees':c(await database.rawQuery('SELECT COUNT(*) FROM employees')),
      'mifis':c(await database.rawQuery('SELECT COUNT(*) FROM mifis')),
      'expenses':c(await database.rawQuery('SELECT COUNT(*) FROM expenses')),
      'bills':c(await database.rawQuery('SELECT COUNT(*) FROM bills')),
      'email_accounts':c(await database.rawQuery('SELECT COUNT(*) FROM email_accounts')),
      'active_borrows':c(await database.rawQuery('SELECT COUNT(*) FROM borrow_logs WHERE is_returned=0')),
      'log_entries':c(await database.rawQuery('SELECT COUNT(*) FROM log_entries')),
    };
  }
}
