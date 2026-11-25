// lib/screens/others/other_devices_screen.dart
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/other_device.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import '../../theme/app_theme.dart';
import 'other_device_form_screen.dart';

class OtherDevicesScreen extends StatefulWidget {
  final int? initialItemId;
  const OtherDevicesScreen({super.key, this.initialItemId});
  @override
  State<OtherDevicesScreen> createState() => _OtherDevicesScreenState();
}

class _OtherDevicesScreenState extends State<OtherDevicesScreen> with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper();
  late final Listenable _tablesListenable;
  final _search = TextEditingController();
  List<OtherDevice> _all = [];
  List<OtherDevice> _filtered = [];
  bool _loading = true;
  bool _handledInitial = false;
  final Set<int> _selectedIds = <int>{};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tablesListenable = _db.tables(['other_devices']);
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
      final list = await _db.getOtherDevices();
      if (!mounted) return;
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
        showSnack(context, 'Failed to load devices: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase().trim();
    setState(() {
      _filtered = _all.where((d) {
        return d.deviceType.toLowerCase().contains(q) ||
            d.deviceName.toLowerCase().contains(q) ||
            d.model.toLowerCase().contains(q) ||
            d.notes.toLowerCase().contains(q);
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
      message: 'Delete ${_selectedIds.length} devices from Others inventory?',
      confirmText: 'Delete',
    );
    if (!confirm || !mounted) return;
    for (final id in _selectedIds) {
      await _db.deleteOtherDevice(id);
    }
    if (!mounted) return;
    showSnack(context, '${_selectedIds.length} devices removed');
    _selectedIds.clear();
    _load();
  }

  Future<void> _openForm([OtherDevice? existing]) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OtherDeviceFormScreen(device: existing)),
    );
    if (res == true && mounted) {
      _load();
    }
  }

  void _showDetail(OtherDevice d) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showFintechBottomSheet(
      context: context,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'other_icon_${d.id}',
                  child: IconBox(
                    icon: _iconForType(d.deviceType),
                    color: cs.primary,
                    size: 50,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.deviceName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      if (d.model.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          d.model,
                          style: credentialFont(
                            fontSize: 12.5,
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    d.deviceType,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openForm(d);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Edit Details'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final ok = await showConfirmDialog(
                        context,
                        title: 'Delete Hardware?',
                        message: 'Are you sure you want to remove "${d.deviceName}" from inventory?',
                        confirmText: 'Delete',
                      );
                      if (ok && d.id != null) {
                        await _db.deleteOtherDevice(d.id!);
                        if (mounted) {
                          _load();
                          showSnack(context, 'Device deleted');
                        }
                      }
                    },
                    icon: Icon(Icons.delete_outline_rounded, size: 17, color: cs.error),
                    label: Text('Delete', style: TextStyle(color: cs.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionLabel('DEVICE SPECIFICATIONS'),
            FintechGroupedCard(
              children: [
                DetailRow(
                  label: 'Device Type',
                  value: d.deviceType,
                  icon: Icons.category_outlined,
                ),
                DetailRow(
                  label: 'Device Name',
                  value: d.deviceName,
                  icon: Icons.devices_other_rounded,
                  copyable: true,
                ),
                if (d.model.isNotEmpty)
                  DetailRow(
                    label: 'Model',
                    value: d.model,
                    icon: Icons.precision_manufacturing_outlined,
                    copyable: true,
                  ),
                if (d.notes.isNotEmpty)
                  DetailRow(
                    label: 'Notes / Specs',
                    value: d.notes,
                    icon: Icons.notes_rounded,
                    copyable: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('projector')) return Icons.videocam_rounded;
    if (t.contains('nas') || t.contains('storage') || t.contains('server')) return Icons.dns_rounded;
    if (t.contains('ups') || t.contains('power')) return Icons.battery_charging_full_rounded;
    if (t.contains('scanner')) return Icons.scanner_rounded;
    if (t.contains('tv') || t.contains('display') || t.contains('screen')) return Icons.tv_rounded;
    if (t.contains('audio') || t.contains('speaker') || t.contains('mic')) return Icons.speaker_rounded;
    if (t.contains('camera') || t.contains('cctv')) return Icons.videocam_outlined;
    return Icons.devices_other_rounded;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      floatingActionButton: _isSelectionMode
          ? null
          : SmoothExitFab(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: FintechFab(
                  onPressed: () => _openForm(),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF81C784)
                      : const Color(0xFF2E7D32),
                  tooltip: 'Add Device',
                ),
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
            )
          : null,
      body: Column(
        children: [
          SearchBar2(
            controller: _search,
            hint: 'Search device type, name, model or notes...',
          ),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.devices_other_rounded,
                        title: _search.text.isEmpty ? 'No Other Devices Yet' : 'No Results',
                        subtitle: _search.text.isEmpty
                            ? 'Tap + to add miscellaneous hardware'
                            : 'Try a different search',
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.32,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final d = _filtered[i];
                          final isSel = _selectedIds.contains(d.id);

                          return SlideInAndFade(
                            index: i,
                            child: InventoryGridCard(
                              selected: isSel,
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(d.id!)
                                  : () => _showDetail(d),
                              onLongPress: () {
                                if (d.id != null) _toggleSelection(d.id!);
                              },
                              leading: IconBox(
                                icon: _iconForType(d.deviceType),
                                color: cs.primary,
                                size: 36,
                              ),
                              badge: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cs.secondaryContainer.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  d.deviceType,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSecondaryContainer,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              title: d.deviceName,
                              subtitle: d.model.isNotEmpty ? d.model : d.deviceType,
                              extra: d.notes.isNotEmpty ? d.notes : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
