import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/electronic.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import 'electronic_form_screen.dart';

class ElectronicsScreen extends StatefulWidget {
  const ElectronicsScreen({super.key});
  @override
  State<ElectronicsScreen> createState() => _State();
}

class _State extends State<ElectronicsScreen> {
  final _db = DatabaseHelper();
  final _search = TextEditingController();
  List<Electronic> _all = [], _filtered = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _all = await _db.getElectronics();
    _filter();
    if (mounted) setState(() => _loading = false);
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() => _filtered = q.isEmpty ? List.from(_all) : _all.where((e) =>
      e.deviceNumber.toLowerCase().contains(q) ||
      e.deviceName.toLowerCase().contains(q) ||
      e.details.toLowerCase().contains(q)).toList());
  }

  Future<void> _openForm([Electronic? e]) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ElectronicFormScreen(electronic: e)));
    if (ok == true && mounted) _load();
  }

  Future<void> _delete(Electronic e) async {
    final ok = await showConfirmDialog(context, title: 'Delete Device', message: 'Delete "${e.deviceName}"?');
    if (!ok || !mounted) return;
    await _db.deleteElectronic(e.id!);
    if (!mounted) return;
    showSnack(context, 'Device deleted');
    _load();
  }

  void _showDetail(Electronic e) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const IconBox(icon: Icons.devices_other_outlined, color: AppColors.electronicColor, size: 50),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.deviceName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              Text('# ${e.deviceNumber}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            ])),
            StatusBadge(e.status),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () { Navigator.pop(context); _openForm(e); }),
            IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), onPressed: () { Navigator.pop(context); _delete(e); }),
          ]),
          const Divider(height: 28),
          if (e.details.isNotEmpty) DetailRow(label: 'Details', value: e.details, icon: Icons.info_outline),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(children: [
        SearchBar2(controller: _search, hint: 'Search device name or number...'),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
              ? EmptyState(icon: Icons.devices_other_outlined,
                  title: _search.text.isEmpty ? 'No Electronics' : 'No Results',
                  subtitle: _search.text.isEmpty ? 'Tap + to add a device' : 'Try a different search')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final e = _filtered[i];
                      return Card(
                        child: ListTile(
                          onTap: () => _showDetail(e),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: const IconBox(icon: Icons.devices_other_outlined, color: AppColors.electronicColor),
                          title: Text(e.deviceName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('# ${e.deviceNumber}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                            if (e.details.isNotEmpty) Text(e.details, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          ]),
                          trailing: StatusBadge(e.status),
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
        backgroundColor: AppColors.electronicColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
