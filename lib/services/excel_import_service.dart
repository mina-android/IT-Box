import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';
import '../models/laptop.dart';
import '../models/network_device.dart';
import '../models/mifi.dart';
import '../models/printer.dart';
import '../models/electronic.dart';
import '../models/employee.dart';
import '../models/bill.dart';
import '../models/expense.dart';
import '../models/email_account.dart';
import '../models/log_entry.dart';
import '../models/subscription.dart';
import '../models/access_point.dart';
import '../models/other_device.dart';

/// Result of an import operation
class ImportResult {
  final int inserted;
  final int skipped;
  final List<String> errors;
  const ImportResult({required this.inserted, required this.skipped, this.errors = const []});
  bool get success => errors.isEmpty || inserted > 0;
  String get summary => '$inserted imported, $skipped skipped'
      '${errors.isNotEmpty ? ", ${errors.length} errors" : ""}';
}

// Top-level function for isolate
Excel? _decodeExcel(List<int> bytes) => Excel.decodeBytes(bytes);

class ExcelImportService {
  static final _db = DatabaseHelper();

  // ── Pick file ─────────────────────────────────────────────────
  static Future<Excel?> pickExcel() async {
    final result = await FilePickerPlatform.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result.isEmpty) return null;
    final bytes = await result.first.readAsBytes();
    return await compute(_decodeExcel, bytes);
  }

  // ── Cell value helper ─────────────────────────────────────────
  static String _str(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final v = cell.value;
    if (v is TextCellValue) return v.value.toString().trim();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toString().trim();
    if (v is BoolCellValue) return v.value.toString();
    return v.toString().trim();
  }

  static double _dbl(Data? cell) => double.tryParse(_str(cell)) ?? 0.0;

  // ── Get rows (skip header row 0, skip empty rows) ─────────────
  static List<List<Data?>> _rows(Sheet sheet) {
    final rows = sheet.rows;
    if (rows.length <= 1) return [];
    return rows.sublist(1).where((row) {
      // Skip if all cells are empty
      return row.any((c) => c != null && c.value != null && _str(c).isNotEmpty);
    }).toList();
  }

  static Future<ImportResult> _executeBatchImport<T>({
    required String tableName,
    required List<T> items,
    required int skipped,
    required List<String> errors,
    required bool replace,
    required Future<void> Function(T item) inserter,
  }) async {
    if (items.isEmpty) {
      return ImportResult(
        inserted: 0,
        skipped: skipped,
        errors: [
          if (replace) 'No valid records found in file. Import aborted to prevent data loss.'
          else if (errors.isEmpty) 'No valid records found in file.'
          else ...errors,
        ],
      );
    }

    int inserted = 0;
    await _db.batchScope(() async {
      await _db.drift.transaction(() async {
        if (replace) {
          await _db.deleteTable(tableName);
        }
        for (final item in items) {
          await inserter(item);
          inserted++;
        }
      });
    });

    return ImportResult(inserted: inserted, skipped: skipped, errors: errors);
  }

  // ── LAPTOPS ──────────────────────────────────────────────────
  // Expected columns: #, Laptop No., Model, CPU, GPU, RAM, Storage, Condition, User
  static Future<ImportResult> importLaptops(Excel excel, {bool replace = false}) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    final items = <Laptop>[];
    int skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final num  = _str(row.length > 1 ? row[1] : null); // col 1
        final model= _str(row.length > 2 ? row[2] : null);
        if (num.isEmpty || model.isEmpty) { skipped++; continue; }
        items.add(Laptop(
          laptopNumber: num,
          model:        model,
          cpu:          _str(row.length > 3 ? row[3] : null),
          gpu:          _str(row.length > 4 ? row[4] : null),
          ram:          _str(row.length > 5 ? row[5] : null),
          storage:      _str(row.length > 6 ? row[6] : null),
          condition:    _str(row.length > 7 ? row[7] : null).isEmpty ? 'Good' : _str(row[7]),
          user:         _str(row.length > 8 ? row[8] : null),
        ));
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }

    return _executeBatchImport<Laptop>(
      tableName: 'laptops',
      items: items,
      skipped: skipped,
      errors: errors,
      replace: replace,
      inserter: (l) => _db.insertLaptop(l),
    );
  }

  // ── NETWORK DEVICES ──────────────────────────────────────────
  // Columns: #, Device No., Model, Phone No., Location, Provider, WiFi Name, Status
  static Future<ImportResult> importNetworkDevices(Excel excel, {bool replace = false}) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    final items = <NetworkDevice>[];
    int skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final num  = _str(row.length > 1 ? row[1] : null);
        final model= _str(row.length > 2 ? row[2] : null);
        if (num.isEmpty || model.isEmpty) { skipped++; continue; }
        items.add(NetworkDevice(
          deviceNumber:   num,
          model:          model,
          phoneNumber:    _str(row.length > 3 ? row[3] : null),
          deviceLocation: _str(row.length > 4 ? row[4] : null),
          serviceProvider:_str(row.length > 5 ? row[5] : null),
          wifiName:       _str(row.length > 6 ? row[6] : null),
          status:         'Available',
        ));
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }

    return _executeBatchImport<NetworkDevice>(
      tableName: 'network_devices',
      items: items,
      skipped: skipped,
      errors: errors,
      replace: replace,
      inserter: (d) => _db.insertNetworkDevice(d),
    );
  }

  // ── MIFIS ────────────────────────────────────────────────────
  // Columns: #, Device No., Model, Phone No., WiFi Name, Quota, Provider, Status
  static Future<ImportResult> importMiFis(Excel excel, {bool replace = false}) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    final items = <MiFi>[];
    int skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final num  = _str(row.length > 1 ? row[1] : null);
        final model= _str(row.length > 2 ? row[2] : null);
        if (num.isEmpty || model.isEmpty) { skipped++; continue; }
        items.add(MiFi(
          deviceNumber:   num,
          model:          model,
          phoneNumber:    _str(row.length > 3 ? row[3] : null),
          wifiName:       _str(row.length > 4 ? row[4] : null),
          quota:          _str(row.length > 5 ? row[5] : null),
          serviceProvider:_str(row.length > 6 ? row[6] : null),
          status:         'Available',
        ));
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }

    return _executeBatchImport<MiFi>(
      tableName: 'mifis',
      items: items,
      skipped: skipped,
      errors: errors,
      replace: replace,
      inserter: (m) => _db.insertMiFi(m),
    );
  }

  // ── PRINTERS ─────────────────────────────────────────────────
  // Columns: #, Printer No., Model, Condition, Location
  static Future<ImportResult> importPrinters(Excel excel, {bool replace = false}) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    final items = <Printer>[];
    int skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final num  = _str(row.length > 1 ? row[1] : null);
        final model= _str(row.length > 2 ? row[2] : null);
        if (num.isEmpty || model.isEmpty) { skipped++; continue; }
        items.add(Printer(
          printerNumber: num,
          model:         model,
          condition:     _str(row.length > 3 ? row[3] : null).isEmpty ? 'Good' : _str(row[3]),
          location:      _str(row.length > 4 ? row[4] : null),
        ));
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }

    return _executeBatchImport<Printer>(
      tableName: 'printers',
      items: items,
      skipped: skipped,
      errors: errors,
      replace: replace,
      inserter: (p) => _db.insertPrinter(p),
    );
  }

  // ── ELECTRONICS ──────────────────────────────────────────────
  // Columns: #, Device No., Device Name, Details, Status
  static Future<ImportResult> importElectronics(Excel excel, {bool replace = false}) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    final items = <Electronic>[];
    int skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final num  = _str(row.length > 1 ? row[1] : null);
        final name = _str(row.length > 2 ? row[2] : null);
        if (num.isEmpty || name.isEmpty) { skipped++; continue; }
        items.add(Electronic(
          deviceNumber: num,
          deviceName:   name,
          details:      _str(row.length > 3 ? row[3] : null),
          status:       'Available',
        ));
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }

    return _executeBatchImport<Electronic>(
      tableName: 'electronics',
      items: items,
      skipped: skipped,
      errors: errors,
      replace: replace,
      inserter: (e) => _db.insertElectronic(e),
    );
  }

  // ── EMPLOYEES ────────────────────────────────────────────────
  // Columns: #, Name, Phone Number
  static Future<ImportResult> importEmployees(Excel excel, {bool replace = false}) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    final items = <Employee>[];
    int skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final name = _str(row.length > 1 ? row[1] : null);
        if (name.isEmpty) { skipped++; continue; }
        items.add(Employee(
          name:        name,
          phoneNumber: _str(row.length > 2 ? row[2] : null),
        ));
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }

    return _executeBatchImport<Employee>(
      tableName: 'employees',
      items: items,
      skipped: skipped,
      errors: errors,
      replace: replace,
      inserter: (e) => _db.insertEmployee(e),
    );
  }

  // ── BILLS ─────────────────────────────────────────────────────
  // Columns: #, Person, Number, Category, Price (EGP), Notes
  static Future<ImportResult> importBills(Excel excel, {bool replace = false}) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    final items = <Bill>[];
    int skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final number = _str(row.length > 2 ? row[2] : null);
        if (number.isEmpty) { skipped++; continue; }
        final rawCat = _str(row.length > 3 ? row[3] : null);
        final catMatch = Bill.categories.firstWhere(
          (c) => c.toLowerCase() == rawCat.toLowerCase(),
          orElse: () => Bill.categories.first,
        );
        items.add(Bill(
          person:   _str(row.length > 1 ? row[1] : null),
          number:   number,
          category: catMatch,
          price:    _dbl(row.length > 4 ? row[4] : null),
          notes:    _str(row.length > 5 ? row[5] : null),
        ));
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }

    return _executeBatchImport<Bill>(
      tableName: 'bills',
      items: items,
      skipped: skipped,
      errors: errors,
      replace: replace,
      inserter: (b) => _db.insertBill(b),
    );
  }

  // ── EXPENSES ─────────────────────────────────────────────────
  // Columns: Date, Item, Price (EGP), Details
  static Future<ImportResult> importExpenses(Excel excel, {bool replace = false}) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    final items = <Expense>[];
    int skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        // Skip the TOTAL summary row that ExcelService adds
        final col0 = _str(row.isNotEmpty ? row[0] : null);
        if (col0.toUpperCase() == 'TOTAL') { skipped++; continue; }

        final date = _str(row.isNotEmpty ? row[0] : null);
        final item = _str(row.length > 1 ? row[1] : null);
        if (item.isEmpty) { skipped++; continue; }

        // Normalise date: accept "dd MMM yyyy", "yyyy-MM-dd", or Excel serial
        String normDate = _normalizeDate(date);

        items.add(Expense(
          date:    normDate,
          item:    item,
          price:   _dbl(row.length > 2 ? row[2] : null),
          details: _str(row.length > 3 ? row[3] : null),
        ));
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }

    return _executeBatchImport<Expense>(
      tableName: 'expenses',
      items: items,
      skipped: skipped,
      errors: errors,
      replace: replace,
      inserter: (e) => _db.insertExpense(e),
    );
  }

  // ── EMAIL ACCOUNTS ───────────────────────────────────────────
  // Columns: #, Employee, Email, Password(hidden)
  static Future<ImportResult> importEmailAccounts(Excel excel, {bool replace = false}) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    final items = <EmailAccount>[];
    int skipped = 0;
    final errors = <String>[];
    int maskedOrEmptyPassCount = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final email = _str(row.length > 2 ? row[2] : null);
        if (email.isEmpty || !email.contains('@')) { skipped++; continue; }
        final pass = _str(row.length > 3 ? row[3] : null);
        if (pass == '(hidden)' || pass == '••••••' || pass.isEmpty) {
          maskedOrEmptyPassCount++;
          skipped++;
          continue;
        }
        items.add(EmailAccount(
          employeeName: _str(row.length > 1 ? row[1] : null),
          email:        email,
          password:     pass,
        ));
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }

    if (replace && items.isEmpty && maskedOrEmptyPassCount > 0) {
      return ImportResult(
        inserted: 0,
        skipped: skipped,
        errors: const ['No accounts with valid passwords found. Passwords in exported files are hidden for security and cannot replace database accounts.'],
      );
    }

    return _executeBatchImport<EmailAccount>(
      tableName: 'email_accounts',
      items: items,
      skipped: skipped,
      errors: errors,
      replace: replace,
      inserter: (e) => _db.insertEmailAccount(e),
    );
  }

  // ── SUBSCRIPTIONS ─────────────────────────────────────────────
  // Columns: #, Service Name, Billing Interval, Price (EGP), Renewal Date, Notes
  static Future<ImportResult> importSubscriptions(Excel excel, {bool replace = false}) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    final items = <Subscription>[];
    int skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final service = _str(row.length > 1 ? row[1] : null);
        if (service.isEmpty) { skipped++; continue; }
        final rawType = _str(row.length > 2 ? row[2] : null);
        final typeMatch = Subscription.types.firstWhere(
          (t) => t.toLowerCase() == rawType.toLowerCase(),
          orElse: () => 'Monthly',
        );
        items.add(Subscription(
          service:     service,
          type:        typeMatch,
          price:       _dbl(row.length > 3 ? row[3] : null),
          renewalDate: _normalizeDate(_str(row.length > 4 ? row[4] : null)),
          notes:       _str(row.length > 5 ? row[5] : null),
        ));
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }

    return _executeBatchImport<Subscription>(
      tableName: 'subscriptions',
      items: items,
      skipped: skipped,
      errors: errors,
      replace: replace,
      inserter: (s) => _db.insertSubscription(s),
    );
  }

  // ── ACCESS POINTS ─────────────────────────────────────────────
  // Columns: #, Device No., Model, Port No., Location
  static Future<ImportResult> importAccessPoints(Excel excel, {bool replace = false}) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    final items = <AccessPoint>[];
    int skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final num   = _str(row.length > 1 ? row[1] : null);
        final model = _str(row.length > 2 ? row[2] : null);
        if (num.isEmpty || model.isEmpty) { skipped++; continue; }
        items.add(AccessPoint(
          deviceNumber: num,
          model:        model,
          portNumber:   _str(row.length > 3 ? row[3] : null),
          location:     _str(row.length > 4 ? row[4] : null),
        ));
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }

    return _executeBatchImport<AccessPoint>(
      tableName: 'access_points',
      items: items,
      skipped: skipped,
      errors: errors,
      replace: replace,
      inserter: (a) => _db.insertAccessPoint(a),
    );
  }

  // ── Date normalizer ──────────────────────────────────────────
  static String _normalizeDate(String raw) {
    if (raw.isEmpty) return _today();
    // Already yyyy-MM-dd
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return raw;
    // Try parsing "dd MMM yyyy" e.g. "15 May 2026"
    try {
      final months = {
        'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,
        'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12,
      };
      final parts = raw.trim().split(RegExp(r'[\s,]+'));
      if (parts.length >= 3) {
        final d = int.tryParse(parts[0]);
        final m = months[parts[1].toLowerCase().substring(0, 3)];
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) {
          return '${y.toString().padLeft(4,'0')}-${m.toString().padLeft(2,'0')}-${d.toString().padLeft(2,'0')}';
        }
      }
    } catch (_) {}
    // Excel serial date (days since 1900-01-01)
    final serial = double.tryParse(raw);
    if (serial != null && serial > 1000) {
      final base = DateTime(1899, 12, 30);
      final date = base.add(Duration(days: serial.toInt()));
      return '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
    }
    return _today();
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  // ── LOG ENTRIES ───────────────────────────────────────────────
  // Columns: Date, Employee, Problem, Solution
  static Future<ImportResult> importLogEntries(Excel excel, {bool replace = false}) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    final items = <LogEntry>[];
    int skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final date     = _normalizeDate(_str(row.isNotEmpty ? row[0] : null));
        final employee = _str(row.length > 1 ? row[1] : null);
        final problem  = _str(row.length > 2 ? row[2] : null);
        if (problem.isEmpty) { skipped++; continue; }
        final solution = _str(row.length > 3 ? row[3] : null);

        items.add(LogEntry(
          date:         date,
          employeeName: employee,
          problem:      problem,
          solution:     solution,
        ));
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }

    return _executeBatchImport<LogEntry>(
      tableName: 'log_entries',
      items: items,
      skipped: skipped,
      errors: errors,
      replace: replace,
      inserter: (e) => _db.insertLogEntry(e),
    );
  }

  // ── OTHER DEVICES ─────────────────────────────────────────────
  // Columns: #, Device Type, Device Name, Model, Notes
  static Future<ImportResult> importOtherDevices(Excel excel, {bool replace = false}) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    final items = <OtherDevice>[];
    int skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final type  = _str(row.length > 1 ? row[1] : null);
        final name  = _str(row.length > 2 ? row[2] : null);
        final model = _str(row.length > 3 ? row[3] : null);
        final notes = _str(row.length > 4 ? row[4] : null);

        if (name.isEmpty) { skipped++; continue; }

        items.add(OtherDevice(
          deviceType: type.isNotEmpty ? type : 'Other',
          deviceName: name,
          model: model,
          notes: notes,
        ));
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }

    return _executeBatchImport<OtherDevice>(
      tableName: 'other_devices',
      items: items,
      skipped: skipped,
      errors: errors,
      replace: replace,
      inserter: (d) => _db.insertOtherDevice(d),
    );
  }
}
