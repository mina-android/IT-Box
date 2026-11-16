// lib/database/app_database.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite show getDatabasesPath;
import 'tables.dart';

part 'app_database.g.dart';

LazyDatabase openDatabaseConnection([String dbFileName = 'itbox.db']) {
  return LazyDatabase(() async {
    final dbFolder = await sqflite.getDatabasesPath();
    final file = File(p.join(dbFolder, dbFileName));
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
  StaticIps,
  SwitchPatchPorts,
  AuditActivities,
  WifiNetworks,
  AccountPasswords,
  OtherDevices,
  VendorContacts,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openDatabaseConnection());

  static AppDatabase? _instance;
  static String activeDatabaseFile = 'itbox.db';

  static AppDatabase get instance => _instance ??= AppDatabase(openDatabaseConnection(activeDatabaseFile));
  static set testInstance(AppDatabase? db) => _instance = db;

  /// Resets the singleton instance to point to a specific workspace database file.
  static Future<void> switchDatabaseInstance(String newFileName) async {
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
    }
    activeDatabaseFile = newFileName;
    _instance = AppDatabase(openDatabaseConnection(activeDatabaseFile));
  }

  /// Permanently deletes an organization's SQLite database file and companion WAL/SHM files.
  static Future<void> deleteDatabaseFile(String dbFileName) async {
    if (dbFileName == 'itbox.db' || dbFileName.isEmpty) {
      return;
    }
    try {
      final dbFolder = await sqflite.getDatabasesPath();
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final f = File(p.join(dbFolder, '$dbFileName$suffix'));
        if (await f.exists()) {
          await f.delete();
        }
      }
    } catch (_) {}
  }

  static const int currentVersion = 15;

  @override
  int get schemaVersion => currentVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          void logMigration(int version, Object err) {
            debugPrint('Migration notice (from $version to $to): $err');
          }

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
            } catch (e) {
              logMigration(1, e);
            }
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
            } catch (e) {
              logMigration(2, e);
            }
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
            } catch (e) {
              logMigration(4, e);
            }
          }
          if (from < 6) {
            await customStatement('''CREATE TABLE IF NOT EXISTS log_entries(id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,employee_id INTEGER,employee_name TEXT DEFAULT '',
              problem TEXT NOT NULL,solution TEXT DEFAULT '')''');
          }
          if (from < 7) {
            try {
              await customStatement("ALTER TABLE borrow_logs ADD COLUMN due_date TEXT");
            } catch (e) {
              logMigration(6, e);
            }
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
            } catch (e) {
              logMigration(8, e);
            }
          }
          if (from < 10) {
            try {
              await customStatement("ALTER TABLE borrow_logs ADD COLUMN reminder_time TEXT");
            } catch (e) {
              logMigration(9, e);
            }
          }
          if (from < 11) {
            try {
              await customStatement("ALTER TABLE log_entries ADD COLUMN priority TEXT DEFAULT 'Low'");
              await customStatement("ALTER TABLE mifis ADD COLUMN exclude_borrowing INTEGER DEFAULT 0");
              await customStatement("ALTER TABLE mifis ADD COLUMN tag TEXT DEFAULT ''");
              await customStatement("ALTER TABLE electronics ADD COLUMN exclude_borrowing INTEGER DEFAULT 0");
            } catch (e) {
              logMigration(10, e);
            }
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
            } catch (e) {
              logMigration(11, e);
            }
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
            } catch (e) {
              logMigration(12, e);
            }
          }

          Future<void> addColIfMissing(String table, String col, String ddl) async {
            try {
              final info = await customSelect("PRAGMA table_info($table)").get();
              final colNames = info.map((r) => r.data['name'] as String).toSet();
              if (!colNames.contains(col)) {
                await customStatement("ALTER TABLE $table ADD COLUMN $ddl");
              }
            } catch (e) {
              logMigration(13, 'Failed addColIfMissing $table.$col: $e');
            }
          }

          if (from < 14) {
            // Heal any partial migrations from v7-v13
            await addColIfMissing('borrow_logs', 'due_date', 'due_date TEXT');
            await addColIfMissing('borrow_logs', 'reminder_time', 'reminder_time TEXT');
            await addColIfMissing('log_entries', 'state', "state TEXT DEFAULT 'Open'");
            await addColIfMissing('log_entries', 'priority', "priority TEXT DEFAULT 'Low'");
            await addColIfMissing('mifis', 'exclude_borrowing', "exclude_borrowing INTEGER DEFAULT 0");
            await addColIfMissing('mifis', 'tag', "tag TEXT DEFAULT ''");
            await addColIfMissing('electronics', 'exclude_borrowing', "exclude_borrowing INTEGER DEFAULT 0");

            // Performance indexes
            await customStatement("CREATE INDEX IF NOT EXISTS idx_borrow_logs_active ON borrow_logs(is_returned)");
            await customStatement("CREATE INDEX IF NOT EXISTS idx_borrow_logs_dev ON borrow_logs(device_type, device_id, is_returned)");
            await customStatement("CREATE INDEX IF NOT EXISTS idx_log_entries_date ON log_entries(date)");
            await customStatement("CREATE INDEX IF NOT EXISTS idx_log_entries_state ON log_entries(state)");
            await customStatement("CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)");
            await customStatement("CREATE INDEX IF NOT EXISTS idx_switch_ports ON switch_patch_ports(switch_device_id, port_number)");
          }

          if (from < 15) {
            // Drop unused/dead tables
            await customStatement('DROP TABLE IF EXISTS consumable_logs');
            await customStatement('DROP TABLE IF EXISTS consumables');
            await customStatement('DROP TABLE IF EXISTS soft_deletes');

            // Add vendor_contacts table
            await customStatement('''CREATE TABLE IF NOT EXISTS vendor_contacts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              contact_type TEXT NOT NULL,
              name TEXT NOT NULL,
              company TEXT DEFAULT '',
              role TEXT DEFAULT '',
              phone_number TEXT DEFAULT '',
              email TEXT DEFAULT '',
              portal_url TEXT DEFAULT '',
              account_number TEXT DEFAULT '',
              notes TEXT DEFAULT '',
              created_at TEXT
            )''');

            // Add quick technician notes to inventory assets
            for (final tbl in [
              'laptops',
              'network_devices',
              'mifis',
              'printers',
              'electronics',
              'access_points',
              'other_devices',
              'subscriptions',
            ]) {
              await addColIfMissing(tbl, 'notes', "notes TEXT DEFAULT ''");
            }

            // Add planned maintenance columns
            await addColIfMissing('device_maintenance_logs', 'is_planned', 'is_planned INTEGER DEFAULT 0');
            await addColIfMissing('device_maintenance_logs', 'planned_date', "planned_date TEXT DEFAULT ''");
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );
}
