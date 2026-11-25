// lib/screens/documents_vault/document_viewer_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/custody_pdf_service.dart';
import '../../widgets/common_widgets.dart';

class DocumentViewerScreen extends StatelessWidget {
  final String title;
  final String filePath;
  final bool isPdf;
  final String? emailRecipient;
  final String? emailEmployeeName;
  final String? emailDeviceLabel;

  const DocumentViewerScreen({
    super.key,
    required this.title,
    required this.filePath,
    required this.isPdf,
    this.emailRecipient,
    this.emailEmployeeName,
    this.emailDeviceLabel,
  });

  Future<void> _share(BuildContext context) async {
    final file = File(filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        showSnack(context, 'File not found on device.', error: true);
      }
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: isPdf ? 'application/pdf' : 'image/*',
          ),
        ],
        subject: title,
      ),
    );
  }

  Future<void> _saveCopy(BuildContext context) async {
    final file = File(filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        showSnack(context, 'File not found on device.', error: true);
      }
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      final savePath = await FilePickerPlatform.instance.saveFile(
        dialogTitle: 'Save Document Copy',
        fileName: p.basename(file.path),
        bytes: bytes,
        mimeType: isPdf ? 'application/pdf' : 'image/*',
      );
      if (!context.mounted) {
        return;
      }
      if (savePath != null) {
        showSnack(context, 'Saved copy to device');
      }
    } catch (e) {
      if (context.mounted) {
        showSnack(context, 'Save failed: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    final exists = file.existsSync();

    return Scaffold(
      appBar: FintechAppBar(
        title: title,
        subtitle: exists ? p.basename(filePath) : 'Missing file',
        actions: [
          if (exists && isPdf && emailRecipient != null)
            FintechCircleButton(
              icon: Icons.email_outlined,
              tooltip: 'Email Direct',
              onPressed: () async {
                await CustodyPdfService.emailCustodyDirect(
                  file: file,
                  recipientEmail: emailRecipient ?? '',
                  employeeName: emailEmployeeName ?? 'Recipient',
                  device: emailDeviceLabel ?? title,
                );
              },
            ),
          if (exists) ...[
            FintechCircleButton(
              icon: Icons.download_rounded,
              tooltip: 'Save Copy',
              onPressed: () => _saveCopy(context),
            ),
            FintechCircleButton(
              icon: Icons.share_rounded,
              tooltip: 'Share',
              onPressed: () => _share(context),
            ),
          ],
        ],
      ),
      body: !exists
          ? const EmptyState(
              icon: Icons.broken_image_outlined,
              title: 'Document File Missing',
              subtitle: 'The local file could not be found on this device.',
            )
          : isPdf
              ? PdfPreview(
                  build: (_) async => Uint8List.fromList(await file.readAsBytes()),
                  allowSharing: false,
                  allowPrinting: true,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  pdfFileName: p.basename(filePath),
                )
              : InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
    );
  }
}
