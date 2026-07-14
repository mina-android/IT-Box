import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/access_point.dart';
import '../../widgets/common_widgets.dart';
import 'access_point_form_screen.dart';

class AccessPointsScreen extends StatefulWidget {
  const AccessPointsScreen({super.key});
  @override
  State<AccessPointsScreen> createState() => _State();
}

class _State extends State<AccessPointsScreen> {
  final _db = DatabaseHelper();
  final _search = TextEditingController();
  List<AccessPoint> _all = [], _filtered = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _all = await _db.getAccessPoints();
    _filter();
    if (mounted) setState(() => _loading = false);
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() => _filtered = q.isEmpty ? List.from(_all) : _all.where((d) =>
      d.deviceNumber.toLowerCase().contains(q) ||
      d.model.toLowerCase().contains(q) ||
      d.portNumber.toLowerCase().contains(q) ||
      d.location.toLowerCase().contains(q)).toList());
  }

  Future<void> _openForm([AccessPoint? d]) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AccessPointFormScreen(ap: d)));
    if (ok == true && mounted) _load();
  }

  Future<void> _delete(AccessPoint d) async {
    final ok = await showConfirmDialog(context, title: 'Delete Access Point', message: 'Delete "${d.model}"?');
    if (!ok || !mounted) return;
    await _db.deleteAccessPoint(d.id!);
    if (!mounted) return;
    showSnack(context, 'Access point deleted');
    _load();
  }

  void _showDetail(AccessPoint d) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const IconBox(icon: Icons.cell_tower_outlined, color: Color(0xFF0891B2), size: 50),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.model, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              Text('# ${d.deviceNumber}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            ])),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () { Navigator.pop(context); _openForm(d); }),
            IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), onPressed: () { Navigator.pop(context); _delete(d); }),
          ]),
          const Divider(height: 28),
          DetailRow(label: 'Device Number', value: d.deviceNumber, icon: Icons.tag),
          DetailRow(label: 'Model', value: d.model, icon: Icons.memory_outlined),
          DetailRow(label: 'Port Number', value: d.portNumber, icon: Icons.settings_ethernet_outlined),
          DetailRow(label: 'Location', value: d.location, icon: Icons.location_on_outlined),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(children: [
        SearchBar2(controller: _search, hint: 'Search device, model, port, location...'),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
              ? EmptyState(icon: Icons.cell_tower_outlined,
                  title: _search.text.isEmpty ? 'No Access Points' : 'No Results',
                  subtitle: _search.text.isEmpty ? 'Tap + to add an access point' : 'Try a different search')
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
                          leading: const IconBox(icon: Icons.cell_tower_outlined, color: Color(0xFF0891B2)),
                          title: Text(d.model, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('# ${d.deviceNumber}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                            if (d.portNumber.isNotEmpty) Text('Port: ${d.portNumber}', style: const TextStyle(fontSize: 12)),
                          ]),
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
        label: const Text('Add AP'),
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
      ),
    );
  }
}
