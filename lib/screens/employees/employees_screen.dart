import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/employee.dart';
import '../../widgets/common_widgets.dart';
import 'employee_form_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _State();
}

class _State extends State<EmployeesScreen> {
  final _db = DatabaseHelper();
  final _search = TextEditingController();
  List<Employee> _all = [], _filtered = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _all = await _db.getEmployees();
    _filter();
    if (mounted) setState(() => _loading = false);
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() => _filtered = q.isEmpty ? List.from(_all) : _all.where((e) =>
      e.name.toLowerCase().contains(q) || e.phoneNumber.contains(q)).toList());
  }

  Future<void> _openForm([Employee? e]) async {
    final ok = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => EmployeeFormScreen(employee: e)));
    if (ok == true && mounted) _load();
  }

  Future<void> _delete(Employee e) async {
    final ok = await showConfirmDialog(context,
      title: 'Delete Employee', message: 'Delete "${e.name}"?');
    if (!ok || !mounted) return;
    await _db.deleteEmployee(e.id!);
    if (!mounted) return;
    showSnack(context, 'Employee deleted');
    _load();
  }

  String _initials(String n) => n.trim().split(' ')
    .where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
      ),
      body: Column(children: [
        SearchBar2(controller: _search, hint: 'Search by name or phone...'),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline,
                  title: _search.text.isEmpty ? 'No Employees' : 'No Results',
                  subtitle: _search.text.isEmpty
                    ? 'Tap + to add an employee' : 'Try a different search')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final e = _filtered[i];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                            child: Text(_initials(e.name),
                              style: TextStyle(fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary, fontSize: 14))),
                          title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: e.phoneNumber.isNotEmpty
                            ? Row(children: [
                                Icon(Icons.phone_outlined, size: 13,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                const SizedBox(width: 4),
                                Text(e.phoneNumber, style: const TextStyle(fontSize: 12))])
                            : null,
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _openForm(e)),
                            IconButton(icon: Icon(Icons.delete_outline, size: 20,
                              color: theme.colorScheme.error), onPressed: () => _delete(e)),
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
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Employee'),
      ),
    );
  }
}
