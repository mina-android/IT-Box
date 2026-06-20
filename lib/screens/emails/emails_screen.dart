import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/email_account.dart';
import '../../widgets/common_widgets.dart';
import 'email_form_screen.dart';

const _emailColor = Color(0xFF0EA5E9);

class EmailsScreen extends StatefulWidget {
  const EmailsScreen({super.key});
  @override
  State<EmailsScreen> createState() => _State();
}

class _State extends State<EmailsScreen> {
  final _db = DatabaseHelper();
  final _search = TextEditingController();
  List<EmailAccount> _all = [], _filtered = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _all = await _db.getEmailAccounts();
    _filter();
    if (mounted) setState(() => _loading = false);
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() => _filtered = q.isEmpty ? List.from(_all) : _all.where((e) =>
      e.email.toLowerCase().contains(q) ||
      e.employeeName.toLowerCase().contains(q)).toList());
  }

  Future<void> _openForm([EmailAccount? acc]) async {
    final ok = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => EmailFormScreen(account: acc)));
    if (ok == true && mounted) _load();
  }

  Future<void> _delete(EmailAccount acc) async {
    final ok = await showConfirmDialog(context, title: 'Delete Email Account',
      message: 'Delete "${acc.email}"?');
    if (!ok || !mounted) return;
    await _db.deleteEmailAccount(acc.id!);
    if (!mounted) return;
    showSnack(context, 'Email account deleted');
    _load();
  }

  void _showDetail(EmailAccount acc) {
    bool showPass = false;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const IconBox(icon: Icons.email_outlined, color: _emailColor, size: 50),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(acc.email, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                if (acc.employeeName.isNotEmpty)
                  Text(acc.employeeName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
              ])),
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () { Navigator.pop(ctx); _openForm(acc); }),
              IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), onPressed: () { Navigator.pop(ctx); _delete(acc); }),
            ]),
            const Divider(height: 28),
            Row(children: [
              const Icon(Icons.lock_outlined, size: 15, color: Colors.grey),
              const SizedBox(width: 6),
              const SizedBox(width: 90, child: Text('Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey))),
              Expanded(child: Text(showPass ? acc.password : '••••••••', style: const TextStyle(fontWeight: FontWeight.w500))),
              GestureDetector(onTap: () => setS(() => showPass = !showPass),
                child: Icon(showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: Colors.grey)),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emails'),
      ),
      body: Column(children: [
        SearchBar2(controller: _search, hint: 'Search email or employee...'),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
              ? EmptyState(icon: Icons.email_outlined, title: 'No Emails', subtitle: 'Tap + to add an email account')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final acc = _filtered[i];
                      return Card(
                        child: ListTile(
                          onTap: () => _showDetail(acc),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: const IconBox(icon: Icons.email_outlined, color: _emailColor),
                          title: Text(acc.email, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: acc.employeeName.isNotEmpty
                            ? Row(children: [
                                Icon(Icons.person_outline, size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                const SizedBox(width: 4),
                                Text(acc.employeeName, style: const TextStyle(fontSize: 12))])
                            : Text('No employee linked', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                          trailing: const Icon(Icons.key_outlined, color: Colors.grey, size: 18),
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
        label: const Text('Add Email'),
        backgroundColor: _emailColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
