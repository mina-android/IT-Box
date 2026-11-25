// lib/screens/documents_vault/vault_document_form_screen.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:path/path.dart' as p;
import '../../database/database_helper.dart';
import '../../models/employee.dart';
import '../../models/vault_document.dart';
import '../../services/document_storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class VaultDocumentFormScreen extends StatefulWidget {
  final VaultDocument? existing;
  final String? initialFilePath;
  final String? initialFileType;
  final int initialPageCount;
  final String? initialTitle;
  final bool fileAlreadyInVault;

  const VaultDocumentFormScreen({
    super.key,
    this.existing,
    this.initialFilePath,
    this.initialFileType,
    this.initialPageCount = 1,
    this.initialTitle,
    this.fileAlreadyInVault = false,
  });

  @override
  State<VaultDocumentFormScreen> createState() => _VaultDocumentFormScreenState();
}

class _VaultDocumentFormScreenState extends State<VaultDocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _assetLabelCtrl;
  late final TextEditingController _notesCtrl;

  String _category = VaultDocument.categories.first;
  String _filePath = '';
  String _fileType = 'pdf';
  int _pageCount = 1;
  bool _fileNeedsCopy = false;
  String _linkedEmployeeName = '';
  String _linkedAssetType = '';
  List<Employee> _employees = [];
  bool _saving = false;

  static const _assetTypes = [
    '',
    'Laptop',
    'Router',
    'MiFi',
    'Access Point',
    'Printer',
    'Electronic',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _titleCtrl = TextEditingController(
      text: ex?.title ?? widget.initialTitle ?? '',
    );
    _assetLabelCtrl = TextEditingController(text: ex?.linkedAssetLabel ?? '');
    _notesCtrl = TextEditingController(text: ex?.notes ?? '');
    _category = ex != null && VaultDocument.categories.contains(ex.category)
        ? ex.category
        : VaultDocument.categories.first;
    _filePath = ex?.filePath ?? widget.initialFilePath ?? '';
    _fileType = ex?.fileType ?? widget.initialFileType ?? 'pdf';
    _pageCount = ex?.pageCount ?? widget.initialPageCount;
    _fileNeedsCopy = ex == null && !widget.fileAlreadyInVault && _filePath.isNotEmpty;
    _linkedEmployeeName = ex?.linkedEmployeeName ?? '';
    _linkedAssetType = _assetTypes.contains(ex?.linkedAssetType ?? '') ? (ex?.linkedAssetType ?? '') : '';

    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final emps = await _db.getEmployees();
    if (mounted) {
      setState(() => _employees = emps);
    }
  }

  Future<void> _rescan() async {
    DocumentScanner? scanner;
    try {
      scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: const {DocumentFormat.pdf},
          mode: ScannerMode.full,
          pageLimit: 20,
          isGalleryImport: true,
        ),
      );
      final result = await scanner.scanDocument();
      if (!mounted) {
        return;
      }
      final images = result.images ?? const <String>[];
      if (result.pdf != null && result.pdf!.uri.isNotEmpty) {
        setState(() {
          _filePath = result.pdf!.uri;
          _fileType = 'pdf';
          _pageCount = result.pdf!.pageCount;
          _fileNeedsCopy = true;
        });
      } else if (images.isNotEmpty) {
        if (images.length == 1) {
          setState(() {
            _filePath = images.first;
            _fileType = 'image';
            _pageCount = 1;
            _fileNeedsCopy = true;
          });
        } else {
          final bundled = await DocumentStorageService.bundleImagesToVaultPdf(
            images,
            _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Scanned_Document',
          );
          if (!mounted) {
            return;
          }
          setState(() {
            _filePath = bundled;
            _fileType = 'pdf';
            _pageCount = images.length;
            _fileNeedsCopy = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Scanner unavailable: $e', error: true);
      }
    } finally {
      scanner?.close();
    }
  }

  Future<void> _replaceFile() async {
    final result = await FilePickerPlatform.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result.isEmpty || !mounted) {
      return;
    }
    final picked = result.first.path;
    if (picked == null || picked.isEmpty) {
      return;
    }
    final ext = p.extension(picked).toLowerCase();
    setState(() {
      _filePath = picked;
      _fileType = ext == '.pdf' ? 'pdf' : 'image';
      _pageCount = 1;
      _fileNeedsCopy = true;
      if (_titleCtrl.text.trim().isEmpty) {
        _titleCtrl.text = p.basenameWithoutExtension(picked);
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_filePath.isEmpty || !File(_filePath).existsSync()) {
      showSnack(context, 'Please scan or import a valid file first.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      String finalPath = _filePath;
      if (_fileNeedsCopy) {
        finalPath = await DocumentStorageService.saveVaultFileFromPath(
          _filePath,
          _titleCtrl.text.trim(),
        );
        if (widget.existing != null &&
            widget.existing!.filePath.isNotEmpty &&
            widget.existing!.filePath != finalPath) {
          await DocumentStorageService.deleteFileIfExists(widget.existing!.filePath);
        }
      }

      final stat = await File(finalPath).stat();
      final doc = VaultDocument(
        id: widget.existing?.id,
        title: _titleCtrl.text.trim(),
        category: _category,
        filePath: finalPath,
        fileType: _fileType,
        fileSizeBytes: stat.size,
        pageCount: _pageCount,
        linkedEmployeeName: _linkedEmployeeName,
        linkedAssetType: _linkedAssetType,
        linkedAssetLabel: _assetLabelCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        createdAt: widget.existing?.createdAt ?? DateTime.now().toIso8601String(),
      );

      if (doc.id == null) {
        await _db.insertVaultDocument(doc);
      } else {
        await _db.updateVaultDocument(doc);
      }

      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to save document: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _assetLabelCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasFile = _filePath.isNotEmpty && File(_filePath).existsSync();
    final sizeBytes = hasFile ? File(_filePath).lengthSync() : 0;

    return Scaffold(
      appBar: FintechAppBar(
        title: widget.existing == null ? 'Save Vault Document' : 'Edit Vault Document',
        subtitle: 'Classify and store offline',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardSurface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (hasFile && _fileType == 'image')
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_filePath),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        IconBox(
                          icon: _fileType == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                          color: VaultDocument.colorForCategory(_category),
                          size: 52,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasFile ? p.basename(_filePath) : 'No file selected',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              hasFile
                                  ? '${_fileType.toUpperCase()} • $_pageCount page${_pageCount == 1 ? '' : 's'} • ${(sizeBytes / 1024).toStringAsFixed(1)} KB'
                                  : 'Scan or import a PDF/image',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _rescan,
                          icon: const Icon(Icons.document_scanner_rounded, size: 17),
                          label: const Text('Re-scan'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _replaceFile,
                          icon: const Icon(Icons.upload_file_rounded, size: 17),
                          label: const Text('Replace File'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const SectionLabel('DOCUMENT DETAILS'),
            AppTextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Document Title *',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            FintechDropdown<String>(
              value: _category,
              labelText: 'Category *',
              prefixIcon: const Icon(Icons.category_outlined),
              items: VaultDocument.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _category = v);
                }
              },
            ),
            const SizedBox(height: 20),

            const SectionLabel('LINKED EMPLOYEE & ASSET (OPTIONAL)'),
            InkWell(
              onTap: () async {
                final picked = await showFintechEmployeePicker(
                  context: context,
                  employees: _employees,
                  selectedEmployeeName: _linkedEmployeeName,
                  title: 'Select Linked Employee',
                  allowNone: true,
                );
                if (picked == null || !mounted) {
                  return;
                }
                setState(() {
                  _linkedEmployeeName =
                      picked.cleared ? '' : (picked.employee?.name ?? '');
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Linked Employee',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  suffixIcon: Icon(Icons.search_rounded, size: 20),
                ),
                child: Text(
                  _linkedEmployeeName.isNotEmpty
                      ? _linkedEmployeeName
                      : 'None (Unlinked) — Tap to search',
                  style: TextStyle(
                    fontWeight: _linkedEmployeeName.isNotEmpty
                        ? FontWeight.w700
                        : FontWeight.normal,
                    color: _linkedEmployeeName.isNotEmpty
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FintechDropdown<String>(
                    value: _linkedAssetType,
                    labelText: 'Asset Type',
                    items: _assetTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.isEmpty ? 'None' : t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _linkedAssetType = v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: AppTextField(
                    controller: _assetLabelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Asset Tag / Model',
                    ),
                    style: credentialFont(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Save to Vault'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
