// lib/services/wifi_pdf_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'company_service.dart';

class WifiNetworkInfo {
  final String ssid;
  final String password;
  final String security;
  final String locationOrTag;

  WifiNetworkInfo({
    required this.ssid,
    required this.password,
    this.security = 'WPA',
    this.locationOrTag = '',
  });

  static String _escapeWifiValue(String val) {
    return val
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll(':', r'\:');
  }

  String get qrString {
    if (password.isEmpty) {
      return 'WIFI:S:${_escapeWifiValue(ssid)};T:nopass;;';
    }
    return 'WIFI:S:${_escapeWifiValue(ssid)};T:$security;P:${_escapeWifiValue(password)};;';
  }
}

class WifiPdfService {
  /// Generates an A4 Portrait PDF with exactly 3 cards per page for selected Wi-Fi networks.
  static Future<void> generateAndShareWifiCards({
    required List<WifiNetworkInfo> networks,
    required BuildContext context,
  }) async {
    final pdf = pw.Document();
    final companyName = CompanyService().name;

    // Group into pages of 3
    for (int i = 0; i < networks.length; i += 3) {
      final card1 = networks[i];
      final card2 = (i + 1 < networks.length) ? networks[i + 1] : null;
      final card3 = (i + 2 < networks.length) ? networks[i + 2] : null;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          build: (ctx) {
            return pw.Column(
              children: [
                pw.Expanded(
                  child: _buildStandardWifiCard(card1, companyName),
                ),
                _buildCutGuide(),
                pw.Expanded(
                  child: card2 != null
                      ? _buildStandardWifiCard(card2, companyName)
                      : pw.Container(),
                ),
                _buildCutGuide(),
                pw.Expanded(
                  child: card3 != null
                      ? _buildStandardWifiCard(card3, companyName)
                      : pw.Container(),
                ),
              ],
            );
          },
        ),
      );
    }

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Wifi_Standard_Cards_3x.pdf');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Wi-Fi Standard Cards (3 Per Page)',
      ),
    );
  }

  /// Generates an A4 Landscape PDF with 20 Portable Cards (7cm x 4cm) per page (4 columns x 5 rows).
  static Future<void> generateAndSharePortableWifiCards({
    required List<WifiNetworkInfo> networks,
    required BuildContext context,
  }) async {
    final pdf = pw.Document();
    final companyName = CompanyService().name;

    const cardsPerPage = 20; // 4 columns x 5 rows

    for (int i = 0; i < networks.length; i += cardsPerPage) {
      final end = (i + cardsPerPage < networks.length) ? i + cardsPerPage : networks.length;
      final pageItems = networks.sublist(i, end);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(
            horizontal: 8.5 * PdfPageFormat.mm,
            vertical: 5.0 * PdfPageFormat.mm,
          ),
          build: (ctx) {
            // Build 5 rows of 4 cards
            final rows = <pw.Widget>[];
            for (int r = 0; r < 5; r++) {
              final rowChildren = <pw.Widget>[];
              for (int c = 0; c < 4; c++) {
                final itemIndex = (r * 4) + c;
                if (itemIndex < pageItems.length) {
                  rowChildren.add(_buildPortableWifiCard(pageItems[itemIndex], companyName));
                } else {
                  rowChildren.add(
                    pw.Container(
                      width: 70 * PdfPageFormat.mm,
                      height: 40 * PdfPageFormat.mm,
                    ),
                  );
                }
              }
              rows.add(
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: rowChildren,
                ),
              );
            }
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: rows,
            );
          },
        ),
      );
    }

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Wifi_Portable_Cards_7x4cm.pdf');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Wi-Fi Portable Cards (7cm x 4cm)',
      ),
    );
  }

  static pw.Widget _buildCutGuide() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        children: [
          pw.Text('✂', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 6),
              height: 1,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColors.grey400,
                    width: 0.8,
                    style: pw.BorderStyle.dashed,
                  ),
                ),
              ),
            ),
          ),
          pw.Text('✂', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _buildStandardWifiCard(WifiNetworkInfo net, String company) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        color: PdfColors.white,
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: pw.Row(
        children: [
          // QR Code Column
          pw.Container(
            width: 110,
            height: 110,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            padding: const pw.EdgeInsets.all(5),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: net.qrString,
            ),
          ),
          pw.SizedBox(width: 20),
          // Info Column
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  company.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Wi-Fi Access Card',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                if (net.locationOrTag.isNotEmpty) ...[
                  _fieldRow('Device:', net.locationOrTag, isBold: true),
                  pw.SizedBox(height: 3),
                ],
                _fieldRow('Network (SSID):', net.ssid, isBold: true),
                pw.SizedBox(height: 3),
                _fieldRow('Password:', net.password.isNotEmpty ? net.password : '(None / Open)', isMono: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPortableWifiCard(WifiNetworkInfo net, String company) {
    return pw.Container(
      width: 70 * PdfPageFormat.mm,
      height: 40 * PdfPageFormat.mm,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8, style: pw.BorderStyle.dashed),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: PdfColors.white,
      ),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Row(
        children: [
          // 32mm x 32mm QR Code
          pw.Container(
            width: 30 * PdfPageFormat.mm,
            height: 30 * PdfPageFormat.mm,
            padding: const pw.EdgeInsets.all(2),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: net.qrString,
            ),
          ),
          pw.SizedBox(width: 5),
          // Info Column
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  company.toUpperCase(),
                  maxLines: 1,
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 2),
                if (net.locationOrTag.isNotEmpty) ...[
                  pw.Text(
                    net.locationOrTag,
                    maxLines: 1,
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                  pw.SizedBox(height: 1),
                ],
                pw.Text(
                  'SSID: ${net.ssid}',
                  maxLines: 1,
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  'Pass: ${net.password.isNotEmpty ? net.password : "None"}',
                  maxLines: 1,
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _fieldRow(String label, String value, {bool isBold = false, bool isMono = false}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 85,
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              font: isMono ? pw.Font.courier() : null,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }
}
