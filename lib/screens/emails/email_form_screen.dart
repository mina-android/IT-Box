import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/email_account.dart';
import '../../models/employee.dart';
import '../../widgets/common_widgets.dart';

class EmailFormScreen extends StatefulWidget {
  final EmailAccount? account;
  const EmailFormScreen({super.key, this.account});
  @override
  State<EmailFormScreen> createState() => _State();
}

class _State extends State<EmailFormScreen> {
  final _key = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  bool _saving = false, _showPass = false;
  List<Employee> _employees = [];
  Employee? _selEmp;

  late final _email = TextEditingController(text: widget.account?.email ?? '');
  late final _pass  = TextEditingController(text: widget.account?.password ?? '');

  @override
  void initState() { super.initState(); _loadEmployees(); }

  Future<void> _loadEmployees() async {
    final emps = await _db.getEmployees();
    if (!mounted) return;
    setState(() {
      _employees = emps;
      if (widget.account?.employeeId != null) {
        try { _selEmp = emps.firstWhere((e) => e.id == widget.account!.employeeId); }
        catch (_) { _selEmp = null; }
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_email, _pass]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final acc = EmailAccount(
        id: widget.account?.id,
        employeeId: _selEmp?.id,
        employeeName: _selEmp?.name ?? '',
        email: _email.text.trim(),
        password: _pass.text,
      );
      if (widget.account == null) { await _db.insertEmailAccount(acc); }
      else { await _db.updateEmailAccount(acc); }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Error: $e', error: true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.account != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Email' : 'Add Email Account')),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          const SectionLabel('EMPLOYEE (OPTIONAL)'),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Employee',
              prefixIcon: Icon(Icons.person_outline)),
            child: DropdownButton<Employee?>(
              value: _selEmp,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: Text('None',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
              items: [
                const DropdownMenuItem<Employee?>(value: null, child: Text('None')),
                ..._employees.map((e) => DropdownMenuItem<Employee?>(value: e, child: Text(e.name))),
              ],
              onChanged: (v) => setState(() => _selEmp = v),
            ),
          ),
          const SectionLabel('CREDENTIALS'),
          Padding(padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              controller: _email,
              enableSuggestions: false, autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email Address *', prefixIcon: Icon(Icons.email_outlined), hintText: 'user@example.com'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              })),
          Padding(padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              controller: _pass,
              enableSuggestions: false, autocorrect: false,
              obscureText: !_showPass,
              decoration: InputDecoration(
                labelText: 'Password *',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showPass = !_showPass))),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
            label: Text(isEdit ? 'Update Email' : 'Add Email Account'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9))),
        ]),
      ),
    );
  }
}
