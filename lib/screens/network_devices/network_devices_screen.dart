import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/network_device.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import 'network_device_form_screen.dart';

class NetworkDevicesScreen extends StatefulWidget {
  const NetworkDevicesScreen({super.key});
  @override
  State<NetworkDevicesScreen> createState() => _State();
}

class _State extends State<NetworkDevicesScreen> {
  final _db = DatabaseHelper();
  final _search = TextEditingController();
  List<NetworkDevice> _all = [], _filtered = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _all = await _db.getNetworkDevices();
    _filter();
    if (mounted) setState(() => _loading = false);
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() => _filtered = q.isEmpty ? List.from(_all) : _all.where((d) =>
      d.deviceNumber.toLowerCase().contains(q) ||
      d.model.toLowerCase().contains(q) ||
      d.deviceLocation.toLowerCase().contains(q) ||
      d.wifiName.toLowerCase().contains(q)).toList());
  }

  Future<void> _openForm([NetworkDevice? d]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => NetworkDeviceFormScreen(device: d)));
    if (saved == true && mounted) _load();
  }

  Future<void> _delete(NetworkDevice d) async {
    final ok = await showConfirmDialog(context, title: 'Delete Device', message: 'Delete "${d.model}" (${d.deviceNumber})?');
    if (!ok || !mounted) return;
    await _db.deleteNetworkDevice(d.id!);
    if (!mounted) return;
    showSnack(context, 'Device deleted');
    _load();
  }

  void _showDetail(NetworkDevice d) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DetailSheet(device: d,
        onEdit: () { Navigator.pop(context); _openForm(d); },
        onDelete: () { Navigator.pop(context); _delete(d); }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(children: [
        SearchBar2(controller: _search, hint: 'Search model, number, location...'),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
              ? EmptyState(icon: Icons.router_outlined,
                  title: _search.text.isEmpty ? 'No Network Devices' : 'No Results',
                  subtitle: _search.text.isEmpty ? 'Tap + to add a device' : 'Try a different search')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final d = _filtered[i];
                      return Card(
                        child: ListTile(
                          onTap: () => _showDetail(d),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: const IconBox(icon: Icons.router_outlined, color: AppColors.networkColor),
                          title: Text(d.model, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('# ${d.deviceNumber}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                            if (d.phoneNumber.isNotEmpty) Text(d.phoneNumber, style: const TextStyle(fontSize: 12)),
                          ]),
                          trailing: StatusBadge(d.status),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
        backgroundColor: AppColors.networkColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _DetailSheet extends StatefulWidget {
  final NetworkDevice device;
  final VoidCallback onEdit, onDelete;
  const _DetailSheet({required this.device, required this.onEdit, required this.onDelete});
  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  bool _showWifi = false, _showAdmin = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            const IconBox(icon: Icons.router_outlined, color: AppColors.networkColor, size: 50),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.model, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              Text('# ${d.deviceNumber}', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13)),
            ])),
            StatusBadge(d.status),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: widget.onEdit),
            IconButton(icon: Icon(Icons.delete_outline, color: theme.colorScheme.error), onPressed: widget.onDelete),
          ]),
          const Divider(height: 28),
          DetailRow(label: 'Phone No.', value: d.phoneNumber, icon: Icons.phone_outlined),
          DetailRow(label: 'Location', value: d.deviceLocation, icon: Icons.location_on_outlined),
          DetailRow(label: 'Provider', value: d.serviceProvider, icon: Icons.cell_tower_outlined),
          DetailRow(label: 'WiFi Name', value: d.wifiName, icon: Icons.wifi_outlined),
          if (d.wifiPassword.isNotEmpty)
            _passRow('WiFi Password', d.wifiPassword, _showWifi, () => setState(() => _showWifi = !_showWifi), Icons.lock_outlined, theme),
          DetailRow(label: 'Gateway', value: d.gateway, icon: Icons.router),
          if (d.adminPassword.isNotEmpty)
            _passRow('Admin Password', d.adminPassword, _showAdmin, () => setState(() => _showAdmin = !_showAdmin), Icons.admin_panel_settings_outlined, theme),
        ]),
      ),
    );
  }

  Widget _passRow(String label, String value, bool show, VoidCallback toggle, IconData icon, ThemeData theme) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 15, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))),
        Expanded(child: Text(show ? value : '••••••••', style: const TextStyle(fontWeight: FontWeight.w500))),
        GestureDetector(onTap: toggle, child: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: Colors.grey)),
      ]),
    );
}
