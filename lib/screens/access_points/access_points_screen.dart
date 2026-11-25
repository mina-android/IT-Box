import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/access_point.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import 'access_point_form_screen.dart';

class AccessPointsScreen extends StatefulWidget {
  final int? initialItemId;
  const AccessPointsScreen({super.key, this.initialItemId});
  @override
  State<AccessPointsScreen> createState() => _AccessPointsScreenState();
}

class _AccessPointsScreenState extends State<AccessPointsScreen> with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper();
  late final Listenable _tablesListenable;
  final _search = TextEditingController();
  List<AccessPoint> _all = [];
  List<AccessPoint> _filtered = [];
  bool _loading = true;
  bool _handledInitial = false;
  final Set<int> _selectedIds = <int>{};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tablesListenable = _db.tables(['access_points']);
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
      final list = await _db.getAccessPoints();
      if (!mounted) {
        return;
      }
      setState(() {
        _all = list;
        _applyFilter();
      });
      if (!_handledInitial && widget.initialItemId != null) {
        final match = list.where((d) => d.id == widget.initialItemId).firstOrNull;
        if (match != null) {
          _handledInitial = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showDetail(match);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to load access points: $e', error: true);
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
      _filtered = _all.where((d) {
        return d.model.toLowerCase().contains(q) ||
            d.deviceNumber.toLowerCase().contains(q) ||
            d.portNumber.toLowerCase().contains(q) ||
            d.location.toLowerCase().contains(q);
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
      message: 'Delete ${_selectedIds.length} access points?',
      confirmText: 'Delete',
    );
    if (!confirm || !mounted) {
      return;
    }
    for (final id in _selectedIds) {
      await _db.deleteAccessPoint(id);
    }
    if (!mounted) {
      return;
    }
    showSnack(context, '${_selectedIds.length} APs deleted');
    _selectedIds.clear();
    _load();
  }

  Future<void> _duplicate() async {
    if (_selectedIds.length != 1) {
      return;
    }
    final original = _all.firstWhere((d) => d.id == _selectedIds.first);
    final clone = AccessPoint(
      deviceNumber: '${original.deviceNumber}-copy',
      model: original.model,
      portNumber: original.portNumber,
      location: original.location,
    );
    await _db.insertAccessPoint(clone);
    if (!mounted) {
      return;
    }
    showSnack(context, 'Duplicated: ${clone.deviceNumber}');
    _selectedIds.clear();
    _load();
  }

  Future<void> _openForm([AccessPoint? ap]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AccessPointFormScreen(ap: ap)),
    );
    if (ok == true && mounted) {
      _load();
    }
  }

  Future<void> _delete(AccessPoint d, {bool confirm = true}) async {
    bool ok;
    if (confirm) {
      ok = await showConfirmDialog(
        context,
        title: 'Delete AP?',
        message: 'Delete "${d.model}" (${d.deviceNumber})?',
      );
    } else {
      ok = true;
    }
    if (!ok || !mounted) {
      return;
    }
    await _db.deleteAccessPoint(d.id!);
    if (!mounted) {
      return;
    }
    if (confirm) {
      showSnack(context, 'Access Point deleted');
    }
    _load();
  }

  void _showDetail(AccessPoint d) {
    showFintechBottomSheet(
      context: context,
      child: _AccessPointDetailSheet(
        ap: d,
        onEdit: () {
          Navigator.pop(context);
          _openForm(d);
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(d);
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
          SearchBar2(controller: _search, hint: 'Search APs, ports, rooms...'),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.cell_tower_rounded,
                        title: _search.text.isEmpty
                            ? 'No Access Points'
                            : 'No Results',
                        subtitle: _search.text.isEmpty
                            ? 'Tap + to add an access point'
                            : 'Try a different search',
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
                          final d = _filtered[i];
                          final isSelected = _selectedIds.contains(d.id);
                          return SlideInAndFade(
                            index: i,
                            child: InventoryGridCard(
                              selected: isSelected,
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(d.id!)
                                  : () => _showDetail(d),
                              onLongPress: () => _toggleSelection(d.id!),
                              leading: const IconBox(
                                icon: Icons.cell_tower_rounded,
                                color: Color(0xFF0891B2),
                                size: 36,
                              ),
                              title: d.model,
                              subtitle: '# ${d.deviceNumber}',
                              extra: d.portNumber.isNotEmpty
                                  ? 'Port ${d.portNumber}'
                                  : (d.location.isNotEmpty ? d.location : null),
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
                tooltip: 'Add AP',
              ),
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

class _AccessPointDetailSheet extends StatelessWidget {
  final AccessPoint ap;
  final VoidCallback onEdit, onDelete;
  const _AccessPointDetailSheet({
    required this.ap,
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
                icon: Icons.cell_tower_rounded,
                color: Color(0xFF0891B2),
                size: 50,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ap.model,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '# ${ap.deviceNumber}',
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
          const SectionLabel('CONFIGURATION & LOCATION'),
          FintechGroupedCard(
            children: [
              DetailRow(
                label: 'Device Tag',
                value: ap.deviceNumber,
                icon: Icons.tag_rounded,
                copyable: true,
              ),
              DetailRow(
                label: 'Model',
                value: ap.model,
                icon: Icons.memory_rounded,
              ),
              DetailRow(
                label: 'Switch Port',
                value: ap.portNumber,
                icon: Icons.settings_ethernet_rounded,
                copyable: true,
              ),
              DetailRow(
                label: 'Physical Location',
                value: ap.location,
                icon: Icons.location_on_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
