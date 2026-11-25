// lib/screens/documents_vault/documents_vault_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../../database/database_helper.dart';
import '../../models/vault_document.dart';
import '../../services/document_storage_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import 'document_viewer_screen.dart';
import 'vault_document_form_screen.dart';

class DocumentsVaultScreen extends StatefulWidget {
  final bool autoStartScan;
  final int? initialItemId;
  const DocumentsVaultScreen({
    super.key,
    this.autoStartScan = false,
    this.initialItemId,
  });

  @override
  State<DocumentsVaultScreen> createState() => _DocumentsVaultScreenState();
}

class _DocumentsVaultScreenState extends State<DocumentsVaultScreen> {
  final _db = DatabaseHelper();
  final _searchCtrl = TextEditingController();
  StreamSubscription<List<VaultDocument>>? _sub;

  List<VaultDocument> _all = [];
  List<VaultDocument> _filtered = [];
  String _selectedCategory = 'All';
  String _query = '';
  bool _loading = true;
  bool _showSearch = false;
  bool _handledInitial = false;

  final Set<int> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _sub = _db.watchVaultDocuments().listen((docs) {
      if (!mounted) {
        return;
      }
      final validIds = docs.where((d) => d.id != null).map((d) => d.id!).toSet();
      _selectedIds.removeWhere((id) => !validIds.contains(id));
      _all = docs;
      _loading = false;
      _applyFilter();
      if (!_handledInitial && widget.initialItemId != null) {
        final match = docs.where((d) => d.id == widget.initialItemId).firstOrNull;
        if (match != null) {
          _handledInitial = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showDocActions(match);
            }
          });
        }
      }
    });
    if (widget.autoStartScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scanDocument();
        }
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _query.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((d) {
        if (_selectedCategory != 'All' && d.category != _selectedCategory) {
          return false;
        }
        if (q.isEmpty) {
          return true;
        }
        return d.title.toLowerCase().contains(q) ||
            d.category.toLowerCase().contains(q) ||
            d.linkedEmployeeName.toLowerCase().contains(q) ||
            d.linkedAssetLabel.toLowerCase().contains(q) ||
            d.notes.toLowerCase().contains(q);
      }).toList();
    });
  }

  void _toggleSelection(int id) {
    AppHaptics.tap(context, HapticStrength.selection);
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _scanDocument() async {
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
        final pdfFile = File(result.pdf!.uri);
        final pageCount = result.pdf!.pageCount;
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => VaultDocumentFormScreen(
              initialFilePath: pdfFile.path,
              initialFileType: 'pdf',
              initialPageCount: pageCount,
            ),
          ),
        );
      } else if (images.isNotEmpty) {
        if (images.length == 1) {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => VaultDocumentFormScreen(
                initialFilePath: images.first,
                initialFileType: 'image',
                initialPageCount: 1,
              ),
            ),
          );
        } else {
          final bundledPath = await DocumentStorageService.bundleImagesToVaultPdf(
            images,
            'Scanned_Document',
          );
          if (!mounted) {
            return;
          }
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => VaultDocumentFormScreen(
                initialFilePath: bundledPath,
                initialFileType: 'pdf',
                initialPageCount: images.length,
                fileAlreadyInVault: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(
        context,
        'Scanner unavailable on this device ($e). Use Import File instead.',
        error: true,
      );
    } finally {
      scanner?.close();
    }
  }

  Future<void> _importFile() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (result.isEmpty || !mounted) {
        return;
      }
      final pickedPath = result.first.path;
      if (pickedPath == null || pickedPath.isEmpty) {
        return;
      }
      final ext = p.extension(pickedPath).toLowerCase();
      final isPdf = ext == '.pdf';
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => VaultDocumentFormScreen(
            initialFilePath: pickedPath,
            initialFileType: isPdf ? 'pdf' : 'image',
            initialPageCount: 1,
            initialTitle: p.basenameWithoutExtension(pickedPath),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        showSnack(context, 'File import failed: $e', error: true);
      }
    }
  }

  void _showAddOptions() {
    showFintechBottomSheet(
      context: context,
      title: 'Add to Documents Vault',
      subtitle: 'Scan physical pages or import existing PDF / images',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const IconBox(
              icon: Icons.document_scanner_rounded,
              color: Color(0xFF0EA5E9),
              size: 42,
            ),
            title: const Text('Scan Document', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Auto-edge crop, perspective fix & multi-page PDF'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pop(context);
              _scanDocument();
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const IconBox(
              icon: Icons.upload_file_rounded,
              color: Color(0xFF10B981),
              size: 42,
            ),
            title: const Text('Import PDF / Image', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Pick a PDF, JPG, PNG, or WebP from storage'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pop(context);
              _importFile();
            },
          ),
        ],
      ),
    );
  }

  void _openViewer(VaultDocument doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: doc.title,
          filePath: doc.filePath,
          isPdf: doc.isPdf,
        ),
      ),
    );
  }

  Future<void> _batchShareSelected() async {
    final files = _all
        .where((d) => d.id != null && _selectedIds.contains(d.id!) && File(d.filePath).existsSync())
        .map((d) => XFile(d.filePath, mimeType: d.isPdf ? 'application/pdf' : 'image/*'))
        .toList();
    if (files.isEmpty) {
      showSnack(context, 'No valid files found to share.', error: true);
      return;
    }
    setState(() => _selectedIds.clear());
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        subject: 'IT Box Documents Vault (${files.length} files)',
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Vault Documents',
      message: 'Permanently delete $count selected document${count == 1 ? '' : 's'} and their local files?',
      confirmText: 'Delete ($count)',
      confirmColor: Colors.red,
    );
    if (!ok || !mounted) {
      return;
    }
    final ids = _selectedIds.toList();
    setState(() => _selectedIds.clear());
    await _db.deleteVaultDocumentsByIds(ids);
    if (mounted) {
      showSnack(context, 'Deleted $count vault document${count == 1 ? '' : 's'}');
    }
  }

  void _showDocActions(VaultDocument doc) {
    final catColor = VaultDocument.colorForCategory(doc.category);
    showFintechBottomSheet(
      context: context,
      title: doc.title,
      subtitle: '${doc.category} • ${doc.formattedSize}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailRow(
            label: 'Category',
            value: doc.category,
            icon: VaultDocument.iconForCategory(doc.category),
          ),
          DetailRow(
            label: 'Format',
            value: '${doc.isPdf ? 'PDF' : 'Image'} • ${doc.pageCount} page${doc.pageCount == 1 ? '' : 's'} (${doc.formattedSize})',
            icon: Icons.insert_drive_file_outlined,
          ),
          if (doc.linkedEmployeeName.isNotEmpty)
            DetailRow(
              label: 'Linked Employee',
              value: doc.linkedEmployeeName,
              icon: Icons.person_outline_rounded,
            ),
          if (doc.linkedAssetLabel.isNotEmpty)
            DetailRow(
              label: 'Linked Asset',
              value: doc.linkedAssetType.isNotEmpty
                  ? '${doc.linkedAssetType}: ${doc.linkedAssetLabel}'
                  : doc.linkedAssetLabel,
              icon: Icons.devices_outlined,
            ),
          if (doc.notes.isNotEmpty)
            DetailRow(
              label: 'Notes',
              value: doc.notes,
              icon: Icons.notes_rounded,
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: catColor),
                  onPressed: () {
                    Navigator.pop(context);
                    _openViewer(doc);
                  },
                  icon: Icon(doc.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, size: 18),
                  label: const Text('Open Viewer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => VaultDocumentFormScreen(existing: doc)),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.35),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                final ok = await showConfirmDialog(
                  context,
                  title: 'Delete Document',
                  message: 'Delete "${doc.title}" from Documents Vault?',
                  confirmText: 'Delete',
                  confirmColor: Colors.red,
                );
                if (ok && doc.id != null) {
                  await _db.deleteVaultDocument(doc.id!);
                  if (mounted) {
                    showSnack(context, 'Document deleted');
                  }
                }
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = ['All', ...VaultDocument.categories];

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Documents Vault',
        subtitle: '${_all.length} scanned & stored files',
        actions: [
          FintechCircleButton(
            icon: _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
            tooltip: 'Search',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _query = '';
                  _applyFilter();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            SearchBar2(
              controller: _searchCtrl,
              hint: 'Search title, category, employee or asset...',
              onChanged: (v) {
                _query = v;
                _applyFilter();
              },
            ),
          FintechFilterBar(
            children: [
              for (final cat in categories)
                FintechFilterPill(
                  label: cat,
                  selected: _selectedCategory == cat,
                  color: cat == 'All' ? cs.primary : VaultDocument.colorForCategory(cat),
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    _applyFilter();
                  },
                ),
            ],
          ),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.document_scanner_outlined,
                        title: 'Documents Vault is Empty',
                        subtitle: _query.isNotEmpty || _selectedCategory != 'All'
                            ? 'No documents match your current filter.'
                            : 'Tap Scan Document below to scan contracts, invoices, warranties, or IDs.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final doc = _filtered[i];
                          final id = doc.id ?? -1;
                          final isSelected = _selectedIds.contains(id);
                          final catColor = VaultDocument.colorForCategory(doc.category);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                if (_isSelectionMode && doc.id != null) {
                                  _toggleSelection(doc.id!);
                                } else {
                                  _showDocActions(doc);
                                }
                              },
                              onLongPress: doc.id != null ? () => _toggleSelection(doc.id!) : null,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? cs.primary.withValues(alpha: isDark ? 0.2 : 0.08)
                                      : AppColors.cardSurface(context),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? cs.primary
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.08)
                                            : Colors.black.withValues(alpha: 0.06)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    IconBox(
                                      icon: isSelected
                                          ? Icons.check_circle_rounded
                                          : (doc.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded),
                                      color: isSelected ? cs.primary : catColor,
                                      size: 44,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  doc.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14.5,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: catColor.withValues(alpha: 0.14),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  doc.category,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: catColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                              doc.formattedSize,
                                              if (doc.isPdf) '${doc.pageCount}p',
                                              if (doc.linkedEmployeeName.isNotEmpty) doc.linkedEmployeeName,
                                              if (doc.linkedAssetLabel.isNotEmpty) doc.linkedAssetLabel,
                                            ].join(' • '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: cs.onSurface.withValues(alpha: 0.65),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_isSelectionMode)
                                      IconButton(
                                        icon: const Icon(Icons.visibility_outlined, size: 20),
                                        tooltip: 'View Document',
                                        onPressed: () => _openViewer(doc),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _isSelectionMode
          ? SelectionBottomBar(
              selectedCount: _selectedIds.length,
              totalCount: _filtered.length,
              onSelectAll: () {
                setState(() {
                  _selectedIds.addAll(_filtered.where((d) => d.id != null).map((d) => d.id!));
                });
              },
              onDeselectAll: () => setState(() => _selectedIds.clear()),
              onClose: () => setState(() => _selectedIds.clear()),
              onDelete: _deleteSelected,
              trailingActions: [
                FilledButton.icon(
                  onPressed: _batchShareSelected,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      floatingActionButton: _isSelectionMode
          ? null
          : SmoothExitFab(
              child: FintechFab(
                onPressed: _showAddOptions,
                icon: Icons.document_scanner_rounded,
                tooltip: 'Scan or Import Document',
                color: cs.primary,
              ),
            ),
    );
  }
}
