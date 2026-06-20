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

class ExcelImportService {
  static final _db = DatabaseHelper();

  // ── Pick file ─────────────────────────────────────────────────
  static Future<Excel?> pickExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final bytes = result.files.first.bytes;
    if (bytes == null) return null;
    return Excel.decodeBytes(bytes);
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

  // ── LAPTOPS ──────────────────────────────────────────────────
  // Expected columns: #, Laptop No., Model, CPU, GPU, RAM, Storage, Condition, User
  static Future<ImportResult> importLaptops(Excel excel) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    int inserted = 0, skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final num  = _str(row.length > 1 ? row[1] : null); // col 1
        final model= _str(row.length > 2 ? row[2] : null);
        if (num.isEmpty || model.isEmpty) { skipped++; continue; }
        final l = Laptop(
          laptopNumber: num,
          model:        model,
          cpu:          _str(row.length > 3 ? row[3] : null),
          gpu:          _str(row.length > 4 ? row[4] : null),
          ram:          _str(row.length > 5 ? row[5] : null),
          storage:      _str(row.length > 6 ? row[6] : null),
          condition:    _str(row.length > 7 ? row[7] : null).isEmpty ? 'Good' : _str(row[7]),
          user:         _str(row.length > 8 ? row[8] : null),
        );
        await _db.insertLaptop(l);
        inserted++;
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }
    return ImportResult(inserted: inserted, skipped: skipped, errors: errors);
  }

  // ── NETWORK DEVICES ──────────────────────────────────────────
  // Columns: #, Device No., Model, Phone No., Location, Provider, WiFi Name, Status
  static Future<ImportResult> importNetworkDevices(Excel excel) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    int inserted = 0, skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final num  = _str(row.length > 1 ? row[1] : null);
        final model= _str(row.length > 2 ? row[2] : null);
        if (num.isEmpty || model.isEmpty) { skipped++; continue; }
        final d = NetworkDevice(
          deviceNumber:   num,
          model:          model,
          phoneNumber:    _str(row.length > 3 ? row[3] : null),
          deviceLocation: _str(row.length > 4 ? row[4] : null),
          serviceProvider:_str(row.length > 5 ? row[5] : null),
          wifiName:       _str(row.length > 6 ? row[6] : null),
          status:         'Available',
        );
        await _db.insertNetworkDevice(d);
        inserted++;
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }
    return ImportResult(inserted: inserted, skipped: skipped, errors: errors);
  }

  // ── MIFIS ────────────────────────────────────────────────────
  // Columns: #, Device No., Model, Phone No., WiFi Name, Quota, Provider, Status
  static Future<ImportResult> importMiFis(Excel excel) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    int inserted = 0, skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final num  = _str(row.length > 1 ? row[1] : null);
        final model= _str(row.length > 2 ? row[2] : null);
        if (num.isEmpty || model.isEmpty) { skipped++; continue; }
        final m = MiFi(
          deviceNumber:   num,
          model:          model,
          phoneNumber:    _str(row.length > 3 ? row[3] : null),
          wifiName:       _str(row.length > 4 ? row[4] : null),
          quota:          _str(row.length > 5 ? row[5] : null),
          serviceProvider:_str(row.length > 6 ? row[6] : null),
          status:         'Available',
        );
        await _db.insertMiFi(m);
        inserted++;
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }
    return ImportResult(inserted: inserted, skipped: skipped, errors: errors);
  }

  // ── PRINTERS ─────────────────────────────────────────────────
  // Columns: #, Printer No., Model, Condition, Location
  static Future<ImportResult> importPrinters(Excel excel) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    int inserted = 0, skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final num  = _str(row.length > 1 ? row[1] : null);
        final model= _str(row.length > 2 ? row[2] : null);
        if (num.isEmpty || model.isEmpty) { skipped++; continue; }
        final p = Printer(
          printerNumber: num,
          model:         model,
          condition:     _str(row.length > 3 ? row[3] : null).isEmpty ? 'Good' : _str(row[3]),
          location:      _str(row.length > 4 ? row[4] : null),
        );
        await _db.insertPrinter(p);
        inserted++;
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }
    return ImportResult(inserted: inserted, skipped: skipped, errors: errors);
  }

  // ── ELECTRONICS ──────────────────────────────────────────────
  // Columns: #, Device No., Device Name, Details, Status
  static Future<ImportResult> importElectronics(Excel excel) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    int inserted = 0, skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final num  = _str(row.length > 1 ? row[1] : null);
        final name = _str(row.length > 2 ? row[2] : null);
        if (num.isEmpty || name.isEmpty) { skipped++; continue; }
        final e = Electronic(
          deviceNumber: num,
          deviceName:   name,
          details:      _str(row.length > 3 ? row[3] : null),
          status:       'Available',
        );
        await _db.insertElectronic(e);
        inserted++;
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }
    return ImportResult(inserted: inserted, skipped: skipped, errors: errors);
  }

  // ── EMPLOYEES ────────────────────────────────────────────────
  // Columns: #, Name, Phone Number
  static Future<ImportResult> importEmployees(Excel excel) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    int inserted = 0, skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final name = _str(row.length > 1 ? row[1] : null);
        if (name.isEmpty) { skipped++; continue; }
        final e = Employee(
          name:        name,
          phoneNumber: _str(row.length > 2 ? row[2] : null),
        );
        await _db.insertEmployee(e);
        inserted++;
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }
    return ImportResult(inserted: inserted, skipped: skipped, errors: errors);
  }

  // ── BILLS ─────────────────────────────────────────────────────
  // Columns: #, Person, Number, Category, Price (EGP), Notes
  static Future<ImportResult> importBills(Excel excel) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    int inserted = 0, skipped = 0;
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
        final b = Bill(
          person:   _str(row.length > 1 ? row[1] : null),
          number:   number,
          category: catMatch,
          price:    _dbl(row.length > 4 ? row[4] : null),
          notes:    _str(row.length > 5 ? row[5] : null),
        );
        await _db.insertBill(b);
        inserted++;
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }
    return ImportResult(inserted: inserted, skipped: skipped, errors: errors);
  }

  // ── EXPENSES ─────────────────────────────────────────────────
  // Columns: Date, Item, Price (EGP), Details
  static Future<ImportResult> importExpenses(Excel excel) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    int inserted = 0, skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        // Skip the TOTAL summary row that ExcelService adds
        final col0 = _str(row.isNotEmpty ? row[0] : null);
        if (col0.toUpperCase() == 'TOTAL') { skipped++; continue; }

        final date = _str(row.length > 0 ? row[0] : null);
        final item = _str(row.length > 1 ? row[1] : null);
        if (item.isEmpty) { skipped++; continue; }

        // Normalise date: accept "dd MMM yyyy", "yyyy-MM-dd", or Excel serial
        String normDate = _normalizeDate(date);

        final e = Expense(
          date:    normDate,
          item:    item,
          price:   _dbl(row.length > 2 ? row[2] : null),
          details: _str(row.length > 3 ? row[3] : null),
        );
        await _db.insertExpense(e);
        inserted++;
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }
    return ImportResult(inserted: inserted, skipped: skipped, errors: errors);
  }

  // ── EMAIL ACCOUNTS ───────────────────────────────────────────
  // Columns: #, Employee, Email, Password(hidden)
  static Future<ImportResult> importEmailAccounts(Excel excel) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    int inserted = 0, skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final email = _str(row.length > 2 ? row[2] : null);
        if (email.isEmpty || !email.contains('@')) { skipped++; continue; }
        final pass = _str(row.length > 3 ? row[3] : null);
        if (pass == '(hidden)' || pass.isEmpty) { skipped++; continue; }
        final e = EmailAccount(
          employeeName: _str(row.length > 1 ? row[1] : null),
          email:        email,
          password:     pass,
        );
        await _db.insertEmailAccount(e);
        inserted++;
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }
    return ImportResult(inserted: inserted, skipped: skipped, errors: errors);
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
  static Future<ImportResult> importLogEntries(Excel excel) async {
    final sheet = excel.sheets.values.first;
    final rows = _rows(sheet);
    int inserted = 0, skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final date     = _normalizeDate(_str(row.isNotEmpty ? row[0] : null));
        final employee = _str(row.length > 1 ? row[1] : null);
        final problem  = _str(row.length > 2 ? row[2] : null);
        if (problem.isEmpty) { skipped++; continue; }
        final solution = _str(row.length > 3 ? row[3] : null);

        final e = LogEntry(
          date:         date,
          employeeName: employee,
          problem:      problem,
          solution:     solution,
        );
        await _db.insertLogEntry(e);
        inserted++;
      } catch (e) { errors.add('Row ${i + 2}: $e'); skipped++; }
    }
    return ImportResult(inserted: inserted, skipped: skipped, errors: errors);
  }
}
