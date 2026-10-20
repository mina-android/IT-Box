import 'dart:async';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/electronic.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import 'electronic_form_screen.dart';

class ElectronicsScreen extends StatefulWidget {
  const ElectronicsScreen({super.key});
  @override
  State<ElectronicsScreen> createState() => _ElectronicsScreenState();
}

class _ElectronicsScreenState extends State<ElectronicsScreen> with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper();
  StreamSubscription<List<Electronic>>? _sub;
  final _search = TextEditingController();
  List<Electronic> _all = [];
  List<Electronic> _filtered = [];
  bool _loading = true;
  final Set<int> _selectedIds = <int>{};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sub = _db.watchElectronics().listen((list) {
      if (mounted) {
        setState(() {
          _all = list;
          _applyFilter();
          _loading = false;
        });
      }
    });
    _search.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoader = false}) async {
    if (showLoader || _all.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final list = await _db.getElectronics();
      if (!mounted) {
        return;
      }
      setState(() {
        _all = list;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to load electronics: $e', error: true);
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
      _filtered = _all.where((e) {
        return e.deviceName.toLowerCase().contains(q) ||
            e.deviceNumber.toLowerCase().contains(q) ||
            e.details.toLowerCase().contains(q);
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
      message: 'Delete ${_selectedIds.length} electronics?',
      confirmText: 'Delete',
    );
    if (!confirm || !mounted) {
      return;
    }
    int deleted = 0;
    int skippedBorrowed = 0;
    for (final id in _selectedIds) {
      if (await _db.isDeviceBorrowed('electronic', id)) {
        skippedBorrowed++;
        continue;
      }
      try {
        await _db.deleteElectronic(id);
        deleted++;
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }
    if (skippedBorrowed > 0) {
      showSnack(
        context,
        '$deleted devices deleted. $skippedBorrowed skipped because actively borrowed.',
        error: skippedBorrowed > 0 && deleted == 0,
      );
    } else {
      showSnack(context, '$deleted devices deleted');
    }
    _selectedIds.clear();
    _load();
  }

  Future<void> _openForm([Electronic? e]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ElectronicFormScreen(electronic: e)),
    );
    if (ok == true && mounted) {
      _load();
    }
  }

  Future<void> _delete(Electronic e, {bool confirm = true}) async {
    final isBorrowed = await _db.isDeviceBorrowed('electronic', e.id!);
    if (!mounted) return;
    if (isBorrowed) {
      showSnack(
        context,
        'Cannot delete "${e.deviceName}" while actively borrowed. Return it first.',
        error: true,
      );
      return;
    }
    bool ok = true;
    if (confirm) {
      ok = await showConfirmDialog(
        context,
        title: 'Delete Device',
        message: 'Delete "${e.deviceName}"?',
      );
    }
    if (!ok || !mounted) {
      return;
    }
    try {
      await _db.deleteElectronic(e.id!);
      if (!mounted) {
        return;
      }
      if (confirm) {
        showSnack(context, 'Device deleted');
      }
      _load();
    } catch (err) {
      if (!mounted) return;
      showSnack(context, 'Error deleting device: $err', error: true);
    }
  }

  void _showDetail(Electronic e) {
    showFintechBottomSheet(
      context: context,
      child: _ElectronicDetailSheet(
        electronic: e,
        onEdit: () {
          Navigator.pop(context);
          _openForm(e);
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(e);
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
          SearchBar2(controller: _search, hint: 'Search gadgets, screens, peripherals...'),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.devices_other_rounded,
                        title: _search.text.isEmpty
                            ? 'No Electronics Yet'
                            : 'No Results',
                        subtitle: _search.text.isEmpty
                            ? 'Tap + to register other electronics'
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
                          final e = _filtered[i];
                          final isSelected = _selectedIds.contains(e.id);
                          return SlideInAndFade(
                            index: i,
                            child: InventoryGridCard(
                              selected: isSelected,
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(e.id!)
                                  : () => _showDetail(e),
                              onLongPress: () => _toggleSelection(e.id!),
                              leading: const IconBox(
                                icon: Icons.devices_other_rounded,
                                color: AppColors.electronicColor,
                                size: 36,
                              ),
                              badge: StatusBadge(e.status),
                              title: e.deviceName,
                              subtitle: '# ${e.deviceNumber}',
                              extra: e.details.isNotEmpty ? e.details : null,
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
                tooltip: 'Add Device',
              ),
            ),
      bottomNavigationBar: _isSelectionMode
          ? BottomAppBar(
              elevation: 4,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _selectedIds.clear()),
                  ),
                  Text(
                    '${_selectedIds.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red),
                    onPressed: _bulkDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _ElectronicDetailSheet extends StatelessWidget {
  final Electronic electronic;
  final VoidCallback onEdit, onDelete;
  const _ElectronicDetailSheet({
    required this.electronic,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = electronic;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBox(
                icon: Icons.devices_other_rounded,
                color: AppColors.electronicColor,
                size: 50,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.deviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '# ${e.deviceNumber}',
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
              StatusBadge(e.status),
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
          const SectionLabel('DEVICE SPECIFICATIONS & DETAILS'),
          FintechGroupedCard(
            children: [
              DetailRow(
                label: 'Device Tag',
                value: e.deviceNumber,
                icon: Icons.tag_rounded,
                copyable: true,
              ),
              DetailRow(
                label: 'Device Name',
                value: e.deviceName,
                icon: Icons.devices_other_rounded,
              ),
              if (e.details.isNotEmpty)
                DetailRow(
                  label: 'Specifications',
                  value: e.details,
                  icon: Icons.info_outline_rounded,
                ),
              DetailRow(
                label: 'Borrowable',
                value: e.excludeFromBorrowing ? 'No (Office Only)' : 'Yes (Available to borrow)',
                icon: Icons.swap_horiz_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
