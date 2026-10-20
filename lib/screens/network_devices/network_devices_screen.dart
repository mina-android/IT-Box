import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/network_device.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import 'network_device_form_screen.dart';

class NetworkDevicesScreen extends StatefulWidget {
  const NetworkDevicesScreen({super.key});
  @override
  State<NetworkDevicesScreen> createState() => _NetworkDevicesScreenState();
}

class _NetworkDevicesScreenState extends State<NetworkDevicesScreen> with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper();
  late final Listenable _tablesListenable;
  final _search = TextEditingController();
  List<NetworkDevice> _all = [];
  List<NetworkDevice> _filtered = [];
  bool _loading = true;
  final Set<int> _selectedIds = <int>{};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tablesListenable = _db.tables(['network_devices']);
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
      final list = await _db.getNetworkDevices();
      if (!mounted) {
        return;
      }
      setState(() {
        _all = list;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to load network devices: $e', error: true);
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
            d.phoneNumber.toLowerCase().contains(q) ||
            d.deviceLocation.toLowerCase().contains(q) ||
            d.serviceProvider.toLowerCase().contains(q) ||
            d.wifiName.toLowerCase().contains(q);
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
      message: 'Delete ${_selectedIds.length} network devices?',
      confirmText: 'Delete',
    );
    if (!confirm || !mounted) {
      return;
    }
    for (final id in _selectedIds) {
      await _db.deleteNetworkDevice(id);
    }
    if (!mounted) {
      return;
    }
    showSnack(context, '${_selectedIds.length} devices deleted');
    _selectedIds.clear();
    _load();
  }

  Future<void> _openForm([NetworkDevice? d]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NetworkDeviceFormScreen(device: d)),
    );
    if (ok == true && mounted) {
      _load();
    }
  }

  Future<void> _delete(NetworkDevice d, {bool confirm = true}) async {
    bool ok;
    if (confirm) {
      ok = await showConfirmDialog(
        context,
        title: 'Delete Device',
        message: 'Delete "${d.model}" (${d.deviceNumber})?',
      );
    } else {
      ok = true;
    }
    if (!ok || !mounted) {
      return;
    }
    await _db.deleteNetworkDevice(d.id!);
    if (!mounted) {
      return;
    }
    if (confirm) {
      showSnack(context, 'Device deleted');
    }
    _load();
  }

  void _showDetail(NetworkDevice d) {
    showFintechBottomSheet(
      context: context,
      child: _DetailSheet(
        device: d,
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
          SearchBar2(controller: _search, hint: 'Search routers, sims, wifi...'),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.router_rounded,
                        title: _search.text.isEmpty
                            ? 'No Network Devices'
                            : 'No Results',
                        subtitle: _search.text.isEmpty
                            ? 'Tap + to add a router or device'
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
                                icon: Icons.router_rounded,
                                color: AppColors.networkColor,
                                size: 36,
                              ),
                              badge: StatusBadge(d.status),
                              title: d.model,
                              subtitle: '# ${d.deviceNumber}',
                              extra: d.phoneNumber.isNotEmpty
                                  ? d.phoneNumber
                                  : (d.deviceLocation.isNotEmpty
                                      ? d.deviceLocation
                                      : null),
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
                tooltip: 'Add Router',
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
                    tooltip: 'Clear',
                  ),
                  const SizedBox(width: 8),
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

class _DetailSheet extends StatefulWidget {
  final NetworkDevice device;
  final VoidCallback onEdit, onDelete;
  const _DetailSheet({
    required this.device,
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
    final d = widget.device;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBox(
                icon: Icons.router_rounded,
                color: AppColors.networkColor,
                size: 50,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.model,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '# ${d.deviceNumber}',
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
              StatusBadge(d.status),
            ],
          ),
          const SizedBox(height: 16),
          // Quick action buttons
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
          const SectionLabel('DEVICE & CONNECTION INFO'),
          FintechGroupedCard(
            children: [
              DetailRow(
                label: 'Phone No.',
                value: d.phoneNumber,
                icon: Icons.phone_rounded,
                copyable: true,
              ),
              DetailRow(
                label: 'Location',
                value: d.deviceLocation,
                icon: Icons.location_on_outlined,
              ),
              DetailRow(
                label: 'Provider',
                value: d.serviceProvider,
                icon: Icons.cell_tower_rounded,
              ),
              DetailRow(
                label: 'Gateway IP',
                value: d.gateway,
                icon: Icons.alt_route_rounded,
                copyable: true,
              ),
            ],
          ),
          const SectionLabel('WIFI & SECURITY'),
          FintechGroupedCard(
            children: [
              DetailRow(
                label: 'WiFi Name',
                value: d.wifiName,
                icon: Icons.wifi_rounded,
                copyable: true,
              ),
              if (d.wifiPassword.isNotEmpty)
                _passwordRow(
                  label: 'WiFi Password',
                  value: d.wifiPassword,
                  show: _showWifi,
                  onToggle: () => setState(() => _showWifi = !_showWifi),
                  icon: Icons.lock_outline_rounded,
                  theme: theme,
                ),
              if (d.adminPassword.isNotEmpty)
                _passwordRow(
                  label: 'Admin Password',
                  value: d.adminPassword,
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
