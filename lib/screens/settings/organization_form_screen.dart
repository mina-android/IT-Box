import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/company_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../../widgets/common_widgets.dart';

class OrganizationFormScreen extends StatefulWidget {
  const OrganizationFormScreen({super.key});

  @override
  State<OrganizationFormScreen> createState() => _OrganizationFormScreenState();
}

class _OrganizationFormScreenState extends State<OrganizationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _nameCtrl = TextEditingController();

  String _logoPath = '';
  bool _switchImmediately = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final res = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (res.isNotEmpty && res.first.path != null) {
        final src = File(res.first.path!);
        final ext = res.first.extension ?? 'png';
        final dir = await getApplicationDocumentsDirectory();
        final dest = File(
          '${dir.path}/org_logo_${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
        await src.copy(dest.path);
        if (!mounted) {
          return;
        }
        setState(() => _logoPath = dest.path);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(context, 'Failed to pick logo: $e', error: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      AppHaptics.tap(context, HapticStrength.heavy);
      return;
    }

    setState(() => _saving = true);
    try {
      await CompanyService().createOrganization(
        name: _nameCtrl.text.trim(),
        logoPath: _logoPath,
        switchImmediately: _switchImmediately,
      );
      if (!mounted) {
        return;
      }
      AppHaptics.tap(context, HapticStrength.medium);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      showSnack(context, 'Failed to create organization: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: const FintechAppBar(
        title: 'New Organization',
        subtitle: 'Isolated database & identity',
      ),
      body: Form(
        key: _formKey,
        child: ShakeWidget(
          key: _shakeKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              const SectionLabel('ORGANIZATION IDENTITY'),
              FintechGroupedCard(
                title: 'Profile & Database',
                icon: Icons.corporate_fare_rounded,
                children: [
                  AppTextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Organization Name *',
                      hintText: 'e.g. Branch Alexandria, Client Co.',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Organization name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _logoPath.isNotEmpty && File(_logoPath).existsSync()
                            ? Image.file(File(_logoPath), fit: BoxFit.cover)
                            : Icon(
                                Icons.image_outlined,
                                color: cs.onSurface.withValues(alpha: 0.4),
                                size: 26,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Organization Logo (Optional)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Displayed on Home & PDF reports',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_logoPath.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          tooltip: 'Remove Logo',
                          onPressed: () => setState(() => _logoPath = ''),
                        ),
                      OutlinedButton.icon(
                        onPressed: _pickLogo,
                        icon: Icon(
                          _logoPath.isNotEmpty ? Icons.edit_outlined : Icons.upload_rounded,
                          size: 16,
                        ),
                        label: Text(_logoPath.isNotEmpty ? 'Change' : 'Upload'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionLabel('ACTIVATION'),
              FintechGroupedCard(
                title: 'Switch Behaviour',
                icon: Icons.swap_horiz_rounded,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: IconBox(
                      icon: Icons.bolt_rounded,
                      color: cs.primary,
                      size: 36,
                    ),
                    title: const Text(
                      'Switch Immediately',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Activate this organization now without losing existing data',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    value: _switchImmediately,
                    onChanged: (v) => setState(() => _switchImmediately = v),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  _saving ? 'Creating...' : 'Create Organization',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
