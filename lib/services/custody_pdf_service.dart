// lib/services/custody_pdf_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../database/database_helper.dart';
import '../models/custody_document.dart';
import '../models/laptop.dart';
import 'document_storage_service.dart';
import 'pdf_base_helper.dart';

class CustodyPdfService {
  static void _addCustodyDocumentPages(
    pw.Document pdf, {
    required String documentNumber,
    required String title,
    required String employeeName,
    required String employeePhone,
    required String employeeEmail,
    required String handoverDate,
    required String dueDate,
    required List<CustodyItem> items,
    required String agreementText,
    required String adminNotes,
    required Uint8List? signatureBytes,
    required pw.MemoryImage? logoImage,
  }) {
    final safeItems = items.isEmpty
        ? const [
            CustodyItem(
              deviceType: 'Equipment',
              deviceName: 'Unspecified Item',
              condition: 'Good / Verified',
            ),
          ]
        : items;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          children: [
            PdfBaseHelper.buildBrandedHeader(
              title: title.toUpperCase(),
              subtitle: 'IT Operations & Asset Management',
              rightTitle: title.toUpperCase(),
              rightSubtitle: documentNumber.isNotEmpty
                  ? 'Doc: $documentNumber • Date: $handoverDate'
                  : 'Date: $handoverDate',
              logoImage: logoImage,
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.blue900),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          // 1. Recipient Info
          pw.Text(
            '1. RECIPIENT INFORMATION',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
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
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Employee: $employeeName',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                    if (employeePhone.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text('Phone: $employeePhone', style: const pw.TextStyle(fontSize: 9.5)),
                    ],
                    if (employeeEmail.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text('Email: $employeeEmail', style: const pw.TextStyle(fontSize: 9.5)),
                    ],
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Handover: $handoverDate', style: const pw.TextStyle(fontSize: 9.5)),
                    if (dueDate.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Return Due: $dueDate',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // 2. Equipment Details
          pw.Text(
            '2. EQUIPMENT / HARDWARE DETAILS (${safeItems.length})',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 6),
          for (int i = 0; i < safeItems.length; i++) ...[
            if (safeItems.length > 1)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4, top: 4),
                child: pw.Text(
                  'Item ${i + 1}: ${safeItems[i].deviceName} (${safeItems[i].deviceType})',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _tableRow('Device Category', safeItems[i].deviceType),
                _tableRow('Model / Name', safeItems[i].deviceName),
                _tableRow(
                  'Asset Tag / Number',
                  safeItems[i].deviceNumber.isNotEmpty ? safeItems[i].deviceNumber : 'N/A',
                ),
                if (safeItems[i].serialNumber.isNotEmpty &&
                    safeItems[i].serialNumber != safeItems[i].deviceNumber)
                  _tableRow('Serial Number', safeItems[i].serialNumber),
                _tableRow('Condition at Handover', safeItems[i].condition),
                for (final entry in safeItems[i].extraSpecs.entries)
                  if (entry.value.isNotEmpty) _tableRow(entry.key, entry.value),
              ],
            ),
            pw.SizedBox(height: 8),
          ],

          if (adminNotes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'ADMINISTRATOR NOTES',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(adminNotes.trim(), style: const pw.TextStyle(fontSize: 9)),
            ),
            pw.SizedBox(height: 10),
          ],

          // 3. Custody & Compliance Agreement
          pw.SizedBox(height: 6),
          pw.Text(
            '3. CUSTODY & COMPLIANCE AGREEMENT',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(
              agreementText.trim().isNotEmpty
                  ? agreementText.trim()
                  : CustodyDocument.defaultAgreementText,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
            ),
          ),
          pw.SizedBox(height: 22),

          // 4. Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'IT Administrator Sign-off:',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 36),
                  pw.Container(width: 180, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'IT Operations Department',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Recipient Signature:',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 6),
                  if (signatureBytes != null)
                    pw.Container(
                      width: 180,
                      height: 60,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Image(pw.MemoryImage(signatureBytes), fit: pw.BoxFit.contain),
                    )
                  else
                    pw.SizedBox(height: 36),
                  pw.SizedBox(height: 4),
                  pw.Container(width: 180, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    employeeName,
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Generates a custody PDF for an individual Borrow or Laptop slip and writes to temp.
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
    final logoImage = PdfBaseHelper.getCompanyLogo();
    final docNum = CustodyDocument.generateDocumentNumber();

    _addCustodyDocumentPages(
      pdf,
      documentNumber: docNum,
      title: 'Equipment Custody Receipt',
      employeeName: employeeName,
      employeePhone: employeePhone,
      employeeEmail: employeeEmail,
      handoverDate: handoverDate,
      dueDate: dueDate,
      items: [
        CustodyItem(
          deviceType: deviceType,
          deviceName: deviceName,
          deviceNumber: deviceNumber,
          serialNumber: serialNumber,
          condition: condition,
          extraSpecs: extraSpecs ?? const {},
        ),
      ],
      agreementText: CustodyDocument.defaultAgreementText,
      adminNotes: adminNotes ?? '',
      signatureBytes: signatureBytes,
      logoImage: logoImage,
    );

    final bytes = await pdf.save();
    final safeName = PdfBaseHelper.sanitizeFilename(employeeName);
    final safeNum = PdfBaseHelper.sanitizeFilename(deviceNumber);
    return PdfBaseHelper.writeTempFile(
      Uint8List.fromList(bytes),
      'Custody_Receipt_${safeName}_$safeNum.pdf',
    );
  }

  /// Saves a permanent org-scoped custody PDF and records the slip in `custody_documents`.
  static Future<CustodyDocument> archiveGeneratedSlip({
    required File tempPdfFile,
    required String sourceType, // 'borrow' or 'laptop'
    int? sourceId,
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
    Uint8List? signatureBytes,
    String adminNotes = '',
    Map<String, String>? extraSpecs,
  }) async {
    final docNum = CustodyDocument.generateDocumentNumber();
    final bytes = await tempPdfFile.readAsBytes();
    final permanentPath = await DocumentStorageService.saveCustodyPdfBytes(
      bytes,
      '${docNum}_${employeeName}_$deviceNumber.pdf',
    );

    final item = CustodyItem(
      deviceType: deviceType,
      deviceName: deviceName,
      deviceNumber: deviceNumber,
      serialNumber: serialNumber,
      condition: condition,
      extraSpecs: extraSpecs ?? const {},
    );

    final doc = CustodyDocument(
      documentNumber: docNum,
      title: 'Equipment Custody Receipt',
      sourceType: sourceType,
      sourceId: sourceId,
      employeeName: employeeName,
      employeePhone: employeePhone,
      employeeEmail: employeeEmail,
      handoverDate: handoverDate,
      dueDate: dueDate,
      itemsJson: CustodyDocument.encodeItems([item]),
      agreementText: CustodyDocument.defaultAgreementText,
      adminNotes: adminNotes,
      signatureBase64: signatureBytes != null ? base64Encode(signatureBytes) : '',
      pdfPath: permanentPath,
      createdAt: DateTime.now().toIso8601String(),
    );

    final id = await DatabaseHelper().insertCustodyDocument(doc);
    return doc.copyWith(id: id);
  }

  /// Generates and saves a permanent org-scoped PDF for a [CustodyDocument].
  static Future<File> generateAndSaveCustodyDocumentPdf(CustodyDocument doc) async {
    final pdf = pw.Document();
    final logoImage = PdfBaseHelper.getCompanyLogo();

    _addCustodyDocumentPages(
      pdf,
      documentNumber: doc.documentNumber,
      title: doc.title,
      employeeName: doc.employeeName,
      employeePhone: doc.employeePhone,
      employeeEmail: doc.employeeEmail,
      handoverDate: doc.handoverDate,
      dueDate: doc.dueDate,
      items: doc.items,
      agreementText: doc.agreementText,
      adminNotes: doc.adminNotes,
      signatureBytes: doc.signatureBytes,
      logoImage: logoImage,
    );

    final bytes = Uint8List.fromList(await pdf.save());
    final savedPath = await DocumentStorageService.saveCustodyPdfBytes(
      bytes,
      '${doc.documentNumber}_${doc.employeeName}.pdf',
    );
    return File(savedPath);
  }

  /// Ensures a [CustodyDocument]'s local PDF file exists on disk, regenerating if needed.
  static Future<File> ensureCustodyPdfFile(CustodyDocument doc) async {
    if (doc.pdfPath.isNotEmpty) {
      final f = File(doc.pdfPath);
      if (await f.exists()) {
        return f;
      }
    }
    final regenerated = await generateAndSaveCustodyDocumentPdf(doc);
    if (doc.id != null) {
      await DatabaseHelper().updateCustodyDocument(doc.copyWith(pdfPath: regenerated.path));
    }
    return regenerated;
  }

  /// Merges all selected [CustodyDocument]s into a single consolidated multi-page PDF.
  static Future<File> generateBulkCustodyDocumentsPdf(List<CustodyDocument> docs) async {
    final pdf = pw.Document();
    final logoImage = PdfBaseHelper.getCompanyLogo();

    for (final doc in docs) {
      _addCustodyDocumentPages(
        pdf,
        documentNumber: doc.documentNumber,
        title: doc.title,
        employeeName: doc.employeeName,
        employeePhone: doc.employeePhone,
        employeeEmail: doc.employeeEmail,
        handoverDate: doc.handoverDate,
        dueDate: doc.dueDate,
        items: doc.items,
        agreementText: doc.agreementText,
        adminNotes: doc.adminNotes,
        signatureBytes: doc.signatureBytes,
        logoImage: logoImage,
      );
    }

    final bytes = Uint8List.fromList(await pdf.save());
    return PdfBaseHelper.writeTempFile(
      bytes,
      'Bulk_Custody_Documents_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Generates a consolidated multi-page PDF of custody forms for multiple selected laptops.
  static Future<File> generateBulkLaptopCustodyPdf(List<Laptop> laptops) async {
    final pdf = pw.Document();
    final logoImage = PdfBaseHelper.getCompanyLogo();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (final laptop in laptops) {
      final user = laptop.user.isNotEmpty ? laptop.user : 'Unassigned / In Stock';
      _addCustodyDocumentPages(
        pdf,
        documentNumber: CustodyDocument.generateDocumentNumber(),
        title: 'Equipment Custody Receipt',
        employeeName: user,
        employeePhone: '',
        employeeEmail: '',
        handoverDate: today,
        dueDate: '',
        items: [
          CustodyItem(
            deviceType: 'Laptop',
            deviceName: laptop.model,
            deviceNumber: laptop.laptopNumber,
            serialNumber: laptop.laptopNumber,
            condition: laptop.condition,
            extraSpecs: {
              'Processor (CPU)': laptop.cpu.isNotEmpty ? laptop.cpu : 'Standard',
              'Graphics (GPU)': laptop.gpu.isNotEmpty ? laptop.gpu : 'Integrated',
              'Memory (RAM)': laptop.ram.isNotEmpty ? laptop.ram : 'Standard',
              'Storage Drive': laptop.storage.isNotEmpty ? laptop.storage : 'Standard',
            },
          ),
        ],
        agreementText:
            'The recipient acknowledges receipt and custody of this computing workstation. '
            'The equipment remains sole property of the organization and must be surrendered upon IT audit or request.',
        adminNotes: laptop.notes,
        signatureBytes: null,
        logoImage: logoImage,
      );
    }

    final bytes = Uint8List.fromList(await pdf.save());
    return PdfBaseHelper.writeTempFile(
      bytes,
      'Bulk_Laptop_Custody_Slips_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
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
    await PdfBaseHelper.sharePdfFile(
      file,
      subject: 'Equipment Custody Slip - $device - $employeeName',
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
      await shareCustodyFile(file, employeeName, device);
    }
  }
}
