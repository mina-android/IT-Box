import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExcelService {
  static final _dateFmt  = DateFormat('dd MMM yyyy');

  // ── header style helper ──────────────────────────────────────────
  static CellStyle get _header => CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    horizontalAlign: HorizontalAlign.Center,
  );

  static CellStyle get _altRow => CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#EAF4FF'),
  );

  // ── Generic table writer ─────────────────────────────────────────
  static void _writeSheet(Sheet sheet, List<String> headers, List<List<dynamic>> rows) {
    // Headers
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = _header;
    }
    // Rows
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final val = row[c];
        if (val is double || val is int) {
          cell.value = DoubleCellValue((val as num).toDouble());
        } else {
          cell.value = TextCellValue(val?.toString() ?? '');
        }
        if ((r % 2) == 1) cell.cellStyle = _altRow;
      }
    }
  }

  // ── Export a single database table ──────────────────────────────
  static Future<void> exportTable({
    required String sheetName,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String fileLabel,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    _writeSheet(sheet, headers, rows);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel encoding failed');

    final dir = await getTemporaryDirectory();
    final ts  = DateTime.now().toString().replaceAll(RegExp(r'[: .]'), '-').substring(0, 19);
    final file = File('${dir.path}/${fileLabel}_$ts.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], subject: fileLabel);
  }

  // ── Export expenses date range ───────────────────────────────────
  static Future<void> exportExpenses({
    required List<Map<String, dynamic>> expenses,
    required String label,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Expenses'];
    excel.setDefaultSheet('Expenses');

    final headers = ['Date', 'Item', 'Price (EGP)', 'Details'];
    final rows = expenses.map((e) {
      String dateStr = e['date'] as String? ?? '';
      try { dateStr = _dateFmt.format(DateTime.parse(dateStr)); } catch (_) {}
      return <dynamic>[
        dateStr,
        e['item'] as String? ?? '',
        (e['price'] as num?)?.toDouble() ?? 0.0,
        e['details'] as String? ?? '',
      ];
    }).toList();

    _writeSheet(sheet, headers, rows);

    // Summary row
    final total = expenses.fold<double>(0, (s, e) => s + ((e['price'] as num?)?.toDouble() ?? 0));
    final sumRow = sheet.maxRows;
    final tc = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sumRow));
    tc.value = TextCellValue('TOTAL');
    tc.cellStyle = CellStyle(bold: true);
    final vc = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: sumRow));
    vc.value = DoubleCellValue(total);
    vc.cellStyle = CellStyle(bold: true);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel encoding failed');

    final dir  = await getTemporaryDirectory();
    final ts   = DateTime.now().toString().replaceAll(RegExp(r'[: .]'), '-').substring(0, 19);
    final file = File('${dir.path}/Expenses_${label}_$ts.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], subject: 'Expenses – $label');
  }
}
