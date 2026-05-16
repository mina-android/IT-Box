import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/laptop.dart';
import '../../widgets/common_widgets.dart';
import 'laptop_form_screen.dart';

class LaptopsScreen extends StatefulWidget {
  const LaptopsScreen({super.key});
  @override
  State<LaptopsScreen> createState() => _LaptopsScreenState();
}

class _LaptopsScreenState extends State<LaptopsScreen> {
  final _db = DatabaseHelper();
  final _search = TextEditingController();
  List<Laptop> _all = [], _filtered = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _all = await _db.getLaptops();
    _filter();
    if (mounted) setState(() => _loading = false);
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() => _filtered = q.isEmpty ? List.from(_all) : _all.where((l) =>
      l.laptopNumber.toLowerCase().contains(q) ||
      l.model.toLowerCase().contains(q) ||
      l.user.toLowerCase().contains(q)).toList());
  }

  Future<void> _openForm([Laptop? laptop]) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => LaptopFormScreen(laptop: laptop)));
    if (ok == true && mounted) _load();
  }

  Future<void> _delete(Laptop l) async {
    final ok = await showConfirmDialog(context, title: 'Delete Laptop', message: 'Delete "${l.model}" (${l.laptopNumber})?');
    if (!ok || !mounted) return;
    await _db.deleteLaptop(l.id!);
    if (!mounted) return;
    showSnack(context, 'Laptop deleted');
    _load();
  }

  void _showDetail(Laptop l) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _LaptopDetailSheet(laptop: l,
        onEdit: () { Navigator.pop(context); _openForm(l); },
        onDelete: () { Navigator.pop(context); _delete(l); }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(children: [
        SearchBar2(controller: _search, hint: 'Search model, number, user...'),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
              ? EmptyState(icon: Icons.laptop_outlined,
                  title: _search.text.isEmpty ? 'No Laptops Yet' : 'No Results',
                  subtitle: _search.text.isEmpty ? 'Tap + to add a laptop' : 'Try a different search')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final l = _filtered[i];
                      return Card(
                        child: ListTile(
                          onTap: () => _showDetail(l),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: IconBox(icon: Icons.laptop_outlined, color: theme.colorScheme.primary),
                          title: Text(l.model, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('# ${l.laptopNumber}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
                            if (l.user.isNotEmpty) Text(l.user, style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                          ]),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            ConditionBadge(l.condition),
                            if (l.ram.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(l.ram, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                            ],
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
        label: const Text('Add Laptop'),
      ),
    );
  }
}

class _LaptopDetailSheet extends StatefulWidget {
  final Laptop laptop; final VoidCallback onEdit, onDelete;
  const _LaptopDetailSheet({required this.laptop, required this.onEdit, required this.onDelete});
  @override
  State<_LaptopDetailSheet> createState() => _LaptopDetailSheetState();
}

class _LaptopDetailSheetState extends State<_LaptopDetailSheet> {
  bool _showPass = false;
  @override
  Widget build(BuildContext context) {
    final l = widget.laptop; final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.55, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            IconBox(icon: Icons.laptop_outlined, color: theme.colorScheme.primary, size: 50),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.model, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              Text('# ${l.laptopNumber}', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13)),
            ])),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: widget.onEdit),
            IconButton(icon: Icon(Icons.delete_outline, color: theme.colorScheme.error), onPressed: widget.onDelete),
          ]),
          const Divider(height: 28),
          DetailRow(label: 'CPU', value: l.cpu, icon: Icons.memory_outlined),
          DetailRow(label: 'GPU', value: l.gpu, icon: Icons.videogame_asset_outlined),
          DetailRow(label: 'RAM', value: l.ram, icon: Icons.storage_outlined),
          DetailRow(label: 'Storage', value: l.storage, icon: Icons.disc_full_outlined),
          DetailRow(label: 'Condition', value: l.condition, icon: Icons.health_and_safety_outlined),
          DetailRow(label: 'User', value: l.user, icon: Icons.person_outline),
          if (l.password.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                const Icon(Icons.lock_outline, size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                const SizedBox(width: 94, child: Text('Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey))),
                Expanded(child: Text(_showPass ? l.password : '••••••••', style: const TextStyle(fontWeight: FontWeight.w500))),
                GestureDetector(onTap: () => setState(() => _showPass = !_showPass),
                  child: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: Colors.grey)),
              ]),
            ),
        ]),
      ),
    );
  }
}
