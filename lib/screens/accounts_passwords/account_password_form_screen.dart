// lib/screens/accounts_passwords/account_password_form_screen.dart
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/account_password.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../../widgets/common_widgets.dart';

class AccountPasswordFormScreen extends StatefulWidget {
  final AccountPassword? account;
  const AccountPasswordFormScreen({super.key, this.account});

  @override
  State<AccountPasswordFormScreen> createState() => _AccountPasswordFormScreenState();
}

class _AccountPasswordFormScreenState extends State<AccountPasswordFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;
  bool _obscurePassword = true;

  late final TextEditingController _platformCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;

  @override
  void initState() {
    super.initState();
    _platformCtrl = TextEditingController(text: widget.account?.platform ?? '');
    _emailCtrl = TextEditingController(text: widget.account?.emailUsername ?? '');
    _passCtrl = TextEditingController(text: widget.account?.password ?? '');
  }

  @override
  void dispose() {
    _platformCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      AppHaptics.tap(context, HapticStrength.heavy);
      return;
    }
    setState(() => _saving = true);
    AppHaptics.tap(context, HapticStrength.medium);

    try {
      final item = AccountPassword(
        id: widget.account?.id,
        platform: _platformCtrl.text.trim(),
        emailUsername: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      if (widget.account == null) {
        final id = await _db.insertAccountPassword(item);
        await _db.logAuditActivity(
          'CREATE',
          'AccountPassword',
          entityId: id,
          description: 'Added credentials for ${item.platform} (${item.emailUsername})',
        );
      } else {
        await _db.updateAccountPassword(item);
        await _db.logAuditActivity(
          'UPDATE',
          'AccountPassword',
          entityId: item.id,
          description: 'Updated credentials for ${item.platform} (${item.emailUsername})',
        );
      }

      if (!mounted) return;
      showSnack(context, 'Account credentials saved successfully');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Error saving credentials: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.account != null;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: FintechAppBar(
        title: isEdit ? 'Edit Credentials' : 'Add Platform Account',
        subtitle: isEdit ? 'Update platform login details' : 'Store offline account credentials',
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ShakeWidget(
          key: _shakeKey,
          child: Form(
            key: _key,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
              children: [
                const SectionLabel('CREDENTIAL DETAILS'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _platformCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Platform / Service *',
                        prefixIcon: Icon(Icons.apps_rounded, size: 20),
                        hintText: 'e.g. AWS, Cloudflare, Google Cloud, Figma',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Platform name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email / Username *',
                        prefixIcon: Icon(Icons.account_circle_outlined, size: 20),
                        hintText: 'admin@company.com or sysadmin',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Email or username is required' : null,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _passCtrl,
                      obscureText: _obscurePassword,
                      style: credentialFont(fontSize: 15, color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        hintText: 'Account credentials passphrase',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Password is required' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    isEdit ? 'Save Changes' : 'Save Account Credentials',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
