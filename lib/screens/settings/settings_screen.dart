import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../database/database_helper.dart';
import '../../models/expense.dart';
import '../../services/theme_service.dart';
import '../../services/company_service.dart';
import '../../services/excel_service.dart';
import '../../services/excel_import_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import 'label_export_screen.dart';

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
    _loadCounts();
    _companyCtrl.text = CompanyService().name;
  }

  @override
  void dispose() { _companyCtrl.dispose(); super.dispose(); }

  Future<void> _loadCounts() async {
    final c = await _db.getCounts();
    if (mounted) setState(() { _counts = c; _loadingCounts = false; });
  }

  // ── Backup ────────────────────────────────────────────────────
  Future<void> _backup() async {
    try {
      final json = await _db.exportJson();
      final ts = DateTime.now().toString().replaceAll(RegExp(r'[: .]'), '-').substring(0, 19);
      final fileName = 'inventorya_backup_$ts.json';

      String? outputPath;
      try {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Backup',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: utf8.encode(json),
        );
      } catch (_) { outputPath = null; }

      if (!mounted) return;
      if (outputPath != null) {
        showSnack(context, 'Backup saved to:\n$outputPath');
      } else {
        showSnack(context, 'Backup cancelled', error: true);
      }
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Backup failed: $e', error: true);
    }
  }

  // ── Restore ───────────────────────────────────────────────────
  Future<void> _restore() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (result == null || result.files.isEmpty || !mounted) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) { showSnack(context, 'Could not read file', error: true); return; }
      final ok = await showConfirmDialog(context,
          title: 'Restore Data',
          message: 'This will replace ALL current data. Cannot be undone.',
          confirmText: 'Restore', confirmColor: Colors.orange);
      if (!ok || !mounted) return;
      await _db.importJson(utf8.decode(bytes));
      if (!mounted) return;
      showSnack(context, 'Data restored successfully');
      _loadCounts();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Restore failed: $e', error: true);
    }
  }

  // ── Export Devices ────────────────────────────────────────────
  static const _exportDefs = [
    ('Laptops',         'laptops',         Icons.laptop_outlined,
      ['#', 'Laptop No.', 'Model', 'CPU', 'GPU', 'RAM', 'Storage', 'Condition', 'User']),
    ('Network Devices', 'network_devices', Icons.router_outlined,
      ['#', 'Device No.', 'Model', 'Phone No.', 'Location', 'Provider', 'WiFi Name', 'Status']),
    ('MiFis',           'mifis',           Icons.wifi_tethering_outlined,
      ['#', 'Device No.', 'Model', 'Phone No.', 'WiFi Name', 'Quota', 'Provider', 'Status']),
    ('Printers',        'printers',        Icons.print_outlined,
      ['#', 'Printer No.', 'Model', 'Condition', 'Location']),
    ('Electronics',     'electronics',     Icons.devices_other_outlined,
      ['#', 'Device No.', 'Device Name', 'Details', 'Status']),
    ('Employees',       'employees',       Icons.people_outline,
      ['#', 'Name', 'Phone Number']),
    ('Bills',           'bills',           Icons.receipt_outlined,
      ['#', 'Person', 'Number', 'Category', 'Price (EGP)', 'Notes']),
    ('Email Accounts',  'email_accounts',  Icons.email_outlined,
      ['#', 'Employee', 'Email', 'Password']),
  ];

  Future<void> _exportDevices() async {
    final picked = await showModalBottomSheet<int>(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Select Category to Export',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 14),
          ...List.generate(_exportDefs.length, (i) => ListTile(
            leading: Icon(_exportDefs[i].$3, color: Theme.of(ctx).colorScheme.primary),
            title: Text(_exportDefs[i].$1),
            trailing: const Icon(Icons.table_chart_outlined),
            onTap: () => Navigator.pop(ctx, i),
          )),
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      final def = _exportDefs[picked];
      final database = await _db.db;
      final rawRows = await database.query(def.$2);
      final rows = _buildRows(def.$2, rawRows);
      await ExcelService.exportTable(
        sheetName: def.$1,
        headers: def.$4 as List<String>,
        rows: rows,
        fileLabel: def.$1.replaceAll(' ', '_'),
      );
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Export failed: $e', error: true);
    }
  }

  List<List<dynamic>> _buildRows(String table, List<Map<String, dynamic>> raw) {
    return raw.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final r = entry.value;
      return switch (table) {
        'laptops'         => [i, r['laptop_number'], r['model'], r['cpu'], r['gpu'], r['ram'], r['storage'], r['condition'], r['user']],
        'network_devices' => [i, r['device_number'], r['model'], r['phone_number'], r['device_location'], r['service_provider'], r['wifi_name'], r['status']],
        'mifis'           => [i, r['device_number'], r['model'], r['phone_number'], r['wifi_name'], r['quota'], r['service_provider'], r['status']],
        'printers'        => [i, r['printer_number'], r['model'], r['condition'], r['location']],
        'electronics'     => [i, r['device_number'], r['device_name'], r['details'], r['status']],
        'employees'       => [i, r['name'], r['phone_number']],
        'bills'           => [i, r['person'], r['number'], r['category'], r['price'], r['notes']],
        'email_accounts'  => [i, r['employee_name'], r['email'], '(hidden)'],
        _                 => [i, ...r.values],
      };
    }).toList();
  }

  // ── Export Expenses date range ────────────────────────────────
  Future<void> _exportExpenses() async {
    DateTime fromDate = DateTime.now().copyWith(day: 1);
    DateTime toDate   = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Export Expenses', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Select date range:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _dateRow(ctx, Icons.calendar_today_outlined,
              'From: ${DateFormat('dd MMM yyyy').format(fromDate)}',
              () async {
                final p = await showDatePicker(context: ctx,
                  initialDate: fromDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                if (p != null) setS(() => fromDate = p);
              }),
            const SizedBox(height: 10),
            _dateRow(ctx, Icons.event_available_outlined,
              'To: ${DateFormat('dd MMM yyyy').format(toDate)}',
              () async {
                final p = await showDatePicker(context: ctx,
                  initialDate: toDate, firstDate: fromDate, lastDate: DateTime.now());
                if (p != null) setS(() => toDate = p);
              }),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Export')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final database = await _db.db;
      final fromStr = DateFormat('yyyy-MM-dd').format(fromDate);
      final toStr   = DateFormat('yyyy-MM-dd').format(toDate);
      final rawRows = await database.rawQuery(
        "SELECT * FROM expenses WHERE date >= ? AND date <= ? ORDER BY date DESC",
        [fromStr, toStr],
      );
      final label = '${DateFormat('dd_MMM').format(fromDate)}_to_${DateFormat('dd_MMM_yyyy').format(toDate)}';
      await ExcelService.exportExpenses(expenses: rawRows, label: label);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Export failed: $e', error: true);
    }
  }

  Widget _dateRow(BuildContext ctx, IconData icon, String label, VoidCallback onTap) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );

  // ── Import Devices ────────────────────────────────────────────
  static const _importDefs = [
    ('Laptops',         Icons.laptop_outlined),
    ('Network Devices', Icons.router_outlined),
    ('MiFis',           Icons.wifi_tethering_outlined),
    ('Printers',        Icons.print_outlined),
    ('Electronics',     Icons.devices_other_outlined),
    ('Employees',       Icons.people_outline),
    ('Bills',           Icons.receipt_outlined),
    ('Email Accounts',  Icons.email_outlined),
  ];

  Future<void> _importDevices() async {
    final picked = await showModalBottomSheet<int>(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Select Category to Import',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Pick an Excel (.xlsx) file exported from Inventorya\nor following the same column format.',
              style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5)),
              textAlign: TextAlign.center),
          const SizedBox(height: 14),
          ...List.generate(_importDefs.length, (i) => ListTile(
            leading: Icon(_importDefs[i].$2, color: Theme.of(ctx).colorScheme.primary),
            title: Text(_importDefs[i].$1),
            trailing: const Icon(Icons.upload_file_outlined),
            onTap: () => Navigator.pop(ctx, i),
          )),
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    await _runImport(picked);
  }

  Future<void> _runImport(int categoryIdx) async {
    final excel = await ExcelImportService.pickExcel();
    if (excel == null || !mounted) return;

    // Ask append vs replace
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Import Mode', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Do you want to add these records to existing data, or replace everything in this category?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'append'),
            child: const Text('Append')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Replace')),
        ],
      ),
    );
    if (mode == null || mode == 'cancel' || !mounted) return;

    // If replace, clear the table first
    if (mode == 'replace') {
      final database = await _db.db;
      final tableMap = [
        'laptops', 'network_devices', 'mifis', 'printers',
        'electronics', 'employees', 'bills', 'email_accounts',
      ];
      await database.delete(tableMap[categoryIdx]);
    }

    // Run the import
    ImportResult result;
    try {
      result = switch (categoryIdx) {
        0 => await ExcelImportService.importLaptops(excel),
        1 => await ExcelImportService.importNetworkDevices(excel),
        2 => await ExcelImportService.importMiFis(excel),
        3 => await ExcelImportService.importPrinters(excel),
        4 => await ExcelImportService.importElectronics(excel),
        5 => await ExcelImportService.importEmployees(excel),
        6 => await ExcelImportService.importBills(excel),
        7 => await ExcelImportService.importEmailAccounts(excel),
        _ => const ImportResult(inserted: 0, skipped: 0),
      };
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Import failed: $e', error: true);
      return;
    }

    if (!mounted) return;
    _loadCounts();

    if (result.errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Import Complete — ${result.summary}'),
          content: SingleChildScrollView(
            child: Text(result.errors.join('\n'),
                style: const TextStyle(fontSize: 12))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } else {
      showSnack(context, '✓ ${result.summary}');
    }
  }

  // ── Import Expenses ───────────────────────────────────────────
  Future<void> _importExpenses() async {
    final excel = await ExcelImportService.pickExcel();
    if (excel == null || !mounted) return;

    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Import Mode', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Append new expenses to existing ones, or replace all expenses?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'append'),
            child: const Text('Append')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Replace')),
        ],
      ),
    );
    if (mode == null || mode == 'cancel' || !mounted) return;

    if (mode == 'replace') {
      final database = await _db.db;
      await database.delete('expenses');
    }

    ImportResult result;
    try {
      result = await ExcelImportService.importExpenses(excel);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Import failed: $e', error: true);
      return;
    }

    if (!mounted) return;
    _loadCounts();
    showSnack(context, '✓ ${result.summary}');
  }

  // ── Company name ──────────────────────────────────────────────
  Future<void> _saveCompany() async {
    await CompanyService().setCompanyName(_companyCtrl.text.trim());
    if (!mounted) return;
    showSnack(context, 'Company name saved');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.themeService.isDark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary
          if (!_loadingCounts) ...[
            const _H('INVENTORY SUMMARY'),
            SizedBox(
              height: 88,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _SC(icon: Icons.laptop_outlined,         label: 'Laptops',     count: _counts['laptops'] ?? 0,         color: theme.colorScheme.primary),
                _SC(icon: Icons.router_outlined,         label: 'Network',     count: _counts['network_devices'] ?? 0, color: AppColors.networkColor),
                _SC(icon: Icons.wifi_tethering_outlined, label: 'MiFis',       count: _counts['mifis'] ?? 0,           color: const Color(0xFF0EA5E9)),
                _SC(icon: Icons.print_outlined,          label: 'Printers',    count: _counts['printers'] ?? 0,        color: AppColors.printerColor),
                _SC(icon: Icons.devices_other_outlined,  label: 'Electronics', count: _counts['electronics'] ?? 0,     color: AppColors.electronicColor),
                _SC(icon: Icons.people_outline,          label: 'Employees',   count: _counts['employees'] ?? 0,       color: const Color(0xFF0EA5E9)),
                _SC(icon: Icons.receipt_long_outlined,   label: 'Expenses',    count: _counts['expenses'] ?? 0,        color: const Color(0xFF10B981)),
                _SC(icon: Icons.receipt_outlined,        label: 'Bills',       count: _counts['bills'] ?? 0,           color: const Color(0xFF7C3AED)),
                _SC(icon: Icons.email_outlined,          label: 'Emails',      count: _counts['email_accounts'] ?? 0,  color: const Color(0xFF0EA5E9)),
                _SC(icon: Icons.swap_horiz_outlined,     label: 'Borrowed',    count: _counts['active_borrows'] ?? 0,  color: AppColors.borrowed),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          // Company
          const _H('COMPANY'),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _companyCtrl,
              enableSuggestions: false, autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Company Name',
                prefixIcon: Icon(Icons.business_outlined)),
            )),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _saveCompany, child: const Text('Save')),
          ]),

          // Appearance
          const SizedBox(height: 12),
          const _H('APPEARANCE'),
          _T(icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFFF59E0B),
            title: 'Dark Mode', subtitle: isDark ? 'Currently enabled' : 'Currently disabled',
            trailing: Switch(value: isDark, onChanged: (_) => widget.themeService.toggle())),

          // Backup & Restore
          const SizedBox(height: 8),
          const _H('BACKUP & RESTORE'),
          _T(icon: Icons.save_alt_outlined, color: theme.colorScheme.primary,
            title: 'Backup Data', subtitle: 'Save JSON backup — opens file manager',
            onTap: _backup),
          _T(icon: Icons.restore_outlined, color: Colors.orange,
            title: 'Restore Data', subtitle: 'Restore from a JSON backup file',
            onTap: _restore),

          // Export
          const SizedBox(height: 8),
          const _H('EXPORT'),
          _T(icon: Icons.table_chart_outlined, color: Colors.teal,
            title: 'Export Devices', subtitle: 'Export a device category to Excel (.xlsx)',
            onTap: _exportDevices),
          _T(icon: Icons.receipt_long_outlined, color: const Color(0xFF10B981),
            title: 'Export Expenses', subtitle: 'Export expenses by date range to Excel',
            onTap: _exportExpenses),

          // Import
          const SizedBox(height: 8),
          const _H('IMPORT'),
          _T(icon: Icons.upload_file_outlined, color: const Color(0xFF3B82F6),
            title: 'Import Devices', subtitle: 'Import from Excel — Laptops, Network, MiFis, Printers, Electronics, Employees, Bills, Emails',
            onTap: _importDevices),
          _T(icon: Icons.playlist_add_outlined, color: const Color(0xFF10B981),
            title: 'Import Expenses', subtitle: 'Import expenses from an Excel file',
            onTap: _importExpenses),

          // Labels
          const SizedBox(height: 8),
          const _H('DEVICE LABELS'),
          _T(icon: Icons.label_outline, color: const Color(0xFFB45309),
            title: 'Export Labels (PDF)', subtitle: 'Generate 3-column label sheet',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LabelExportScreen()))),

          // About
          const SizedBox(height: 32),
          Center(child: Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/icon/app_icon.png', width: 40, height: 40,
                errorBuilder: (_, __, ___) => Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                  child: Icon(Icons.inventory_2_outlined, size: 34,
                      color: theme.colorScheme.primary)))),
            const SizedBox(height: 8),
            Text('Inventorya', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            Text('v1.0.0 · com.ma.inventorya', style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
          ])),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.primary, letterSpacing: 0.8)));
}

class _SC extends StatelessWidget {
  final IconData icon; final String label; final int count; final Color color;
  const _SC({required this.icon, required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 80, margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text('$count', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
      Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
    ]));
}

class _T extends StatelessWidget {
  final IconData icon; final Color color;
  final String title, subtitle;
  final VoidCallback? onTap; final Widget? trailing;
  const _T({required this.icon, required this.color, required this.title,
      required this.subtitle, this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: color, size: 19)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        trailing: trailing ??
            (onTap != null ? Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)) : null),
      ),
    );
  }
}
