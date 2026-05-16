import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/printer.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import 'printer_form_screen.dart';

class PrintersScreen extends StatefulWidget {
  const PrintersScreen({super.key});
  @override
  State<PrintersScreen> createState() => _State();
}

class _State extends State<PrintersScreen> {
  final _db = DatabaseHelper();
  final _search = TextEditingController();
  List<Printer> _all = [], _filtered = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _all = await _db.getPrinters();
    _filter();
    if (mounted) setState(() => _loading = false);
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() => _filtered = q.isEmpty ? List.from(_all) : _all.where((p) =>
      p.printerNumber.toLowerCase().contains(q) ||
      p.model.toLowerCase().contains(q) ||
      p.location.toLowerCase().contains(q)).toList());
  }

  Future<void> _openForm([Printer? p]) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PrinterFormScreen(printer: p)));
    if (ok == true && mounted) _load();
  }

  Future<void> _delete(Printer p) async {
    final ok = await showConfirmDialog(context, title: 'Delete Printer', message: 'Delete "${p.model}"?');
    if (!ok || !mounted) return;
    await _db.deletePrinter(p.id!);
    if (!mounted) return;
    showSnack(context, 'Printer deleted');
    _load();
  }

  void _showDetail(Printer p) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const IconBox(icon: Icons.print_outlined, color: AppColors.printerColor, size: 50),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.model, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              Text('# ${p.printerNumber}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            ])),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () { Navigator.pop(context); _openForm(p); }),
            IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), onPressed: () { Navigator.pop(context); _delete(p); }),
          ]),
          const Divider(height: 28),
          DetailRow(label: 'Condition', value: p.condition, icon: Icons.health_and_safety_outlined),
          DetailRow(label: 'Location', value: p.location, icon: Icons.location_on_outlined),
        ]),
      ),
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
              ? EmptyState(icon: Icons.print_outlined,
                  title: _search.text.isEmpty ? 'No Printers' : 'No Results',
                  subtitle: _search.text.isEmpty ? 'Tap + to add a printer' : 'Try a different search')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final p = _filtered[i];
                      return Card(
                        child: ListTile(
                          onTap: () => _showDetail(p),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: const IconBox(icon: Icons.print_outlined, color: AppColors.printerColor),
                          title: Text(p.model, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('# ${p.printerNumber}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                            if (p.location.isNotEmpty) Text(p.location, style: const TextStyle(fontSize: 12)),
                          ]),
                          trailing: ConditionBadge(p.condition),
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
        label: const Text('Add Printer'),
        backgroundColor: AppColors.printerColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
