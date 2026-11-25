// lib/services/document_storage_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'company_service.dart';

class DocumentStorageService {
  static String _sanitizeSegment(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.isEmpty ? 'default' : cleaned;
  }

  static String get activeOrgKey => _sanitizeSegment(CompanyService().activeOrganizationId);

  static Future<Directory> _orgSubDir(String rootFolder, {String? orgId}) async {
    final docs = await getApplicationDocumentsDirectory();
    final key = _sanitizeSegment(orgId ?? CompanyService().activeOrganizationId);
    final dir = Directory(p.join(docs.path, rootFolder, key));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> custodyDir({String? orgId}) => _orgSubDir('custody', orgId: orgId);
  static Future<Directory> vaultDir({String? orgId}) => _orgSubDir('vault', orgId: orgId);
  static Future<Directory> receiptsDir({String? orgId}) => _orgSubDir('receipts', orgId: orgId);

  static Future<String> saveCustodyPdfBytes(Uint8List bytes, String fileName, {String? orgId}) async {
    final dir = await custodyDir(orgId: orgId);
    final safeName = _sanitizeSegment(fileName);
    final finalName = safeName.toLowerCase().endsWith('.pdf') ? safeName : '$safeName.pdf';
    final file = File(p.join(dir.path, finalName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<String> saveVaultFileFromPath(String sourcePath, String preferredName, {String? orgId}) async {
    final src = File(sourcePath);
    final dir = await vaultDir(orgId: orgId);
    final ext = p.extension(sourcePath).toLowerCase();
    final base = _sanitizeSegment(p.basenameWithoutExtension(preferredName));
    final ts = DateTime.now().millisecondsSinceEpoch;
    final dest = File(p.join(dir.path, '${base}_$ts$ext'));
    await src.copy(dest.path);
    return dest.path;
  }

  static Future<String> saveVaultBytes(Uint8List bytes, String fileName, {String? orgId}) async {
    final dir = await vaultDir(orgId: orgId);
    final safeName = _sanitizeSegment(fileName);
    final dest = File(p.join(dir.path, safeName));
    await dest.writeAsBytes(bytes, flush: true);
    return dest.path;
  }

  static Future<String> saveReceiptFileFromPath(String sourcePath, {String? orgId}) async {
    final src = File(sourcePath);
    final dir = await receiptsDir(orgId: orgId);
    final ext = p.extension(sourcePath).toLowerCase();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final dest = File(p.join(dir.path, 'receipt_$ts$ext'));
    await src.copy(dest.path);
    return dest.path;
  }

  static Future<String> saveReceiptBytes(Uint8List bytes, String fileName, {String? orgId}) async {
    final dir = await receiptsDir(orgId: orgId);
    final safeName = _sanitizeSegment(fileName);
    final dest = File(p.join(dir.path, safeName));
    await dest.writeAsBytes(bytes, flush: true);
    return dest.path;
  }

  /// Bundles multiple scanned/selected image paths into a single multi-page PDF.
  static Future<String> bundleImagesToVaultPdf(List<String> imagePaths, String title, {String? orgId}) async {
    final pdf = pw.Document();
    for (final imgPath in imagePaths) {
      final f = File(imgPath);
      if (!await f.exists()) {
        continue;
      }
      final bytes = await f.readAsBytes();
      final memImg = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (_) => pw.Center(
            child: pw.Image(memImg, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    final pdfBytes = await pdf.save();
    final base = _sanitizeSegment(title);
    final ts = DateTime.now().millisecondsSinceEpoch;
    return saveVaultBytes(Uint8List.fromList(pdfBytes), '${base}_$ts.pdf', orgId: orgId);
  }

  static Future<void> deleteFileIfExists(String path) async {
    if (path.trim().isEmpty) {
      return;
    }
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }

  static Future<void> deleteOrganizationDirectories(String orgId) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final key = _sanitizeSegment(orgId);
      for (final folder in ['custody', 'vault', 'receipts']) {
        try {
          final dir = Directory(p.join(docs.path, folder, key));
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }
}
