import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/company_service.dart';
import '../../database/database_helper.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = TextEditingController();
  final _key = GlobalKey<FormState>();
  bool _saving = false;
  int _step = 0; // 0 = Choice (Fresh or Restore), 1 = Company Name Form

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (!_key.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    await CompanyService().completeOnboarding(_ctrl.text.trim());
    if (!mounted) {
      return;
    }
    widget.onDone();
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
          type: FileType.custom, allowedExtensions: ['json']);
      if (result.isEmpty || !mounted) {
        return;
      }
      final picked = result.first;
      final rawStr = utf8.decode(await picked.readAsBytes());

      var summary = await DatabaseHelper().inspectBackupJson(rawStr);
      String? passphrase;

      if (summary.isEncrypted && !summary.isValid) {
        if (!mounted) return;
        final passCtrl = TextEditingController();
        final okPass = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Encrypted Backup Detected'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please enter the passphrase used to encrypt this backup:'),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Passphrase',
                    prefixIcon: Icon(Icons.lock_rounded),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unlock')),
            ],
          ),
        );
        if (okPass != true || !mounted) return;
        passphrase = passCtrl.text.trim();
        summary = await DatabaseHelper().inspectBackupJson(rawStr, passphrase: passphrase);
      }

      if (!mounted) return;
      if (!summary.isValid) {
        showSnack(context, summary.validationError ?? 'Invalid backup file.', error: true);
        return;
      }

      setState(() => _saving = true);
      await DatabaseHelper().importJson(rawStr, passphrase: passphrase);
      setState(() => _saving = false);
      if (!mounted) {
        return;
      }
      if (CompanyService().name.isNotEmpty) {
        showSnack(context, 'Backup restored successfully!');
        widget.onDone();
      } else {
        await CompanyService().completeOnboarding('IT Box');
        if (!mounted) {
          return;
        }
        showSnack(context, 'Backup restored successfully!');
        widget.onDone();
      }
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) {
        return;
      }
      showSnack(context, 'Restore failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: _step == 1
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _step = 0),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icon/app_icon_raw.png',
                  width: 92,
                  height: 92,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'IT Box',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  _step == 0
                      ? 'Local-first offline IT inventory, hardware tracking & department operations suite'
                      : 'Customize your IT Box deployment with your company or organization name',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                if (_step == 0) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : () => setState(() => _step = 1),
                            icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                            label: const Text('Setup New Workspace', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _restoreBackup,
                            icon: _saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.settings_backup_restore_rounded, size: 20),
                            label: const Text('Restore Backup (.json)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        '100% Offline • Zero Analytics • Zero Cloud',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  FintechGroupedCard(
                    title: 'Workspace Identity',
                    icon: Icons.corporate_fare_rounded,
                    children: [
                      Form(
                        key: _key,
                        child: AppTextField(
                          controller: _ctrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Company or Workspace Name *',
                            prefixIcon: Icon(Icons.business_outlined),
                            hintText: 'e.g. Innovatech Labs',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your organization name' : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _done,
                          icon: _saving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.arrow_forward_rounded, size: 20),
                          label: const Text('Launch IT Box', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
