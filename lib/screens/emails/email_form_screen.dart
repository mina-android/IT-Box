import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/email_account.dart';
import '../../models/employee.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';

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
    final theme = Theme.of(context);
    final searchCtrl = TextEditingController();
    List<Employee> filtered = List.from(_employees);

    final selected = await showModalBottomSheet<Employee?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Assigned Employee',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search employee name or phone...',
                    prefixIcon: Icon(Icons.search_rounded),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onChanged: (q) {
                    final query = q.toLowerCase().trim();
                    setModalState(() {
                      filtered = _employees.where((e) {
                        return e.name.toLowerCase().contains(query) ||
                            e.phoneNumber.toLowerCase().contains(query);
                      }).toList();
                    });
                  },
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: IconBox(
                          icon: Icons.person_off_outlined,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          size: 36,
                        ),
                        title: const Text(
                          'None (Unassigned)',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                        ),
                        trailing: _selEmp == null
                            ? const Icon(Icons.check_circle_rounded, color: _emailColor)
                            : null,
                        onTap: () => Navigator.pop(ctx, null),
                      ),
                      const Divider(height: 1),
                      if (filtered.isEmpty && searchCtrl.text.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No matching employees found.',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      else
                        ...filtered.map((emp) {
                          final isSel = _selEmp?.id == emp.id;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: IconBox(
                                  icon: Icons.badge_outlined,
                                  color: isSel ? _emailColor : AppColors.employeeColor,
                                  size: 36,
                                ),
                                title: Text(
                                  emp.name,
                                  style: TextStyle(
                                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                ),
                                subtitle: emp.phoneNumber.isNotEmpty
                                    ? Text(emp.phoneNumber, style: const TextStyle(fontSize: 12))
                                    : null,
                                trailing: isSel
                                    ? const Icon(Icons.check_circle_rounded, color: _emailColor)
                                    : null,
                                onTap: () => Navigator.pop(ctx, emp),
                              ),
                              const Divider(height: 1),
                            ],
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // If modal dismissed with an employee or null
    setState(() => _selEmp = selected);
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
      final acc = EmailAccount(
        id: widget.account?.id,
        employeeId: _selEmp?.id,
        employeeName: _selEmp?.name ?? '',
        email: _email.text.trim(),
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Email Account' : 'New Email Account'),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
          ),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ),
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
            ],
          ),
        ),
      ),
    );
  }
}
