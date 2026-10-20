import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/employee.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';

class EmployeeFormScreen extends StatefulWidget {
  final Employee? employee;
  const EmployeeFormScreen({super.key, this.employee});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;
  bool _logOnboarding = true;
  late final _name = TextEditingController(text: widget.employee?.name ?? '');
  late final _phone = TextEditingController(text: widget.employee?.phoneNumber ?? '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    setState(() => _saving = true);
    try {
      final e = Employee(
        id: widget.employee?.id,
        name: _name.text.trim(),
        phoneNumber: _phone.text.trim(),
      );
      if (widget.employee == null) {
        final newId = await _db.insertEmployee(e);
        if (_logOnboarding) {
          await _db.logAuditActivity(
            'ONBOARD',
            'Employee',
            entityId: newId,
            description: 'Onboarded new employee: ${e.name}',
          );
        }
      } else {
        await _db.updateEmployee(e);
      }
      if (!mounted) {
        return;
      }
      showSnack(context, widget.employee == null ? 'Employee created & onboarded' : 'Employee updated');
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee == null ? 'Add Employee' : 'Edit Employee'),
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
                widget.employee == null ? 'Create Employee Profile' : 'Save Changes',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
                title: 'Employee Profile',
                icon: Icons.badge_outlined,
                children: [
                  AppTextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.person_outline),
                      hintText: 'e.g. Sarah Jenkins',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: 'e.g. +20 100 123 4567',
                    ),
                  ),
                  if (widget.employee == null) ...[
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _logOnboarding,
                      onChanged: (v) => setState(() => _logOnboarding = v),
                      title: const Text('Log Onboarding in Audit Trail',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Record employee start & onboarding event in activity history',
                          style: TextStyle(fontSize: 11.5)),
                      secondary: const Icon(Icons.history_edu_rounded, color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
