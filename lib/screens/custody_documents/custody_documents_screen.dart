// lib/screens/custody_documents/custody_documents_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/custody_document.dart';
import '../../services/custody_pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import '../documents_vault/document_viewer_screen.dart';
import 'custody_document_form_screen.dart';

class CustodyDocumentsScreen extends StatefulWidget {
  final int? initialItemId;
  const CustodyDocumentsScreen({super.key, this.initialItemId});

  @override
  State<CustodyDocumentsScreen> createState() => _CustodyDocumentsScreenState();
}

class _CustodyDocumentsScreenState extends State<CustodyDocumentsScreen> {
  final _db = DatabaseHelper();
  final _searchCtrl = TextEditingController();
  StreamSubscription<List<CustodyDocument>>? _sub;

  List<CustodyDocument> _all = [];
  List<CustodyDocument> _filtered = [];
  String _sourceFilter = 'all'; // 'all', 'custom', 'borrow', 'laptop'
  String _query = '';
  bool _loading = true;
  bool _showSearch = false;
  bool _isExporting = false;
  bool _handledInitial = false;

  final Set<int> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _sub = _db.watchCustodyDocuments().listen((docs) {
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
        if (_sourceFilter != 'all' && d.sourceType != _sourceFilter) {
          return false;
        }
        if (q.isEmpty) {
          return true;
        }
        return d.documentNumber.toLowerCase().contains(q) ||
            d.title.toLowerCase().contains(q) ||
            d.employeeName.toLowerCase().contains(q) ||
            d.items.any((it) =>
                it.deviceName.toLowerCase().contains(q) ||
                it.deviceNumber.toLowerCase().contains(q) ||
                it.serialNumber.toLowerCase().contains(q));
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

  Future<void> _openCreateCustom() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CustodyDocumentFormScreen()),
    );
  }

  Future<void> _openViewer(CustodyDocument doc) async {
    final file = await CustodyPdfService.ensureCustodyPdfFile(doc);
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: '${doc.documentNumber} • ${doc.employeeName}',
          filePath: file.path,
          isPdf: true,
          emailRecipient: doc.employeeEmail,
          emailEmployeeName: doc.employeeName,
          emailDeviceLabel: doc.items.map((e) => e.deviceName).join(', '),
        ),
      ),
    );
  }

  Future<void> _bulkExportSelected() async {
    if (_selectedIds.isEmpty || _isExporting) {
      return;
    }
    setState(() => _isExporting = true);
    try {
      final selectedDocs = _all.where((d) => d.id != null && _selectedIds.contains(d.id!)).toList();
      final mergedPdf = await CustodyPdfService.generateBulkCustodyDocumentsPdf(selectedDocs);
      if (!mounted) {
        return;
      }
      setState(() => _selectedIds.clear());
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentViewerScreen(
            title: 'Bulk Custody Export (${selectedDocs.length})',
            filePath: mergedPdf.path,
            isPdf: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Bulk export failed: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Custody Documents',
      message: 'Permanently delete $count selected custody document${count == 1 ? '' : 's'}?',
      confirmText: 'Delete ($count)',
      confirmColor: Colors.red,
    );
    if (!ok || !mounted) {
      return;
    }
    final ids = _selectedIds.toList();
    setState(() => _selectedIds.clear());
    await _db.deleteCustodyDocumentsByIds(ids);
    if (mounted) {
      showSnack(context, 'Deleted $count custody document${count == 1 ? '' : 's'}');
    }
  }

  void _showDocActions(CustodyDocument doc) {
    final items = doc.items;
    showFintechBottomSheet(
      context: context,
      title: doc.title,
      subtitle: '${doc.documentNumber} • ${doc.employeeName}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailRow(
            label: 'Document No.',
            value: doc.documentNumber,
            icon: Icons.tag_rounded,
            textStyle: credentialFont(fontSize: 13),
          ),
          DetailRow(
            label: 'Recipient',
            value: doc.employeeName,
            icon: Icons.person_outline_rounded,
          ),
          DetailRow(
            label: 'Handover Date',
            value: doc.handoverDate,
            icon: Icons.calendar_today_rounded,
          ),
          if (doc.dueDate.isNotEmpty)
            DetailRow(
              label: 'Return Due',
              value: doc.dueDate,
              icon: Icons.event_available_rounded,
            ),
          DetailRow(
            label: 'Equipment Items',
            value: items.map((e) => '${e.deviceName} (${e.deviceNumber})').join('\n'),
            icon: Icons.devices_rounded,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openViewer(doc);
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('View PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final file = await CustodyPdfService.ensureCustodyPdfFile(doc);
                    await CustodyPdfService.shareCustodyFile(
                      file,
                      doc.employeeName,
                      doc.documentNumber,
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (doc.sourceType == 'custom') ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustodyDocumentFormScreen(existing: doc),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
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
                      message: 'Delete custody document ${doc.documentNumber}?',
                      confirmText: 'Delete',
                      confirmColor: Colors.red,
                    );
                    if (ok && doc.id != null) {
                      await _db.deleteCustodyDocument(doc.id!);
                      if (mounted) {
                        showSnack(context, 'Custody document deleted');
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Custody Documents',
        subtitle: '${_all.length} archived & custom receipts',
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
              hint: 'Search doc #, employee, device or tag...',
              onChanged: (v) {
                _query = v;
                _applyFilter();
              },
            ),
          FintechFilterBar(
            children: [
              for (final entry in const [
                ('all', 'All'),
                ('custom', 'Custom'),
                ('borrow', 'Borrowed'),
                ('laptop', 'Laptops'),
              ])
                FintechFilterPill(
                  label: entry.$2,
                  selected: _sourceFilter == entry.$1,
                  color: switch (entry.$1) {
                    'custom' => const Color(0xFF6366F1),
                    'laptop' => const Color(0xFF10B981),
                    'borrow' => const Color(0xFFF59E0B),
                    _ => cs.primary,
                  },
                  onTap: () {
                    setState(() => _sourceFilter = entry.$1);
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
                        icon: Icons.assignment_turned_in_outlined,
                        title: 'No Custody Documents',
                        subtitle: _query.isNotEmpty || _sourceFilter != 'all'
                            ? 'No custody documents match your current filter.'
                            : 'Create a custom custody receipt or generate one from Borrowed / Laptops.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final doc = _filtered[i];
                          final id = doc.id ?? -1;
                          final isSelected = _selectedIds.contains(id);
                          final items = doc.items;
                          final primaryItem = items.isNotEmpty ? items.first.deviceName : 'Equipment';
                          final extraCount = items.length > 1 ? ' +${items.length - 1} more' : '';
                          final badgeColor = switch (doc.sourceType) {
                            'custom' => const Color(0xFF6366F1),
                            'laptop' => const Color(0xFF10B981),
                            _ => const Color(0xFFF59E0B),
                          };

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
                                          : Icons.assignment_turned_in_rounded,
                                      color: isSelected ? cs.primary : badgeColor,
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
                                                  doc.employeeName,
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
                                                  color: badgeColor.withValues(alpha: 0.14),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  doc.sourceType.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: badgeColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$primaryItem$extraCount',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: cs.onSurface.withValues(alpha: 0.78),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                doc.documentNumber,
                                                style: credentialFont(
                                                  fontSize: 11,
                                                  color: cs.onSurface.withValues(alpha: 0.55),
                                                ),
                                              ),
                                              Text(
                                                ' • ${doc.handoverDate}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: cs.onSurface.withValues(alpha: 0.55),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_isSelectionMode)
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                                        tooltip: 'Open PDF',
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
                  onPressed: _isExporting ? null : _bulkExportSelected,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Bulk PDF', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      floatingActionButton: _isSelectionMode
          ? null
          : SmoothExitFab(
              child: FintechFab(
                onPressed: _openCreateCustom,
                icon: Icons.note_add_rounded,
                tooltip: 'New Custom Custody Document',
                color: cs.primary,
              ),
            ),
    );
  }
}
