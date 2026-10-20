// lib/services/custody_pdf_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'company_service.dart';
import '../models/laptop.dart';

class CustodyPdfService {
  static pw.MemoryImage? _getCompanyLogo() {
    if (CompanyService().hasLogo) {
      try {
        final logoFile = File(CompanyService().logoPath);
        if (logoFile.existsSync()) {
          return pw.MemoryImage(logoFile.readAsBytesSync());
        }
      } catch (_) {}
    }
    return null;
  }

  static pw.Widget _buildHeader({
    required String companyName,
    required String handoverDate,
    required pw.MemoryImage? logoImage,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Row(
          children: [
            if (logoImage != null)
              pw.Container(
                width: 44,
                height: 44,
                margin: const pw.EdgeInsets.only(right: 12),
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  companyName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  'IT Operations & Asset Management',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'EQUIPMENT CUSTODY RECEIPT',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.Text(
              'Date: $handoverDate',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }

  static Future<File> generateCustodyPdf({
    required String employeeName,
    required String employeePhone,
    required String employeeEmail,
    required String deviceType,
    required String deviceName,
    required String deviceNumber,
    required String condition,
    required String serialNumber,
    required String handoverDate,
    required String dueDate,
    required Uint8List? signatureBytes,
    String? adminNotes,
    Map<String, String>? extraSpecs,
  }) async {
    final pdf = pw.Document();
    final companyName = CompanyService().name.isNotEmpty ? CompanyService().name : 'IT BOX';
    final logoImage = _getCompanyLogo();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                companyName: companyName,
                handoverDate: handoverDate,
                logoImage: logoImage,
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.blue900),
              pw.SizedBox(height: 12),

              // Employee Section
              pw.Text(
                '1. RECIPIENT INFORMATION',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Full Name: $employeeName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Phone Number: ${employeePhone.isNotEmpty ? employeePhone : 'N/A'}'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Email: ${employeeEmail.isNotEmpty ? employeeEmail : 'N/A'}'),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Equipment Section
              pw.Text(
                '2. ISSUED ASSET SPECIFICATIONS',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  _tableRow('Asset Tag / Device #', deviceNumber),
                  _tableRow('Hardware Name / Model', deviceName),
                  _tableRow('Category / Type', deviceType.toUpperCase()),
                  _tableRow('Physical Condition', condition),
                  _tableRow('Serial / Identifier', serialNumber.isNotEmpty ? serialNumber : 'N/A'),
                  _tableRow('Expected Due Date', dueDate.isNotEmpty ? dueDate : 'Permanent / Indefinite'),
                  if (extraSpecs != null) ...[
                    for (final entry in extraSpecs.entries)
                      if (entry.value.isNotEmpty)
                        _tableRow(entry.key, entry.value),
                  ],
                ],
              ),
              pw.SizedBox(height: 14),

              // Terms & Conditions
              pw.Text(
                '3. CUSTODY & USAGE AGREEMENT',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'The recipient acknowledges receipt of the equipment listed above in verified operational condition. '
                  'The employee agrees to exercise reasonable care, maintain security credentials, adhere to corporate usage policies, '
                  'and immediately return the asset upon demand or employment conclusion.',
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                ),
              ),
              pw.SizedBox(height: 20),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('IT Administrator Sign-off:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 35),
                      pw.Container(width: 180, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('IT Operations Department', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Recipient Signature:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      if (signatureBytes != null && signatureBytes.isNotEmpty)
                        pw.Container(
                          width: 150,
                          height: 50,
                          child: pw.Image(pw.MemoryImage(signatureBytes)),
                        )
                      else
                        pw.SizedBox(height: 50),
                      pw.Container(width: 180, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text(employeeName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final safeName = employeeName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final file = File('${dir.path}/Custody_Receipt_${safeName}_$deviceNumber.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Bulk export multiple laptops into a single consolidated PDF document.
  static Future<File> generateBulkLaptopCustodyPdf(List<Laptop> laptops) async {
    final pdf = pw.Document();
    final companyName = CompanyService().name.isNotEmpty ? CompanyService().name : 'IT BOX';
    final logoImage = _getCompanyLogo();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (final laptop in laptops) {
      final user = laptop.user.isNotEmpty ? laptop.user : 'Unassigned / In Stock';
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  companyName: companyName,
                  handoverDate: today,
                  logoImage: logoImage,
                ),
                pw.Divider(thickness: 1.5, color: PdfColors.blue900),
                pw.SizedBox(height: 12),

                // Employee / User Section
                pw.Text(
                  '1. RECIPIENT INFORMATION',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Assigned User: $user', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text('Assignment Status: ${laptop.user.isNotEmpty ? 'Deployed to Personnel' : 'Available in IT Inventory'}'),
                        ],
                      ),
                      pw.Text('Asset Type: Laptop', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Equipment Section
                pw.Text(
                  '2. LAPTOP HARDWARE SPECIFICATIONS',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                ),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _tableRow('Laptop Number / Tag', laptop.laptopNumber),
                    _tableRow('Make & Model', laptop.model),
                    _tableRow('Condition', laptop.condition),
                    _tableRow('Processor (CPU)', laptop.cpu.isNotEmpty ? laptop.cpu : 'Standard'),
                    _tableRow('Graphics (GPU)', laptop.gpu.isNotEmpty ? laptop.gpu : 'Integrated'),
                    _tableRow('Memory (RAM)', laptop.ram.isNotEmpty ? laptop.ram : 'Standard'),
                    _tableRow('Storage Drive', laptop.storage.isNotEmpty ? laptop.storage : 'Standard'),
                  ],
                ),
                pw.SizedBox(height: 14),

                // Terms & Conditions
                pw.Text(
                  '3. CUSTODY & COMPLIANCE AGREEMENT',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(
                    'The recipient acknowledges receipt and custody of this computing workstation. '
                    'The equipment remains sole property of the organization and must be surrendered upon IT audit or request.',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                  ),
                ),
                pw.SizedBox(height: 24),

                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('IT Administrator Sign-off:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 35),
                        pw.Container(width: 180, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 4),
                        pw.Text('IT Operations Department', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Recipient Signature:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 35),
                        pw.Container(width: 180, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 4),
                        pw.Text(user, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Bulk_Laptop_Custody_Slips_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  static pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: PdfColors.grey100,
          child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  static Future<void> shareCustodyFile(File file, String employeeName, String device) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Equipment Custody Slip - $device - $employeeName',
      ),
    );
  }

  static Future<void> emailCustodyDirect({
    required File file,
    required String recipientEmail,
    required String employeeName,
    required String device,
  }) async {
    const channel = MethodChannel('com.ma.itbox/email_launcher');
    final subject = 'Equipment Custody Receipt - $device';
    final body =
        'Hello $employeeName,\n\nPlease find attached the official custody receipt for equipment ($device) issued to you.\n\nBest regards,\nIT Department';

    try {
      await channel.invokeMethod('sendEmailWithAttachment', {
        'filePath': file.path,
        'recipient': recipientEmail,
        'subject': subject,
        'body': body,
      });
    } catch (_) {
      // Fallback to share sheet if channel fails
      await shareCustodyFile(file, employeeName, device);
    }
  }
}
