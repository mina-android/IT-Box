import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LabelService {
  /// Generates a 3-column label PDF and opens the share sheet.
  /// Uses only [pdf] + [share_plus] — no [printing] dependency needed.
  static Future<void> printLabels({
    required List<String> labels,
    required String title,
    required BuildContext context,
  }) async {
    final pdf = pw.Document();

    // Pad to multiple of 3
    final items = List<String>.from(labels);
    while (items.length % 3 != 0) {
      items.add('');
    }

    // Build rows of 3
    final rows = <List<String>>[];
    for (var i = 0; i < items.length; i += 3) {
      rows.add(items.sublist(i, i + 3));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => [
          pw.Center(
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(width: 2.5, color: PdfColors.black),
            columnWidths: const {
              0: pw.FlexColumnWidth(),
              1: pw.FlexColumnWidth(),
              2: pw.FlexColumnWidth(),
            },
            children: rows.map((row) {
              return pw.TableRow(
                children: row.map((cell) {
                  final isEmpty = cell.isEmpty;
                  return pw.Container(
                    height: 55,
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(6),
                    color: isEmpty ? PdfColors.grey100 : PdfColors.white,
                    child: pw.Text(
                      isEmpty ? '—' : cell,
                      style: pw.TextStyle(
                        fontSize: isEmpty ? 10 : 12,
                        fontWeight: pw.FontWeight.bold,
                        color: isEmpty ? PdfColors.grey400 : PdfColors.black,
                        letterSpacing: 0.3,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ],
      ),
    );

    // Save to temp file
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final file = File('${dir.path}/inventorya_$safeTitle.pdf');
    await file.writeAsBytes(bytes);

    // Share via system share sheet
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: title,
    );
  }
}
