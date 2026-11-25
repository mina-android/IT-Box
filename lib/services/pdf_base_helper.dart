// lib/services/pdf_base_helper.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'company_service.dart';

class PdfBaseHelper {
  static String get companyName {
    final n = CompanyService().name.trim();
    return n.isNotEmpty ? n : 'IT BOX';
  }

  static pw.MemoryImage? getCompanyLogo() {
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

  static String sanitizeFilename(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.isEmpty ? 'document' : cleaned;
  }

  static Future<File> writeTempFile(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final safe = sanitizeFilename(fileName);
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> sharePdfFile(File file, {required String subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: subject,
      ),
    );
  }

  static pw.Widget buildBrandedHeader({
    required String title,
    required String subtitle,
    String? rightTitle,
    String? rightSubtitle,
    pw.MemoryImage? logoImage,
    PdfColor accentColor = PdfColors.blue900,
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
                    color: accentColor,
                  ),
                ),
                pw.Text(
                  subtitle,
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
              rightTitle ?? title,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            if (rightSubtitle != null && rightSubtitle.isNotEmpty)
              pw.Text(
                rightSubtitle,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
          ],
        ),
      ],
    );
  }
}
