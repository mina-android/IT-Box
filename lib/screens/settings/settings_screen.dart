import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../database/database_helper.dart';
import '../../services/theme_service.dart';
import '../../services/company_service.dart';
import '../../services/currency_service.dart';
import '../../services/ticket_reminder_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import 'organization_form_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeService themeService;
  const SettingsScreen({super.key, required this.themeService});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper();
  StreamSubscription<Map<String, int>>? _countsSub;
  Map<String, int> _counts = {};
  bool _loadingCounts = true;
  String _appVersion = 'v1.2.0+7';
  final _companyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.themeService.addListener(_onThemeChanged);
    _countsSub = _db.watchCounts().listen((c) {
      if (mounted) {
        setState(() {
          _counts = c;
          _loadingCounts = false;
        });
      }
    });
    _loadAppVersion();
    _companyCtrl.text = CompanyService().name;
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted && info.version.isNotEmpty) {
        setState(() => _appVersion = 'v${info.version}+${info.buildNumber}');
      }
    } catch (_) {}
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
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

  @override
  void dispose() {
    _countsSub?.cancel();
    widget.themeService.removeListener(_onThemeChanged);
    _companyCtrl.dispose();
    super.dispose();
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
        final safeOrg = CompanyService().activeOrganizationId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final oldPath = CompanyService().logoPath;
        final dest = File('${dir.path}/company_logo_${safeOrg}_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await src.copy(dest.path);
        await CompanyService().setCompanyLogo(dest.path);
        if (oldPath.isNotEmpty && oldPath != dest.path) {
          final oldFile = File(oldPath);
          if (await oldFile.exists()) {
            try {
              await oldFile.delete();
            } catch (_) {}
          }
        }
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

  Future<void> _switchOrganization(String orgId) async {
    await CompanyService().switchOrganization(orgId);
    if (!mounted) {
      return;
    }
    _companyCtrl.text = CompanyService().name;
    await _loadCounts();
    if (!mounted) {
      return;
    }
    showSnack(context, 'Switched to ${CompanyService().name}');
  }

  Future<void> _openAddOrganization() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const OrganizationFormScreen()),
    );
    if (created == true && mounted) {
      _companyCtrl.text = CompanyService().name;
      await _loadCounts();
    }
  }

  Future<void> _deleteActiveOrganization() async {
    final company = CompanyService();
    final target = company.activeOrganization;
    if (target.id == 'default' || company.organizations.length <= 1) {
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Organization?',
      message:
          'This will permanently delete "${target.name}" and its isolated database. Other organizations will not be affected.',
      confirmText: 'Delete',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final deleted = await company.deleteOrganization(target.id);
    if (!mounted) {
      return;
    }
    if (deleted) {
      _companyCtrl.text = company.name;
      await _loadCounts();
      if (!mounted) {
        return;
      }
      showSnack(context, 'Deleted "${target.name}"');
    }
  }

  Future<void> _pickCurrency() async {
    final cs = CurrencyService();
    final oldCode = cs.currency;
    final picked = await showCurrencyPicker(context, current: oldCode);
    if (picked == null || picked == oldCode || !mounted) {
      return;
    }

    final factor = cs.convertBetween(1.0, oldCode, picked);
    bool shouldConvert = false;

    if (factor != null && factor > 0) {
      final choice = await showDialog<String>(
        context: context,
        builder: (dCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Convert Existing Amounts?', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text(
            'Do you want to convert existing Expenses, Bills, Subscriptions, and Maintenance costs from $oldCode to $picked?\n\n'
            'Rate: 1 $oldCode ≈ ${factor.toStringAsFixed(4)} $picked',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, 'cancel'),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(dCtx, 'symbol_only'),
              child: const Text('Symbol Only'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, 'convert'),
              child: const Text('Convert Amounts'),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'cancel' || !mounted) {
        return;
      }
      shouldConvert = choice == 'convert';
    }

    if (shouldConvert && factor != null) {
      await _db.convertAllFinancialAmounts(factor);
    }
    await cs.setCurrency(picked);
    if (!mounted) {
      return;
    }
    showSnack(
      context,
      shouldConvert
          ? 'Currency switched to $picked and financial records converted'
          : 'Currency switched to $picked',
    );
  }

  Future<void> _addTicketReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Enter Reminder Time',
    );
    if (picked == null || !mounted) {
      return;
    }
    final added = await TicketReminderService().addTime(picked);
    if (!mounted) {
      return;
    }
    if (!added) {
      showSnack(context, 'That reminder time is already added', error: true);
    } else {
      showSnack(context, 'Added reminder at ${picked.format(context)}');
    }
  }

  String _formatReminderSummary(TicketReminderService svc) {
    if (!svc.enabled) {
      return 'Reminders are currently paused';
    }
    if (svc.days.isEmpty || svc.times.isEmpty) {
      return 'Select at least one day and one time to activate';
    }
    const dayLabels = {
      DateTime.sunday: 'Sun',
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
    };
    final activeDays = svc.days.map((d) => dayLabels[d] ?? '').where((s) => s.isNotEmpty).join(', ');
    final count = svc.times.length;
    return 'Active on $activeDays • $count ${count == 1 ? 'reminder' : 'reminders'}/day';
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
                  _StatMetricCard(icon: Icons.devices_outlined, label: 'Others', count: _counts['other_devices'] ?? 0, color: const Color(0xFF0D9488)),
                  _StatMetricCard(icon: Icons.wifi_password_rounded, label: 'Wi-Fi', count: _counts['wifi_networks'] ?? 0, color: const Color(0xFF059669)),
                  _StatMetricCard(icon: Icons.vpn_key_outlined, label: 'Vault', count: _counts['account_passwords'] ?? 0, color: const Color(0xFFF59E0B)),
                  _StatMetricCard(icon: Icons.contact_phone_outlined, label: 'Vendors', count: _counts['vendor_contacts'] ?? 0, color: AppColors.vendorColor),
                  _StatMetricCard(icon: Icons.assignment_turned_in_outlined, label: 'Custody', count: _counts['custody_documents'] ?? 0, color: const Color(0xFF6366F1)),
                  _StatMetricCard(icon: Icons.document_scanner_outlined, label: 'Docs', count: _counts['vault_documents'] ?? 0, color: const Color(0xFF0EA5E9)),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          const SectionLabel('ORGANIZATION & BRANDING'),
          ListenableBuilder(
            listenable: CompanyService(),
            builder: (ctx, _) {
              final company = CompanyService();
              return FintechGroupedCard(
                title: 'Organization Identity',
                icon: Icons.business_outlined,
                children: [
                  FintechDropdown<String>(
                    labelText: 'Active Organization',
                    prefixIcon: const Icon(Icons.corporate_fare_rounded),
                    value: company.activeOrganizationId,
                    items: company.organizations
                        .map((o) => DropdownMenuItem(value: o.id, child: Text(o.name)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        _switchOrganization(val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openAddOrganization,
                          icon: const Icon(Icons.add_business_rounded, size: 18),
                          label: const Text('Add New Organization'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      if (company.activeOrganizationId != 'default' &&
                          company.organizations.length > 1) ...[
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _deleteActiveOrganization,
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          label: Text(
                            'Delete',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: theme.colorScheme.error.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _companyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Organization Name',
                            prefixIcon: Icon(Icons.edit_outlined),
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
                        child: company.hasLogo
                            ? Image.file(
                                File(company.logoPath),
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
                              'Organization Logo',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              company.hasLogo
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
                      if (company.hasLogo)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          tooltip: 'Remove Logo',
                          onPressed: _removeLogo,
                        ),
                      OutlinedButton.icon(
                        onPressed: _pickLogo,
                        icon: Icon(company.hasLogo ? Icons.edit_outlined : Icons.upload_rounded, size: 16),
                        label: Text(company.hasLogo ? 'Change' : 'Upload'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          const SectionLabel('CURRENCY & EXCHANGE RATES'),
          ListenableBuilder(
            listenable: CurrencyService(),
            builder: (ctx, _) {
              final curService = CurrencyService();
              final info = curService.info;
              final usdRate = curService.convertBetween(1.0, 'USD', info.code);
              final rateText = curService.ratesFetching
                  ? 'Updating live exchange rates...'
                  : (usdRate != null
                      ? '1 USD = ${usdRate.toStringAsFixed(2)} ${info.code} • ${curService.ratesLoaded ? 'Live cached' : 'Offline fallback'}'
                      : 'Offline fallback rates active');

              return FintechGroupedCard(
                title: 'App Currency',
                icon: Icons.currency_exchange_rounded,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconBox(
                      icon: Icons.monetization_on_outlined,
                      color: theme.colorScheme.primary,
                      size: 40,
                    ),
                    title: const Text(
                      'Default Currency',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${info.name} (${info.code} • ${info.symbol})',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _pickCurrency,
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Icon(
                        curService.ratesLoaded ? Icons.cloud_done_outlined : Icons.offline_bolt_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rateText,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: curService.ratesFetching ? null : () => curService.refreshRates(),
                        icon: curService.ratesFetching
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          const SectionLabel('TICKET LOGGING REMINDERS'),
          ListenableBuilder(
            listenable: TicketReminderService(),
            builder: (ctx, _) {
              final svc = TicketReminderService();
              const weekdays = [
                (DateTime.sunday, 'Sun'),
                (DateTime.monday, 'Mon'),
                (DateTime.tuesday, 'Tue'),
                (DateTime.wednesday, 'Wed'),
                (DateTime.thursday, 'Thu'),
                (DateTime.friday, 'Fri'),
                (DateTime.saturday, 'Sat'),
              ];

              return FintechGroupedCard(
                title: 'Ticket Reminders',
                icon: Icons.notifications_active_outlined,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: IconBox(
                      icon: Icons.confirmation_number_outlined,
                      color: theme.colorScheme.primary,
                      size: 36,
                    ),
                    title: const Text(
                      'Enable Ticket Reminders',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Notify to log IT support tickets on chosen days & times',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    value: svc.enabled,
                    onChanged: (v) => svc.setEnabled(v),
                  ),
                  const Divider(height: 18),
                  Text(
                    'Reminder Days',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: weekdays.map((entry) {
                      final isSelected = svc.days.contains(entry.$1);
                      return FintechFilterPill(
                        label: entry.$2,
                        selected: isSelected,
                        onTap: () => svc.toggleDay(entry.$1),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Clock Times (${svc.times.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addTicketReminderTime,
                        icon: const Icon(Icons.add_alarm_rounded, size: 17),
                        label: const Text('Add Time'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (svc.times.isEmpty)
                    Text(
                      'No reminder times configured. Tap Add Time to enter a clock time.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: svc.times.map((hhmm) {
                        final parsed = TicketReminderService.parseTime(hhmm);
                        final display = parsed != null ? parsed.format(context) : hhmm;
                        return FintechFilterPill(
                          label: display,
                          selected: svc.enabled,
                          icon: Icons.access_time_rounded,
                          onDeleted: () => svc.removeTime(hhmm),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _formatReminderSummary(svc),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: svc.enabled && svc.days.isNotEmpty && svc.times.isNotEmpty
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              );
            },
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
              DetailRow(
                label: 'Software Version',
                value: _appVersion,
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
        color: AppColors.cardSurface(context),
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
