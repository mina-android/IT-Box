import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LabelService {
  /// Generates a 4-column label PDF and opens the share sheet.
  /// Uses only [pdf] + [share_plus] — no [printing] dependency needed.
  /// Labels may contain '\n' for two-line labels (e.g. device number + phone).
  static Future<void> printLabels({
    required List<String> labels,
    required String title,
    required BuildContext context,
  }) async {
    final pdf = pw.Document();

    // Pad to multiple of 4
    final items = List<String>.from(labels);
    while (items.length % 4 != 0) {
      items.add('');
    }

    // Build rows of 4
    final rows = <List<String>>[];
    for (var i = 0; i < items.length; i += 4) {
      rows.add(items.sublist(i, i + 4));
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
              3: pw.FlexColumnWidth(),
            },
            children: rows.map((row) {
              return pw.TableRow(
                children: row.map((cell) {
                  final isEmpty = cell.isEmpty;
                  final hasSecondLine = cell.contains('\n');
                  return pw.Container(
                    height: 55,
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(6),
                    color: isEmpty ? PdfColors.grey100 : PdfColors.white,
                    child: isEmpty
                        ? pw.Text(
                            '—',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey400,
                              letterSpacing: 0.3,
                            ),
                            textAlign: pw.TextAlign.center,
                          )
                        : hasSecondLine
                            ? pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    cell.split('\n')[0],
                                    style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.black,
                                      letterSpacing: 0.3,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    cell.split('\n')[1],
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.normal,
                                      color: PdfColors.grey700,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ],
                              )
                            : pw.Text(
                                cell,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
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
    final file = File('${dir.path}/itbox_$safeTitle.pdf');
    await file.writeAsBytes(bytes);

    // Share via system share sheet
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: title,
      ),
    );
  }

  /// Generates a printable grid of QR code asset stickers with asset ID, model, and metadata.
  static Future<void> printDeviceQrCodes({
    required List<Map<String, String>> items,
    required String title,
    required BuildContext context,
  }) async {
    final pdf = pw.Document();

    const itemsPerPage = 12;
    for (var pageStart = 0; pageStart < items.length; pageStart += itemsPerPage) {
      final pageEnd = (pageStart + itemsPerPage < items.length) ? pageStart + itemsPerPage : items.length;
      final pageItems = items.sublist(pageStart, pageEnd);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.Text(
                      'Page ${(pageStart ~/ itemsPerPage) + 1} of ${((items.length - 1) ~/ itemsPerPage) + 1}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 3,
                    childAspectRatio: 0.88,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: pageItems.map((item) {
                      final code = item['code'] ?? '';

                      return pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400, width: 1.2),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: code,
                              width: 80,
                              height: 80,
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              code,
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final file = File('${dir.path}/itbox_qr_$safeTitle.pdf');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: title,
      ),
    );
  }
}
