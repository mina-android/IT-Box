// lib/services/audit_export_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import 'pdf_base_helper.dart';

class AuditExportService {
  final DatabaseHelper _db = DatabaseHelper();

  /// Export audit activities as a formatted CSV file and return the saved File.
  Future<File> exportAuditCsv() async {
    final activities = await _db.getAuditActivities(limit: 1000);
    final sb = StringBuffer();

    // CSV Header
    sb.writeln('ID,Timestamp,Action,Entity,Entity_ID,Description');

    for (final a in activities) {
      final id = a['id']?.toString() ?? '';
      final timestamp = a['timestamp']?.toString() ?? '';
      final action = _escapeCsv((a['action_type'] ?? a['action'])?.toString() ?? '');
      final entity = _escapeCsv((a['entity_type'] ?? a['entity'])?.toString() ?? '');
      final entityId = a['entity_id']?.toString() ?? '';
      final desc = _escapeCsv(a['description']?.toString() ?? '');

      sb.writeln('$id,$timestamp,$action,$entity,$entityId,$desc');
    }

    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final bytes = Uint8List.fromList(utf8.encode(sb.toString()));
    final file = await PdfBaseHelper.writeTempFile(bytes, 'itbox_audit_trail_$dateStr.csv');
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], subject: 'IT Box Audit Trail CSV'),
    );
    return file;
  }

  /// Export audit activities as a professional PDF report and return the saved File.
  Future<File> exportAuditPdf() async {
    final activities = await _db.getAuditActivities(limit: 500);
    final pdf = pw.Document();
    final logoImage = PdfBaseHelper.getCompanyLogo();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          children: [
            PdfBaseHelper.buildBrandedHeader(
              title: 'SYSTEM AUDIT TRAIL',
              subtitle: 'Operational Audit Log',
              rightTitle: 'AUDIT REPORT',
              rightSubtitle: 'Generated: $dateStr',
              logoImage: logoImage,
              accentColor: PdfColors.indigo900,
            ),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Operational Audit Log', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Total Events: ${activities.length}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Time', 'Action', 'Entity', 'Description'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            data: activities.map((a) {
              final rawTime = a['timestamp']?.toString() ?? '';
              var timeStr = rawTime;
              try {
                final dt = DateTime.parse(rawTime);
                timeStr = DateFormat('MM-dd HH:mm').format(dt);
              } catch (_) {}

              final action = (a['action_type'] ?? a['action'])?.toString() ?? '';
              final entity = (a['entity_type'] ?? a['entity'])?.toString() ?? '';
              return [
                timeStr,
                action,
                '$entity${a['entity_id'] != null ? ' (#${a['entity_id']})' : ''}',
                a['description']?.toString() ?? '',
              ];
            }).toList(),
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        ),
      ),
    );

    final fileDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final bytes = Uint8List.fromList(await pdf.save());
    final file = await PdfBaseHelper.writeTempFile(bytes, 'itbox_audit_report_$fileDate.pdf');
    await PdfBaseHelper.sharePdfFile(file, subject: 'IT Box Audit Trail Report');
    return file;
  }

  static String _escapeCsv(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }
}
