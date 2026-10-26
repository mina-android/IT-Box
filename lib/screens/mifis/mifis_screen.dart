import 'dart:async';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/mifi.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import 'mifi_form_screen.dart';

const Color _mifiColor = Color(0xFFD97706); // Warm Amber

class MiFisScreen extends StatefulWidget {
  const MiFisScreen({super.key});
  @override
  State<MiFisScreen> createState() => _MiFisScreenState();
}

class _MiFisScreenState extends State<MiFisScreen> with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper();
  StreamSubscription<List<MiFi>>? _sub;
  final _search = TextEditingController();
  List<MiFi> _all = [];
  List<MiFi> _filtered = [];
  bool _loading = true;
  final Set<int> _selectedIds = <int>{};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sub = _db.watchMiFis().listen((list) {
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
      final list = await _db.getMiFis();
      if (!mounted) {
        return;
      }
      setState(() {
        _all = list;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to load MiFis: $e', error: true);
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
      _filtered = _all.where((m) {
        return m.model.toLowerCase().contains(q) ||
            m.deviceNumber.toLowerCase().contains(q) ||
            m.phoneNumber.toLowerCase().contains(q) ||
            m.wifiName.toLowerCase().contains(q) ||
            m.serviceProvider.toLowerCase().contains(q) ||
            m.tag.toLowerCase().contains(q);
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
      message: 'Delete ${_selectedIds.length} MiFis?',
      confirmText: 'Delete',
    );
    if (!confirm || !mounted) {
      return;
    }
    int deleted = 0;
    int skippedBorrowed = 0;
    for (final id in _selectedIds) {
      if (await _db.isDeviceBorrowed('mifi', id)) {
        skippedBorrowed++;
        continue;
      }
      try {
        await _db.deleteMiFi(id);
        deleted++;
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }
    if (skippedBorrowed > 0) {
      showSnack(
        context,
        '$deleted MiFis deleted. $skippedBorrowed skipped because actively borrowed.',
        error: skippedBorrowed > 0 && deleted == 0,
      );
    } else {
      showSnack(context, '$deleted MiFis deleted');
    }
    _selectedIds.clear();
    _load();
  }

  Future<void> _duplicate() async {
    if (_selectedIds.length != 1) {
      return;
    }
    final original = _all.firstWhere((m) => m.id == _selectedIds.first);
    final clone = MiFi(
      deviceNumber: '${original.deviceNumber}-copy',
      model: original.model,
      phoneNumber: original.phoneNumber,
      wifiName: original.wifiName,
      wifiPassword: original.wifiPassword,
      quota: original.quota,
      serviceProvider: original.serviceProvider,
      gateway: original.gateway,
      adminPassword: original.adminPassword,
      tag: original.tag,
      excludeFromBorrowing: original.excludeFromBorrowing,
    );
    await _db.insertMiFi(clone);
    if (!mounted) {
      return;
    }
    showSnack(context, 'Duplicated: ${clone.deviceNumber}');
    _selectedIds.clear();
    _load();
  }

  Future<void> _openForm([MiFi? m]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MiFiFormScreen(mifi: m)),
    );
    if (ok == true && mounted) {
      _load();
    }
  }

  Future<void> _delete(MiFi m, {bool confirm = true}) async {
    final isBorrowed = await _db.isDeviceBorrowed('mifi', m.id!);
    if (!mounted) return;
    if (isBorrowed) {
      showSnack(
        context,
        'Cannot delete "${m.model}" while actively borrowed. Return it first.',
        error: true,
      );
      return;
    }
    bool ok;
    if (confirm) {
      ok = await showConfirmDialog(
        context,
        title: 'Delete MiFi?',
        message: 'Delete "${m.model}" (${m.deviceNumber})?',
      );
    } else {
      ok = true;
    }
    if (!ok || !mounted) {
      return;
    }
    try {
      await _db.deleteMiFi(m.id!);
      if (!mounted) {
        return;
      }
      if (confirm) {
        showSnack(context, 'MiFi deleted');
      }
      _load();
    } catch (err) {
      if (!mounted) return;
      showSnack(context, 'Error deleting MiFi: $err', error: true);
    }
  }

  void _showDetail(MiFi m) {
    showFintechBottomSheet(
      context: context,
      child: _DetailSheet(
        mifi: m,
        onEdit: () {
          Navigator.pop(context);
          _openForm(m);
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(m);
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
          SearchBar2(controller: _search, hint: 'Search MiFi, quota, SIM...'),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.wifi_tethering_rounded,
                        title: _search.text.isEmpty
                            ? 'No MiFis Yet'
                            : 'No Results',
                        subtitle: _search.text.isEmpty
                            ? 'Tap + to add a portable MiFi'
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
                          final m = _filtered[i];
                          final isSelected = _selectedIds.contains(m.id);
                          return SlideInAndFade(
                            index: i,
                            child: InventoryGridCard(
                              selected: isSelected,
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(m.id!)
                                  : () => _showDetail(m),
                              onLongPress: () => _toggleSelection(m.id!),
                              leading: const IconBox(
                                icon: Icons.wifi_tethering_rounded,
                                color: _mifiColor,
                                size: 36,
                              ),
                              badge: StatusBadge(m.status),
                              title: m.model,
                              subtitle: '# ${m.deviceNumber}',
                              extra: m.quota.isNotEmpty
                                  ? m.quota
                                  : (m.wifiName.isNotEmpty ? m.wifiName : null),
                              bottomTrailing: m.tag.isNotEmpty
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _mifiColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _mifiColor.withValues(alpha: 0.35),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        m.tag,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: _mifiColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : null,
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
                tooltip: 'Add MiFi',
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

class _DetailSheet extends StatefulWidget {
  final MiFi mifi;
  final VoidCallback onEdit, onDelete;
  const _DetailSheet({
    required this.mifi,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  bool _showWifi = false;
  bool _showAdmin = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.mifi;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBox(
                icon: Icons.wifi_tethering_rounded,
                color: _mifiColor,
                size: 50,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.model,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '# ${m.deviceNumber}',
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
              StatusBadge(m.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onEdit,
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
                  onPressed: widget.onDelete,
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
          const SectionLabel('PACKAGE & SIM DETAILS'),
          FintechGroupedCard(
            children: [
              DetailRow(
                label: 'Phone No.',
                value: m.phoneNumber,
                icon: Icons.phone_rounded,
                copyable: true,
              ),
              DetailRow(
                label: 'Provider',
                value: m.serviceProvider,
                icon: Icons.cell_tower_rounded,
              ),
              DetailRow(
                label: 'Data Quota',
                value: m.quota,
                icon: Icons.data_usage_rounded,
              ),
              DetailRow(
                label: 'Gateway IP',
                value: m.gateway,
                icon: Icons.alt_route_rounded,
                copyable: true,
              ),
            ],
          ),
          const SectionLabel('WIFI ACCESS & SECURITY'),
          FintechGroupedCard(
            children: [
              DetailRow(
                label: 'WiFi Name',
                value: m.wifiName,
                icon: Icons.wifi_rounded,
                copyable: true,
              ),
              if (m.wifiPassword.isNotEmpty)
                _passwordRow(
                  label: 'WiFi Password',
                  value: m.wifiPassword,
                  show: _showWifi,
                  onToggle: () => setState(() => _showWifi = !_showWifi),
                  icon: Icons.lock_outline_rounded,
                  theme: theme,
                ),
              if (m.adminPassword.isNotEmpty)
                _passwordRow(
                  label: 'Admin Password',
                  value: m.adminPassword,
                  show: _showAdmin,
                  onToggle: () => setState(() => _showAdmin = !_showAdmin),
                  icon: Icons.admin_panel_settings_outlined,
                  theme: theme,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _passwordRow({
    required String label,
    required String value,
    required bool show,
    required VoidCallback onToggle,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              show ? value : '••••••••',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}
