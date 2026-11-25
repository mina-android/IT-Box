import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/email_account.dart';
import '../../models/employee.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';

const _emailColor = Color(0xFF0EA5E9);

class EmailFormScreen extends StatefulWidget {
  final EmailAccount? account;
  const EmailFormScreen({super.key, this.account});

  @override
  State<EmailFormScreen> createState() => _EmailFormScreenState();
}

class _EmailFormScreenState extends State<EmailFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;
  bool _showPass = false;
  List<Employee> _employees = [];
  Employee? _selEmp;

  late final _email = TextEditingController(text: widget.account?.email ?? '');
  late final _pass = TextEditingController(text: widget.account?.password ?? '');

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final emps = await _db.getEmployees();
    if (!mounted) {
      return;
    }
    setState(() {
      _employees = emps;
      if (widget.account?.employeeId != null) {
        try {
          _selEmp = emps.firstWhere((e) => e.id == widget.account!.employeeId);
        } catch (_) {
          _selEmp = null;
        }
      }
    });
  }

  Future<void> _openEmployeePicker() async {
    final picked = await showFintechEmployeePicker(
      context: context,
      employees: _employees,
      selectedEmployeeId: _selEmp?.id,
      title: 'Select Assigned Employee',
      allowNone: true,
      accentColor: _emailColor,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selEmp = picked.cleared ? null : picked.employee;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    setState(() => _saving = true);
    try {
      final emailStr = _email.text.trim();
      final allAccounts = await _db.getEmailAccounts();
      final duplicate = allAccounts.any((acc) =>
          acc.id != widget.account?.id &&
          acc.email.trim().toLowerCase() == emailStr.toLowerCase());
      if (duplicate) {
        if (!mounted) return;
        _shakeKey.currentState?.shake();
        AppHaptics.tap(context, HapticStrength.heavy);
        showSnack(context, 'Email "$emailStr" is already registered.', error: true);
        setState(() => _saving = false);
        return;
      }

      final acc = EmailAccount(
        id: widget.account?.id,
        employeeId: _selEmp?.id,
        employeeName: _selEmp?.name ?? '',
        email: emailStr,
        password: _pass.text,
      );
      if (widget.account == null) {
        await _db.insertEmailAccount(acc);
      } else {
        await _db.updateEmailAccount(acc);
      }
      if (!mounted) {
        return;
      }
      showSnack(context, widget.account == null ? 'Account created' : 'Account updated');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(context, 'Error: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.account != null;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: FintechAppBar(
        title: isEdit ? 'Edit Email Account' : 'New Email Account',
      ),
      body: ShakeWidget(
        key: _shakeKey,
        child: Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          key: _key,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              FintechGroupedCard(
                title: 'Account Credentials',
                icon: Icons.vpn_key_outlined,
                children: [
                  AppTextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: credentialFont(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Email Address *',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                      hintText: 'user@company.com',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Required';
                      }
                      if (!v.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _pass,
                    obscureText: !_showPass,
                    style: credentialFont(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      hintText: 'Enter account password',
                      suffixIcon: IconButton(
                        icon: Icon(_showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                        onPressed: () => setState(() => _showPass = !_showPass),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FintechGroupedCard(
                title: 'User Assignment',
                icon: Icons.person_outline_rounded,
                children: [
                  InkWell(
                    onTap: _openEmployeePicker,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Assigned Employee (Optional)',
                        prefixIcon: Icon(Icons.badge_outlined),
                        suffixIcon: Icon(Icons.search_rounded, size: 20),
                      ),
                      child: Text(
                        _selEmp != null
                            ? (_selEmp!.phoneNumber.isNotEmpty
                                ? '${_selEmp!.name} (${_selEmp!.phoneNumber})'
                                : _selEmp!.name)
                            : 'None (Unassigned) — Tap to search',
                        style: TextStyle(
                          fontWeight: _selEmp != null ? FontWeight.w700 : FontWeight.normal,
                          color: _selEmp != null
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  isEdit ? 'Save Changes' : 'Create Email Account',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emailColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
