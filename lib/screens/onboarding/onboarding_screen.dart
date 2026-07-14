import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/company_service.dart';
import '../../database/database_helper.dart';
import '../../widgets/common_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = TextEditingController();
  final _key  = GlobalKey<FormState>();
  bool _saving = false;
  int _step = 0; // 0 = Choice (Fresh or Restore), 1 = Company Name Form

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _done() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    await CompanyService().completeOnboarding(_ctrl.text.trim());
    if (!mounted) return;
    widget.onDone();
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (result == null || result.files.isEmpty || !mounted) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        showSnack(context, 'Could not read file', error: true);
        return;
      }
      setState(() => _saving = true);
      await DatabaseHelper().importJson(utf8.decode(bytes));
      setState(() => _saving = false);
      if (!mounted) return;
      if (CompanyService().name.isNotEmpty) {
        showSnack(context, 'Backup restored successfully!');
        widget.onDone();
      } else {
        await CompanyService().completeOnboarding('IT Box');
        if (!mounted) return;
        showSnack(context, 'Backup restored successfully!');
        widget.onDone();
      }
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      showSnack(context, 'Restore failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: _step == 1
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = 0),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(Icons.inventory_2_outlined,
                        size: 52, color: theme.colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text('Welcome to IT Box',
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_step == 0
                  ? 'Your offline IT department inventory & operations hub'
                  : 'Enter your company name to get started',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 40),
              if (_step == 0) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : () => setState(() => _step = 1),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Start Fresh'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _restoreBackup,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.restore_outlined),
                    label: const Text('Restore Backup (.json)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ] else ...[
                Form(
                  key: _key,
                  child: TextFormField(
                    controller: _ctrl,
                    enableSuggestions: false,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Company Name *',
                      hintText: 'e.g. RADA Technology',
                      prefixIcon: Icon(Icons.business_outlined,
                          color: theme.colorScheme.primary),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Please enter your company name' : null,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _done,
                    icon: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_forward_outlined),
                    label: const Text('Get Started'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
