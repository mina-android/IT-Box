// lib/database/app_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite show getDatabasesPath;
import 'tables.dart';

part 'app_database.g.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await sqflite.getDatabasesPath();
    final file = File(p.join(dbFolder, 'itbox.db'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [
  Laptops,
  NetworkDevices,
  Printers,
  Electronics,
  Employees,
  BorrowLogs,
  Mifis,
  Expenses,
  Bills,
  EmailAccounts,
  LogEntries,
  Subscriptions,
  AccessPoints,
  DeviceMaintenanceLogs,
  Consumables,
  ConsumableLogs,
  StaticIps,
  SwitchPatchPorts,
  AuditActivities,
  SoftDeletes,
  WifiNetworks,
  AccountPasswords,
  OtherDevices,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase();
  static set testInstance(AppDatabase? db) => _instance = db;

  static const int currentVersion = 14;

  @override
  int get schemaVersion => currentVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            try {
              await customStatement('''CREATE TABLE IF NOT EXISTS network_devices_v2(id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_number TEXT NOT NULL,model TEXT NOT NULL,phone_number TEXT DEFAULT '',
                device_location TEXT DEFAULT '',service_provider TEXT DEFAULT '',
                wifi_name TEXT DEFAULT '',wifi_password TEXT DEFAULT '',
                gateway TEXT DEFAULT '',admin_password TEXT DEFAULT '',status TEXT DEFAULT 'Available')''');
              await customStatement('''INSERT INTO network_devices_v2(id,device_number,model,phone_number,device_location,service_provider,status)
                SELECT id,device_number,model,phone_number,device_location,COALESCE(service_provider,''),COALESCE(status,'Available')
                FROM network_devices''');
              await customStatement('DROP TABLE network_devices');
              await customStatement('ALTER TABLE network_devices_v2 RENAME TO network_devices');
            } catch (_) {}
            await customStatement('''CREATE TABLE IF NOT EXISTS mifis(id INTEGER PRIMARY KEY AUTOINCREMENT,
              device_number TEXT NOT NULL,model TEXT NOT NULL,phone_number TEXT DEFAULT '',
              wifi_name TEXT DEFAULT '',wifi_password TEXT DEFAULT '',quota TEXT DEFAULT '',
              service_provider TEXT DEFAULT '',gateway TEXT DEFAULT '',admin_password TEXT DEFAULT '',
              status TEXT DEFAULT 'Available')''');
            await customStatement('''CREATE TABLE IF NOT EXISTS expenses(id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,item TEXT NOT NULL,price REAL DEFAULT 0.0,details TEXT DEFAULT '')''');
          }
          if (from < 3) {
            try {
              await customStatement("ALTER TABLE mifis ADD COLUMN status TEXT DEFAULT 'Available'");
            } catch (_) {}
          }
          if (from < 4) {
            await customStatement('''CREATE TABLE IF NOT EXISTS bills(id INTEGER PRIMARY KEY AUTOINCREMENT,
              person TEXT DEFAULT '',number TEXT NOT NULL,category TEXT NOT NULL,
              price REAL DEFAULT 0.0,notes TEXT DEFAULT '')''');
            await customStatement('''CREATE TABLE IF NOT EXISTS email_accounts(id INTEGER PRIMARY KEY AUTOINCREMENT,
              employee_id INTEGER,employee_name TEXT DEFAULT '',email TEXT NOT NULL,password TEXT NOT NULL)''');
          }
          if (from < 5) {
            try {
              await customStatement('''CREATE TABLE IF NOT EXISTS bills_v5(id INTEGER PRIMARY KEY AUTOINCREMENT,
                person TEXT DEFAULT '',number TEXT NOT NULL,category TEXT NOT NULL,
                price REAL DEFAULT 0.0,notes TEXT DEFAULT '')''');
              await customStatement('''INSERT INTO bills_v5(id,person,number,category,price,notes)
                SELECT id,person,number,category,price,COALESCE(notes,'') FROM bills''');
              await customStatement('DROP TABLE bills');
              await customStatement('ALTER TABLE bills_v5 RENAME TO bills');
            } catch (_) {}
          }
          if (from < 6) {
            await customStatement('''CREATE TABLE IF NOT EXISTS log_entries(id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,employee_id INTEGER,employee_name TEXT DEFAULT '',
              problem TEXT NOT NULL,solution TEXT DEFAULT '')''');
          }
          if (from < 7) {
            try {
              await customStatement("ALTER TABLE borrow_logs ADD COLUMN due_date TEXT");
            } catch (_) {}
            await customStatement('''CREATE TABLE IF NOT EXISTS subscriptions(id INTEGER PRIMARY KEY AUTOINCREMENT,
              service TEXT NOT NULL,type TEXT NOT NULL,price REAL DEFAULT 0.0,
              renewal_date TEXT DEFAULT '',notes TEXT DEFAULT '')''');
          }
          if (from < 8) {
            await customStatement('''CREATE TABLE IF NOT EXISTS access_points(id INTEGER PRIMARY KEY AUTOINCREMENT,
              device_number TEXT NOT NULL,model TEXT NOT NULL,port_number TEXT DEFAULT '',location TEXT DEFAULT '')''');
          }
          if (from < 9) {
            try {
              await customStatement("ALTER TABLE log_entries ADD COLUMN state TEXT DEFAULT 'Open'");
            } catch (_) {}
          }
          if (from < 10) {
            try {
              await customStatement("ALTER TABLE borrow_logs ADD COLUMN reminder_time TEXT");
            } catch (_) {}
          }
          if (from < 11) {
            try {
              await customStatement("ALTER TABLE log_entries ADD COLUMN priority TEXT DEFAULT 'Low'");
              await customStatement("ALTER TABLE mifis ADD COLUMN exclude_borrowing INTEGER DEFAULT 0");
              await customStatement("ALTER TABLE mifis ADD COLUMN tag TEXT DEFAULT ''");
              await customStatement("ALTER TABLE electronics ADD COLUMN exclude_borrowing INTEGER DEFAULT 0");
            } catch (_) {}
          }
          if (from < 12) {
            try {
              await customStatement('''CREATE TABLE IF NOT EXISTS device_maintenance_logs(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_type TEXT NOT NULL,
                device_id INTEGER NOT NULL,
                date TEXT NOT NULL,
                service_type TEXT DEFAULT 'Maintenance',
                cost REAL DEFAULT 0.0,
                details TEXT DEFAULT '',
                performed_by TEXT DEFAULT ''
              )''');
              await customStatement('''CREATE TABLE IF NOT EXISTS consumables(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                item_name TEXT NOT NULL,
                category TEXT DEFAULT 'General',
                quantity INTEGER DEFAULT 0,
                minimum_threshold INTEGER DEFAULT 5,
                location TEXT DEFAULT '',
                unit_price REAL DEFAULT 0.0
              )''');
              await customStatement('''CREATE TABLE IF NOT EXISTS consumable_logs(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                consumable_id INTEGER NOT NULL,
                employee_id INTEGER,
                change_amount INTEGER NOT NULL,
                reason TEXT DEFAULT '',
                date TEXT NOT NULL
              )''');
              await customStatement('''CREATE TABLE IF NOT EXISTS static_ips(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ip_address TEXT NOT NULL,
                subnet_mask TEXT DEFAULT '255.255.255.0',
                assigned_device TEXT NOT NULL,
                device_type TEXT DEFAULT 'Other',
                mac_address TEXT DEFAULT '',
                notes TEXT DEFAULT ''
              )''');
              await customStatement('''CREATE TABLE IF NOT EXISTS switch_patch_ports(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                switch_device_id INTEGER NOT NULL,
                port_number INTEGER NOT NULL,
                connected_device TEXT DEFAULT '',
                destination_room TEXT DEFAULT '',
                vlan TEXT DEFAULT '1',
                status TEXT DEFAULT 'Active'
              )''');
              await customStatement('''CREATE TABLE IF NOT EXISTS audit_activities(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                action_type TEXT NOT NULL,
                entity_type TEXT NOT NULL,
                entity_id INTEGER,
                description TEXT NOT NULL,
                timestamp TEXT NOT NULL
              )''');
              await customStatement('''CREATE TABLE IF NOT EXISTS soft_deletes(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                original_table TEXT NOT NULL,
                original_id INTEGER NOT NULL,
                display_name TEXT NOT NULL,
                serialized_data TEXT NOT NULL,
                deleted_at TEXT NOT NULL
              )''');
            } catch (_) {}
          }
          if (from < 13) {
            try {
              await customStatement('''CREATE TABLE IF NOT EXISTS wifi_networks(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                network_name TEXT NOT NULL,
                password TEXT DEFAULT '',
                phone_number TEXT DEFAULT '',
                location_device TEXT DEFAULT '',
                admin_username TEXT DEFAULT '',
                admin_password TEXT DEFAULT '',
                notes TEXT DEFAULT '',
                created_at TEXT
              )''');
              await customStatement('''CREATE TABLE IF NOT EXISTS account_passwords(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                platform TEXT NOT NULL,
                email_username TEXT NOT NULL,
                password TEXT NOT NULL,
                created_at TEXT
              )''');
              await customStatement('''CREATE TABLE IF NOT EXISTS other_devices(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_type TEXT NOT NULL,
                device_name TEXT NOT NULL,
                model TEXT DEFAULT '',
                notes TEXT DEFAULT '',
                created_at TEXT
              )''');
            } catch (_) {}
          }
          if (from < 14) {
            Future<void> addColIfMissing(String table, String col, String ddl) async {
              try {
                final info = await customSelect("PRAGMA table_info($table)").get();
                final colNames = info.map((r) => r.data['name'] as String).toSet();
                if (!colNames.contains(col)) {
                  await customStatement("ALTER TABLE $table ADD COLUMN $ddl");
                }
              } catch (_) {}
            }

            // Heal any partial migrations from v7-v13
            await addColIfMissing('borrow_logs', 'due_date', 'due_date TEXT');
            await addColIfMissing('borrow_logs', 'reminder_time', 'reminder_time TEXT');
            await addColIfMissing('log_entries', 'state', "state TEXT DEFAULT 'Open'");
            await addColIfMissing('log_entries', 'priority', "priority TEXT DEFAULT 'Low'");
            await addColIfMissing('mifis', 'exclude_borrowing', "exclude_borrowing INTEGER DEFAULT 0");
            await addColIfMissing('mifis', 'tag', "tag TEXT DEFAULT ''");
            await addColIfMissing('electronics', 'exclude_borrowing', "exclude_borrowing INTEGER DEFAULT 0");

            // Performance indexes
            try {
              await customStatement("CREATE INDEX IF NOT EXISTS idx_borrow_logs_active ON borrow_logs(is_returned)");
              await customStatement("CREATE INDEX IF NOT EXISTS idx_borrow_logs_dev ON borrow_logs(device_type, device_id, is_returned)");
              await customStatement("CREATE INDEX IF NOT EXISTS idx_log_entries_date ON log_entries(date)");
              await customStatement("CREATE INDEX IF NOT EXISTS idx_log_entries_state ON log_entries(state)");
              await customStatement("CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)");
              await customStatement("CREATE INDEX IF NOT EXISTS idx_switch_ports ON switch_patch_ports(switch_device_id, port_number)");
            } catch (_) {}
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );
}
