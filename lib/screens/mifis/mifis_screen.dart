import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/mifi.dart';
import '../../widgets/common_widgets.dart';
import 'mifi_form_screen.dart';

const _mifiColor = Color(0xFF0EA5E9);

class MiFisScreen extends StatefulWidget {
  const MiFisScreen({super.key});
  @override
  State<MiFisScreen> createState() => _State();
}

class _State extends State<MiFisScreen> {
  final _db = DatabaseHelper();
  final _search = TextEditingController();
  List<MiFi> _all = [], _filtered = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _all = await _db.getMiFis();
    _filter();
    if (mounted) setState(() => _loading = false);
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() => _filtered = q.isEmpty ? List.from(_all) : _all.where((m) =>
      m.deviceNumber.toLowerCase().contains(q) ||
      m.model.toLowerCase().contains(q) ||
      m.wifiName.toLowerCase().contains(q) ||
      m.serviceProvider.toLowerCase().contains(q)).toList());
  }

  Future<void> _openForm([MiFi? m]) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => MiFiFormScreen(mifi: m)));
    if (ok == true && mounted) _load();
  }

  Future<void> _delete(MiFi m) async {
    final ok = await showConfirmDialog(context, title: 'Delete MiFi', message: 'Delete "${m.model}" (${m.deviceNumber})?');
    if (!ok || !mounted) return;
    await _db.deleteMiFi(m.id!);
    if (!mounted) return;
    showSnack(context, 'MiFi deleted');
    _load();
  }

  void _showDetail(MiFi m) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DetailSheet(mifi: m,
        onEdit: () { Navigator.pop(context); _openForm(m); },
        onDelete: () { Navigator.pop(context); _delete(m); }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(children: [
        SearchBar2(controller: _search, hint: 'Search model, number, WiFi name...'),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
              ? EmptyState(icon: Icons.router_outlined,
                  title: _search.text.isEmpty ? 'No MiFis' : 'No Results',
                  subtitle: _search.text.isEmpty ? 'Tap + to add a MiFi' : 'Try a different search')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final m = _filtered[i];
                      return Card(
                        child: ListTile(
                          onTap: () => _showDetail(m),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: const IconBox(icon: Icons.wifi_tethering_outlined, color: _mifiColor),
                          title: Text(m.model, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('# ${m.deviceNumber}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                            if (m.wifiName.isNotEmpty) Text('📶 ${m.wifiName}', style: const TextStyle(fontSize: 12)),
                          ]),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusBadge(m.status),
                              if (m.quota.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: _mifiColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                  child: Text(m.quota, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _mifiColor))),
                              ],
                            ],
                          ),
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
        label: const Text('Add MiFi'),
        backgroundColor: _mifiColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _DetailSheet extends StatefulWidget {
  final MiFi mifi;
  final VoidCallback onEdit, onDelete;
  const _DetailSheet({required this.mifi, required this.onEdit, required this.onDelete});
  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  bool _showWifi = false, _showAdmin = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.mifi;
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.65, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            const IconBox(icon: Icons.wifi_tethering_outlined, color: _mifiColor, size: 50),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.model, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              Text('# ${m.deviceNumber}', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13)),
            ])),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: widget.onEdit),
            IconButton(icon: Icon(Icons.delete_outline, color: theme.colorScheme.error), onPressed: widget.onDelete),
          ]),
          const Divider(height: 28),
          DetailRow(label: 'Phone No.', value: m.phoneNumber, icon: Icons.phone_outlined),
          DetailRow(label: 'Provider', value: m.serviceProvider, icon: Icons.cell_tower_outlined),
          DetailRow(label: 'Quota', value: m.quota, icon: Icons.data_usage_outlined),
          DetailRow(label: 'WiFi Name', value: m.wifiName, icon: Icons.wifi_outlined),
          if (m.wifiPassword.isNotEmpty)
            _passRow('WiFi Password', m.wifiPassword, _showWifi, () => setState(() => _showWifi = !_showWifi), Icons.lock_outlined, theme),
          DetailRow(label: 'Gateway', value: m.gateway, icon: Icons.router),
          if (m.adminPassword.isNotEmpty)
            _passRow('Admin Password', m.adminPassword, _showAdmin, () => setState(() => _showAdmin = !_showAdmin), Icons.admin_panel_settings_outlined, theme),
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
