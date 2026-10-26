import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../database/database_helper.dart';
import '../../services/theme_service.dart';
import '../../services/company_service.dart';
import '../../services/workspace_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeService themeService;
  const SettingsScreen({super.key, required this.themeService});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper();
  Map<String, int> _counts = {};
  bool _loadingCounts = true;
  final _companyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.themeService.addListener(_onThemeChanged);
    _loadCounts();
    _companyCtrl.text = CompanyService().name;
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.themeService.removeListener(_onThemeChanged);
    _companyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    final c = await _db.getCounts();
    if (mounted) {
      setState(() {
        _counts = c;
        _loadingCounts = false;
      });
    }
  }

  Future<void> _saveCompany() async {
    await CompanyService().setCompanyName(_companyCtrl.text.trim());
    if (!mounted) {
      return;
    }
    showSnack(context, 'Company branding updated');
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
        final dest = File('${dir.path}/company_logo_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await src.copy(dest.path);
        await CompanyService().setCompanyLogo(dest.path);
        if (mounted) {
          setState(() {});
          showSnack(context, 'Company logo updated');
        }
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to pick logo: $e', error: true);
      }
    }
  }

  Future<void> _removeLogo() async {
    await CompanyService().removeCompanyLogo();
    if (mounted) {
      setState(() {});
      showSnack(context, 'Company logo removed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const FintechAppBar(
        title: 'System Settings',
        subtitle: 'Appearance, branding & preferences',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
        children: [
          if (!_loadingCounts) ...[
            const SectionLabel('CATALOG METRICS'),
            SizedBox(
              height: 94,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _StatMetricCard(icon: Icons.laptop_outlined, label: 'Laptops', count: _counts['laptops'] ?? 0, color: theme.colorScheme.primary),
                  _StatMetricCard(icon: Icons.router_outlined, label: 'Routers', count: _counts['network_devices'] ?? 0, color: AppColors.networkColor),
                  _StatMetricCard(icon: Icons.wifi_tethering_outlined, label: 'MiFis', count: _counts['mifis'] ?? 0, color: const Color(0xFF0EA5E9)),
                  _StatMetricCard(icon: Icons.cell_tower_outlined, label: 'APs', count: _counts['access_points'] ?? 0, color: const Color(0xFF0891B2)),
                  _StatMetricCard(icon: Icons.print_outlined, label: 'Printers', count: _counts['printers'] ?? 0, color: AppColors.printerColor),
                  _StatMetricCard(icon: Icons.devices_other_outlined, label: 'Electronics', count: _counts['electronics'] ?? 0, color: AppColors.electronicColor),
                  _StatMetricCard(icon: Icons.people_outline, label: 'Staff', count: _counts['employees'] ?? 0, color: const Color(0xFF0EA5E9)),
                  _StatMetricCard(icon: Icons.receipt_long_outlined, label: 'Expenses', count: _counts['expenses'] ?? 0, color: const Color(0xFF10B981)),
                  _StatMetricCard(icon: Icons.receipt_outlined, label: 'Bills', count: _counts['bills'] ?? 0, color: const Color(0xFF7C3AED)),
                  _StatMetricCard(icon: Icons.alternate_email_rounded, label: 'Emails', count: _counts['email_accounts'] ?? 0, color: const Color(0xFF0EA5E9)),
                  _StatMetricCard(icon: Icons.swap_horiz_outlined, label: 'Borrows', count: _counts['active_borrows'] ?? 0, color: AppColors.borrowed),
                  _StatMetricCard(icon: Icons.confirmation_number_outlined, label: 'Tickets', count: _counts['log_entries'] ?? 0, color: const Color(0xFF6366F1)),
                  _StatMetricCard(icon: Icons.subscriptions_outlined, label: 'Subs', count: _counts['subscriptions'] ?? 0, color: const Color(0xFFE11D48)),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          const SectionLabel('ACTIVE WORKSPACE / TENANT'),
          ListenableBuilder(
            listenable: WorkspaceService(),
            builder: (ctx, _) {
              final wsService = WorkspaceService();
              return FintechGroupedCard(
                title: 'Data Workspace Isolation',
                icon: Icons.workspaces_rounded,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: wsService.activeId,
                    decoration: const InputDecoration(
                      labelText: 'Current Database Workspace',
                      prefixIcon: Icon(Icons.corporate_fare_rounded),
                    ),
                    items: wsService.workspaces
                        .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                        .toList(),
                    onChanged: (val) async {
                      if (val != null) {
                        await wsService.switchWorkspace(val);
                        await _loadCounts();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ctrl = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('New Database Workspace'),
                          content: TextField(
                            controller: ctrl,
                            decoration: const InputDecoration(
                              labelText: 'Workspace / Branch Name',
                              hintText: 'e.g. Branch Alexandria',
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Create')),
                          ],
                        ),
                      );
                      if (ok == true && ctrl.text.trim().isNotEmpty) {
                        await wsService.createWorkspace(ctrl.text.trim());
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create New Workspace Branch'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const SectionLabel('ORGANIZATION & BRANDING'),
          FintechGroupedCard(
            title: 'Organization Identity',
            icon: Icons.business_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _companyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Company / Org Name',
                        prefixIcon: Icon(Icons.corporate_fare_rounded),
                        hintText: 'e.g. Acme Corp',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _saveCompany,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
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
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CompanyService().hasLogo
                        ? Image.file(
                            File(CompanyService().logoPath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded),
                          )
                        : Icon(
                            Icons.image_outlined,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            size: 26,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company Logo',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CompanyService().hasLogo
                              ? 'Appears on Home & Custody PDFs'
                              : 'Upload PNG/JPG logo for custody slips',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (CompanyService().hasLogo)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      tooltip: 'Remove Logo',
                      onPressed: _removeLogo,
                    ),
                  OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: Icon(CompanyService().hasLogo ? Icons.edit_outlined : Icons.upload_rounded, size: 16),
                    label: Text(CompanyService().hasLogo ? 'Change' : 'Upload'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          const SectionLabel('APPEARANCE & THEME'),
          FintechGroupedCard(
            title: 'Visual Theme',
            icon: Icons.palette_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ThemePill(
                      icon: Icons.brightness_auto_rounded,
                      label: 'System',
                      value: 'system',
                      selected: widget.themeService.themeMode,
                      onTap: () => widget.themeService.updateSetting('themeMode', 'system'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ThemePill(
                      icon: Icons.light_mode_rounded,
                      label: 'Light',
                      value: 'light',
                      selected: widget.themeService.themeMode,
                      onTap: () => widget.themeService.updateSetting('themeMode', 'light'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ThemePill(
                      icon: Icons.dark_mode_rounded,
                      label: 'Dark',
                      value: 'dark',
                      selected: widget.themeService.themeMode,
                      onTap: () => widget.themeService.updateSetting('themeMode', 'dark'),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const IconBox(icon: Icons.format_paint_outlined, color: Colors.indigo, size: 36),
                title: const Text('Dynamic System Color', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text('Derive color palette dynamically from your Android wallpaper', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                value: widget.themeService.dynamicColorEnabled,
                onChanged: (v) => widget.themeService.updateSetting('dynamicColorEnabled', v),
              ),
              if (widget.themeService.themeMode != 'light') ...[
                const Divider(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const IconBox(icon: Icons.contrast_rounded, color: Colors.blueGrey, size: 36),
                  title: const Text('True Black (AMOLED)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('Pure #000000 background for OLED efficiency', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                  value: widget.themeService.amoledSurfaces,
                  onChanged: (v) => widget.themeService.updateSetting('amoledSurfaces', v),
                ),
              ],
              if (!widget.themeService.dynamicColorEnabled) ...[
                const Divider(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.palette_outlined, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Accent Color', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              Text(
                                kSeedLabels[widget.themeService.themeSeed] ?? widget.themeService.themeSeed,
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: kSeedColors.entries.map((e) {
                          final sel = widget.themeService.themeSeed == e.key;
                          return GestureDetector(
                            onTap: () => widget.themeService.updateSetting('themeSeed', e.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: e.value,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: sel ? theme.colorScheme.onSurface : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: sel
                                    ? [
                                        BoxShadow(
                                          color: e.value.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),

          const SectionLabel('TYPOGRAPHY'),
          FintechGroupedCard(
            title: 'App Typography',
            icon: Icons.text_fields_rounded,
            children: [
              Row(
                children: [
                  Icon(Icons.text_fields_rounded, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('App Font', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(
                        kFonts[widget.themeService.appFont] ?? 'System Default',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kFonts.entries.map((e) {
                  final sel = widget.themeService.appFont == e.key;
                  final isDark = theme.brightness == Brightness.dark;
                  return GestureDetector(
                    onTap: () => widget.themeService.updateSetting('appFont', e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: sel
                              ? theme.colorScheme.primary
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06)),
                        ),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                          color: sel ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          const SectionLabel('APPLICATION INFO'),
          FintechGroupedCard(
            title: 'About IT Box',
            icon: Icons.info_outline_rounded,
            children: [
              const DetailRow(
                label: 'Software Version',
                value: 'v1.1.0',
                icon: Icons.verified_outlined,
              ),
              const DetailRow(
                label: 'Privacy Guarantee',
                value: '100% Offline • Zero Network Tracking',
                icon: Icons.security_outlined,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse('https://github.com/mina-android/IT-Box');
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.code_rounded, size: 18),
                      label: const Text('GitHub Repo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse('https://portfolio.minaashraf285.workers.dev');
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.person_outline_rounded, size: 18),
                      label: const Text('Developer'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _StatMetricCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 86,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String selected;
  final VoidCallback onTap;

  const _ThemePill({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sel = selected == value;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 54,
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: sel ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
