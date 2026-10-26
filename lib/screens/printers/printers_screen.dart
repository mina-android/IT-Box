import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/printer.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import '../../theme/app_theme.dart';
import 'printer_form_screen.dart';

class PrintersScreen extends StatefulWidget {
  const PrintersScreen({super.key});
  @override
  State<PrintersScreen> createState() => _PrintersScreenState();
}

class _PrintersScreenState extends State<PrintersScreen> with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper();
  late final Listenable _tablesListenable;
  final _search = TextEditingController();
  List<Printer> _all = [];
  List<Printer> _filtered = [];
  bool _loading = true;
  final Set<int> _selectedIds = <int>{};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tablesListenable = _db.tables(['printers']);
    _tablesListenable.addListener(_onDbChanged);
    _load();
    _search.addListener(_applyFilter);
  }

  void _onDbChanged() {
    if (mounted) {
      _load(showLoader: false);
    }
  }

  @override
  void dispose() {
    _tablesListenable.removeListener(_onDbChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoader = false}) async {
    if (showLoader || _all.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final list = await _db.getPrinters();
      if (!mounted) {
        return;
      }
      setState(() {
        _all = list;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to load printers: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = _all.where((p) {
        return p.model.toLowerCase().contains(q) ||
            p.printerNumber.toLowerCase().contains(q) ||
            p.location.toLowerCase().contains(q);
      }).toList();
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDelete() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Delete Selected?',
      message: 'Delete ${_selectedIds.length} printers?',
      confirmText: 'Delete',
    );
    if (!confirm || !mounted) {
      return;
    }
    for (final id in _selectedIds) {
      await _db.deletePrinter(id);
    }
    if (!mounted) {
      return;
    }
    showSnack(context, '${_selectedIds.length} printers deleted');
    _selectedIds.clear();
    _load();
  }

  Future<void> _duplicate() async {
    if (_selectedIds.length != 1) {
      return;
    }
    final original = _all.firstWhere((p) => p.id == _selectedIds.first);
    final clone = Printer(
      printerNumber: '${original.printerNumber}-copy',
      model: original.model,
      condition: original.condition,
      location: original.location,
    );
    await _db.insertPrinter(clone);
    if (!mounted) {
      return;
    }
    showSnack(context, 'Duplicated: ${clone.printerNumber}');
    _selectedIds.clear();
    _load();
  }

  Future<void> _openForm([Printer? p]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PrinterFormScreen(printer: p)),
    );
    if (ok == true && mounted) {
      _load();
    }
  }

  Future<void> _delete(Printer p, {bool confirm = true}) async {
    bool ok;
    if (confirm) {
      ok = await showConfirmDialog(
        context,
        title: 'Delete Printer?',
        message: 'Delete "${p.model}" (${p.printerNumber})?',
      );
    } else {
      ok = true;
    }
    if (!ok || !mounted) {
      return;
    }
    await _db.deletePrinter(p.id!);
    if (!mounted) {
      return;
    }
    if (confirm) {
      showSnack(context, 'Printer deleted');
    }
    _load();
  }

  void _showDetail(Printer p) {
    showFintechBottomSheet(
      context: context,
      child: _PrinterDetailSheet(
        printer: p,
        onEdit: () {
          Navigator.pop(context);
          _openForm(p);
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(p);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Column(
        children: [
          SearchBar2(controller: _search, hint: 'Search printers, locations...'),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.print_rounded,
                        title: _search.text.isEmpty
                            ? 'No Printers Yet'
                            : 'No Results',
                        subtitle: _search.text.isEmpty
                            ? 'Tap + to register a printer'
                            : 'Try a different search',
                        onRefresh: _load,
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.32,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final p = _filtered[i];
                          final isSelected = _selectedIds.contains(p.id);
                          return SlideInAndFade(
                            index: i,
                            child: InventoryGridCard(
                              selected: isSelected,
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(p.id!)
                                  : () => _showDetail(p),
                              onLongPress: () => _toggleSelection(p.id!),
                              leading: const IconBox(
                                icon: Icons.print_rounded,
                                color: AppColors.printerColor,
                                size: 36,
                              ),
                              badge: ConditionBadge(p.condition),
                              title: p.model,
                              subtitle: '# ${p.printerNumber}',
                              extra: p.location.isNotEmpty ? p.location : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FintechFab(
                onPressed: () => _openForm(),
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF81C784)
                    : const Color(0xFF2E7D32),
                tooltip: 'Add Printer',
              ),
            ),
      bottomNavigationBar: _isSelectionMode
          ? SelectionBottomBar(
              selectedCount: _selectedIds.length,
              onClose: () => setState(() => _selectedIds.clear()),
              onDelete: _bulkDelete,
              trailingActions: [
                if (_selectedIds.length == 1)
                  IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: _duplicate,
                    tooltip: 'Duplicate',
                  ),
              ],
            )
          : null,
    );
  }
}

class _PrinterDetailSheet extends StatelessWidget {
  final Printer printer;
  final VoidCallback onEdit, onDelete;
  const _PrinterDetailSheet({
    required this.printer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBox(
                icon: Icons.print_rounded,
                color: AppColors.printerColor,
                size: 50,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      printer.model,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '# ${printer.printerNumber}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ConditionBadge(printer.condition),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Details'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 16, color: theme.colorScheme.error),
                  label: Text('Delete',
                      style: TextStyle(color: theme.colorScheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: theme.colorScheme.error.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionLabel('PRINTER SPECIFICATIONS & LOCATION'),
          FintechGroupedCard(
            children: [
              DetailRow(
                label: 'Printer Tag',
                value: printer.printerNumber,
                icon: Icons.tag_rounded,
                copyable: true,
              ),
              DetailRow(
                label: 'Model',
                value: printer.model,
                icon: Icons.print_rounded,
              ),
              DetailRow(
                label: 'Condition',
                value: printer.condition,
                icon: Icons.health_and_safety_outlined,
              ),
              DetailRow(
                label: 'Location / Floor',
                value: printer.location,
                icon: Icons.location_on_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
