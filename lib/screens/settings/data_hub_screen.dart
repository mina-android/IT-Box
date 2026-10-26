import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../database/database_helper.dart';
import '../../services/excel_service.dart';
import '../../services/excel_import_service.dart';
import '../../services/pdf_report_service.dart';
import '../../services/custody_pdf_service.dart';
import '../../services/executive_health_pdf_service.dart';
import '../../models/laptop.dart';
import '../../widgets/common_widgets.dart';

class DataHubScreen extends StatefulWidget {
  const DataHubScreen({super.key});

  @override
  State<DataHubScreen> createState() => _DataHubScreenState();
}

class _DataHubScreenState extends State<DataHubScreen> {
  final _db = DatabaseHelper();

  // ── Database Backup ──────────────────────────────────────────
  Future<void> _backup() async {
    try {
      final encrypt = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Backup Options'),
          content: const Text(
            'Would you like to encrypt this backup with a secure passphrase (AES-256-GCM)?\n\n'
            'Encrypted backups require your password to restore and protect sensitive credentials.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Plaintext JSON'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.lock_rounded, size: 18),
              onPressed: () => Navigator.pop(ctx, true),
              label: const Text('Encrypt Backup'),
            ),
          ],
        ),
      );
      if (encrypt == null || !mounted) return;

      String? passphrase;
      if (encrypt) {
        final passCtrl = TextEditingController();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Set Backup Passphrase'),
            content: TextField(
              controller: passCtrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Passphrase *',
                prefixIcon: Icon(Icons.key_rounded),
                hintText: 'Enter a strong password',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (passCtrl.text.trim().length >= 4) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        passphrase = passCtrl.text.trim();
      }

      final json = await _db.exportJson(passphrase: passphrase);
      final ts = DateTime.now()
          .toString()
          .replaceAll(RegExp(r'[: .]'), '-')
          .substring(0, 19);
      final fileName = 'itbox_backup_$ts.json';

      final saveUri = await FilePickerPlatform.instance.saveFile(
        dialogTitle: 'Save Backup',
        fileName: fileName,
        bytes: utf8.encode(json),
        mimeType: 'application/json',
      );
      final outputPath = saveUri?.toString();

      if (!mounted) return;
      if (outputPath != null) {
        showSnack(context, 'Backup saved to:\n$outputPath');
      }
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Backup failed: $e', error: true);
    }
  }

  // ── Database Restore ─────────────────────────────────────────
  Future<void> _restore() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result.isEmpty || !mounted) return;
      final rawStr = utf8.decode(await result.first.readAsBytes());
      if (!mounted) return;

      // Inspect backup manifest
      var summary = await _db.inspectBackupJson(rawStr);
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
        summary = await _db.inspectBackupJson(rawStr, passphrase: passphrase);
      }

      if (!mounted) return;
      if (!summary.isValid) {
        showSnack(context, summary.validationError ?? 'Invalid backup file.', error: true);
        return;
      }

      // Display manifest summary before restoring
      final totalRecords = summary.tableCounts.values.fold<int>(0, (a, b) => a + b);
      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Full Restore'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Organization: ${summary.companyName.isNotEmpty ? summary.companyName : "IT Box"}'),
                Text('Exported: ${summary.exportedAt}'),
                Text('Schema Version: v${summary.schemaVersion}'),
                Text('Total Records: $totalRecords across ${summary.tableCounts.length} tables'),
                const SizedBox(height: 12),
                const Text(
                  'WARNING: This will replace ALL existing data with the contents of this backup file. This cannot be undone.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace All Data'),
            ),
          ],
        ),
      );

      if (shouldRestore != true || !mounted) return;

      await _db.importJson(rawStr, passphrase: passphrase);
      if (!mounted) return;
      showSnack(context, 'Database restored successfully ($totalRecords records)');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Restore failed: $e', error: true);
    }
  }

  // ── Table Definitions for Export & Templates ─────────────────
  static const _catalogDefs = [
    ('Laptops', 'laptops', Icons.laptop_outlined,
      ['#', 'Laptop No.', 'Model', 'CPU', 'GPU', 'RAM', 'Storage', 'Condition', 'User']),
    ('Routers', 'network_devices', Icons.router_outlined,
      ['#', 'Device No.', 'Model', 'Phone No.', 'Location', 'Provider', 'WiFi Name', 'Status']),
    ('MiFis', 'mifis', Icons.wifi_tethering_outlined,
      ['#', 'Device No.', 'Model', 'Phone No.', 'WiFi Name', 'Quota', 'Provider', 'Status']),
    ('APs', 'access_points', Icons.cell_tower_outlined,
      ['#', 'Device No.', 'Model', 'Port No.', 'Location']),
    ('Printers', 'printers', Icons.print_outlined,
      ['#', 'Printer No.', 'Model', 'Condition', 'Location']),
    ('Electronics', 'electronics', Icons.devices_other_outlined,
      ['#', 'Device No.', 'Device Name', 'Details', 'Status']),
    ('Employees', 'employees', Icons.people_outline,
      ['#', 'Name', 'Phone Number']),
    ('Bills', 'bills', Icons.receipt_outlined,
      ['#', 'Person', 'Number', 'Category', 'Price (EGP)', 'Notes']),
    ('Email Accounts', 'email_accounts', Icons.email_outlined,
      ['#', 'Employee', 'Email', 'Password']),
    ('Tickets / Log', 'log_entries', Icons.history_outlined,
      ['#', 'Date', 'Employee', 'Problem', 'Solution']),
    ('Subscriptions', 'subscriptions', Icons.subscriptions_outlined,
      ['#', 'Service Name', 'Billing Interval', 'Price (EGP)', 'Renewal Date', 'Notes']),
    ('Expenses', 'expenses', Icons.payments_outlined,
      ['#', 'Date', 'Item', 'Price (EGP)', 'Details']),
    ('Others', 'other_devices', Icons.devices_outlined,
      ['#', 'Device Type', 'Device Name', 'Model', 'Notes']),
  ];

  // ── Export Devices / Catalog Table ───────────────────────────
  Future<void> _exportCatalogTable() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Export Table to Excel',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.6,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _catalogDefs.length,
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  leading: IconBox(
                    icon: _catalogDefs[i].$3,
                    color: Theme.of(ctx).colorScheme.primary,
                    size: 36,
                  ),
                  title: Text(
                    _catalogDefs[i].$1,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  trailing: const Icon(Icons.table_chart_outlined, size: 18),
                  onTap: () => Navigator.pop(ctx, i),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;

    try {
      final def = _catalogDefs[picked];
      final rawRows = await _db.query(def.$2);
      final rows = _buildRows(def.$2, rawRows);
      await ExcelService.exportTable(
        sheetName: def.$1,
        headers: def.$4,
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
        'laptops' => [
            i,
            r['laptop_number'],
            r['model'],
            r['cpu'],
            r['gpu'],
            r['ram'],
            r['storage'],
            r['condition'],
            r['user']
          ],
        'network_devices' => [
            i,
            r['device_number'],
            r['model'],
            r['phone_number'],
            r['device_location'],
            r['service_provider'],
            r['wifi_name'],
            r['status']
          ],
        'mifis' => [
            i,
            r['device_number'],
            r['model'],
            r['phone_number'],
            r['wifi_name'],
            r['quota'],
            r['service_provider'],
            r['status']
          ],
        'printers' => [
            i,
            r['printer_number'],
            r['model'],
            r['condition'],
            r['location']
          ],
        'electronics' => [
            i,
            r['device_number'],
            r['device_name'],
            r['details'],
            r['status']
          ],
        'employees' => [i, r['name'], r['phone_number']],
        'bills' => [
            i,
            r['person'],
            r['number'],
            r['category'],
            r['price'],
            r['notes']
          ],
        'email_accounts' => [i, r['employee_name'], r['email'], '(hidden)'],
        'log_entries' => [
            i,
            r['date'],
            r['employee_name'],
            r['problem'],
            r['solution'] ?? ''
          ],
        'subscriptions' => [
            i,
            r['service'],
            r['type'],
            r['price'],
            r['renewal_date'],
            r['notes']
          ],
        'access_points' => [
            i,
            r['device_number'],
            r['model'],
            r['port_number'],
            r['location']
          ],
        'expenses' => [
            i,
            r['date'],
            r['item'],
            r['price'],
            r['details'] ?? ''
          ],
        'other_devices' => [
            i,
            r['device_type'],
            r['device_name'],
            r['model'] ?? '',
            r['notes'] ?? '',
          ],
        _ => [i, ...r.values],
      };
    }).toList();
  }

  // ── Export Expenses Date Range ───────────────────────────────
  Future<void> _exportExpenses() async {
    DateTime fromDate = DateTime.now().copyWith(day: 1);
    DateTime toDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Export Expenses',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select timeframe for the Excel statement:',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 16),
              _dateRow(
                ctx,
                Icons.calendar_today_outlined,
                'From: ${DateFormat('dd MMM yyyy').format(fromDate)}',
                () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: fromDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (p != null) {
                    setS(() => fromDate = p);
                  }
                },
              ),
              const SizedBox(height: 10),
              _dateRow(
                ctx,
                Icons.event_available_outlined,
                'To: ${DateFormat('dd MMM yyyy').format(toDate)}',
                () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: toDate,
                    firstDate: fromDate,
                    lastDate: DateTime.now(),
                  );
                  if (p != null) {
                    setS(() => toDate = p);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Export Excel'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final fromStr = DateFormat('yyyy-MM-dd').format(fromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(toDate);
      final rawRows = await _db.rawQuery(
        "SELECT * FROM expenses WHERE date >= ? AND date <= ? ORDER BY date DESC",
        [fromStr, toStr],
      );
      final label =
          '${DateFormat('dd_MMM').format(fromDate)}_to_${DateFormat('dd_MMM_yyyy').format(toDate)}';
      await ExcelService.exportExpenses(expenses: rawRows, label: label);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Export failed: $e', error: true);
    }
  }

  // ── Executive PDF Report ─────────────────────────────────────
  Future<void> _exportPdfReport() async {
    final expenses = await _db.getExpenses();
    final bills = await _db.getBills();
    final subs = await _db.getSubscriptions();
    if (!mounted) return;
    await PdfReportService.generateAndShareMonthlyReport(
      periodLabel: 'Full Catalog (${DateTime.now().year})',
      expenses: expenses,
      bills: bills,
      subscriptions: subs,
    );
  }

  // ── Bulk Laptop Custody Export ───────────────────────────────
  Future<void> _bulkExportLaptopCustody() async {
    final laptops = await _db.getLaptops();
    if (!mounted) return;
    if (laptops.isEmpty) {
      showSnack(context, 'No laptops found in inventory to export custody slips.', error: true);
      return;
    }

    final selected = List<Laptop>.from(laptops);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Export Bulk Custody Slips'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select laptops to generate a consolidated multi-page PDF of individual custody forms.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: laptops.length,
                    itemBuilder: (ctx, i) {
                      final lap = laptops[i];
                      final isSel = selected.contains(lap);
                      return CheckboxListTile(
                        dense: true,
                        title: Text('${lap.laptopNumber} • ${lap.model}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(lap.user.isNotEmpty ? 'User: ${lap.user}' : 'In Stock'),
                        value: isSel,
                        onChanged: (v) {
                          setDlgState(() {
                            if (v == true) {
                              selected.add(lap);
                            } else {
                              selected.remove(lap);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: Text('Export (${selected.length})'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selected.isNotEmpty && mounted) {
      try {
        final file = await CustodyPdfService.generateBulkLaptopCustodyPdf(selected);
        if (!mounted) return;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/pdf')],
            subject: 'Bulk Laptop Custody Slips (${selected.length} Devices)',
          ),
        );
        if (mounted) {
          showSnack(context, 'Exported ${selected.length} custody slips successfully');
        }
      } catch (e) {
        if (!mounted) return;
        showSnack(context, 'Bulk export failed: $e', error: true);
      }
    }
  }

  Widget _dateRow(
          BuildContext ctx, IconData icon, String label, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(ctx)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      );

  // ── Data Ingestion / Import ──────────────────────────────────
  static const _importDefs = [
    ('Laptops', Icons.laptop_outlined),
    ('Routers', Icons.router_outlined),
    ('MiFis', Icons.wifi_tethering_outlined),
    ('APs', Icons.cell_tower_outlined),
    ('Printers', Icons.print_outlined),
    ('Electronics', Icons.devices_other_outlined),
    ('Employees', Icons.people_outline),
    ('Bills', Icons.receipt_outlined),
    ('Email Accounts', Icons.email_outlined),
    ('Log', Icons.history_outlined),
    ('Subscriptions', Icons.subscriptions_outlined),
    ('Others', Icons.devices_outlined),
  ];

  Future<void> _importInventory() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select Category to Import',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 4),
            Text(
              'Pick an Excel (.xlsx) file exported from IT Box or created using a template.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.6,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _importDefs.length,
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  leading: IconBox(
                    icon: _importDefs[i].$2,
                    color: Theme.of(ctx).colorScheme.primary,
                    size: 36,
                  ),
                  title: Text(
                    _importDefs[i].$1,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  trailing: const Icon(Icons.upload_file_outlined, size: 18),
                  onTap: () => Navigator.pop(ctx, i),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _runImport(picked);
  }

  Future<void> _runImport(int categoryIdx) async {
    final excel = await ExcelImportService.pickExcel();
    if (excel == null || !mounted) return;

    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Import Mode',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'Do you want to append new rows or overwrite existing records in this category?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'append'),
            child: const Text('Append'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );
    if (mode == null || mode == 'cancel' || !mounted) return;

    final replace = mode == 'replace';
    if (replace) {
      final counts = await _db.getCounts();
      if (!mounted) return;
      final tableKey = switch (categoryIdx) {
        0 => 'laptops',
        1 => 'network_devices',
        2 => 'mifis',
        3 => 'access_points',
        4 => 'printers',
        5 => 'electronics',
        6 => 'employees',
        7 => 'bills',
        8 => 'email_accounts',
        9 => 'log_entries',
        10 => 'subscriptions',
        11 => 'other_devices',
        _ => '',
      };
      final existingCount = counts[tableKey] ?? 0;
      final categoryName = _catalogDefs[categoryIdx].$1;
      final confirmed = await showConfirmDialog(
        context,
        title: 'Confirm Replace All',
        message:
            'This will permanently delete all $existingCount existing $categoryName record${existingCount == 1 ? '' : 's'} and replace them with rows from the Excel sheet.\n\nAre you sure you want to proceed?',
        confirmText: 'Replace $existingCount Records',
        confirmColor: Colors.red,
      );
      if (!confirmed || !mounted) return;
    }

    ImportResult result;
    try {
      result = switch (categoryIdx) {
        0 => await ExcelImportService.importLaptops(excel, replace: replace),
        1 => await ExcelImportService.importNetworkDevices(excel, replace: replace),
        2 => await ExcelImportService.importMiFis(excel, replace: replace),
        3 => await ExcelImportService.importAccessPoints(excel, replace: replace),
        4 => await ExcelImportService.importPrinters(excel, replace: replace),
        5 => await ExcelImportService.importElectronics(excel, replace: replace),
        6 => await ExcelImportService.importEmployees(excel, replace: replace),
        7 => await ExcelImportService.importBills(excel, replace: replace),
        8 => await ExcelImportService.importEmailAccounts(excel, replace: replace),
        9 => await ExcelImportService.importLogEntries(excel, replace: replace),
        10 => await ExcelImportService.importSubscriptions(excel, replace: replace),
        11 => await ExcelImportService.importOtherDevices(excel, replace: replace),
        _ => const ImportResult(inserted: 0, skipped: 0),
      };
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Import failed: $e', error: true);
      return;
    }

    if (!mounted) return;

    if (result.errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Import Finished — ${result.summary}'),
          content: SingleChildScrollView(
            child: Text(result.errors.join('\n'),
                style: const TextStyle(fontSize: 12)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showSnack(context, '✓ ${result.summary}');
    }
  }

  Future<void> _importExpenses() async {
    final excel = await ExcelImportService.pickExcel();
    if (excel == null || !mounted) return;

    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Import Expenses',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'Append new expenses or replace all existing expense ledger records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'append'),
            child: const Text('Append'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );
    if (mode == null || mode == 'cancel' || !mounted) return;

    if (mode == 'replace') {
      final counts = await _db.getCounts();
      if (!mounted) return;
      final existingCount = counts['expenses'] ?? 0;
      final confirmed = await showConfirmDialog(
        context,
        title: 'Confirm Replace All Expenses',
        message:
            'This will permanently delete all $existingCount existing expense record${existingCount == 1 ? '' : 's'} and replace them with rows from the Excel sheet.\n\nAre you sure you want to proceed?',
        confirmText: 'Replace $existingCount Expenses',
        confirmColor: Colors.red,
      );
      if (!confirmed || !mounted) return;
    }

    ImportResult result;
    try {
      result = await ExcelImportService.importExpenses(excel, replace: mode == 'replace');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Import failed: $e', error: true);
      return;
    }

    if (!mounted) return;
    showSnack(context, '✓ ${result.summary}');
  }

  // ── Download Excel Sheet Templates ───────────────────────────
  // Creates clean blank templates with headers & a single helpful sample row
  Future<void> _downloadTemplate(int index) async {
    try {
      final def = _catalogDefs[index];
      final headers = def.$4;
      
      // Sample row for each data model
      final sampleRow = switch (def.$2) {
        'laptops' => [1, 'L-01', 'Dell XPS 15', 'i7-12700H', 'RTX 3050', '32GB', '1TB NVMe', 'Good', 'John Doe'],
        'network_devices' => [1, 'R-01', 'TP-Link AX3000', '01000000000', 'Floor 2 IT Rack', 'WE', 'IT-Office-5G', 'Available'],
        'mifis' => [1, 'M-01', 'ZTE MF927U', '01100000000', 'WE_MiFi_1', '140 GB', 'Orange', 'Available'],
        'access_points' => [1, 'AP-01', 'Ubiquiti U6 Pro', 'Port 14', 'Main Lobby'],
        'printers' => [1, 'P-01', 'HP LaserJet Pro M404n', 'Good', 'Operations Room'],
        'electronics' => [1, 'E-01', 'HDMI Switcher 4K', '4-port switcher with remote', 'Available'],
        'employees' => [1, 'Jane Smith', '+20 123 456 7890'],
        'bills' => [1, 'WE Telecom', '101', 'Internet Fiber', 1500.0, 'Monthly office connection'],
        'email_accounts' => [1, 'Jane Smith', 'jane.smith@company.com', 'InitialTempPass123!'],
        'log_entries' => [1, '2026-10-05', 'Jane Smith', 'Network printer offline', 'Reconnected static IP'],
        'subscriptions' => [1, 'Figma Organization', 'Yearly', 5400.0, '2027-01-15', 'Design team license'],
        'expenses' => [1, '2026-10-05', 'Ethernet Patch Cables (10x)', 450.0, 'Cat6 3m patch cords'],
        'other_devices' => [1, 'Barcode Scanner', 'Zebra DS2208', 'DS2208-SR', 'USB handheld 2D imager'],
        _ => [1, 'Sample Data 1', 'Sample Data 2'],
      };

      await ExcelService.exportTable(
        sheetName: '${def.$1} Template',
        headers: headers,
        rows: [sampleRow],
        fileLabel: '${def.$1}_Template',
      );
      if (mounted) {
        showSnack(context, 'Template for ${def.$1} generated');
      }
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Template export failed: $e', error: true);
    }
  }

  void _showTemplatesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Download Excel Import Template',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              'Select any category to generate a pre-formatted Excel spreadsheet template with column headers and sample data.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.6,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _catalogDefs.length,
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  leading: IconBox(
                    icon: _catalogDefs[i].$3,
                    color: const Color(0xFF10B981),
                    size: 36,
                  ),
                  title: Text(
                    _catalogDefs[i].$1,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${_catalogDefs[i].$4.length} columns: ${_catalogDefs[i].$4.take(3).join(', ')}...',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.download_rounded, size: 20, color: Color(0xFF10B981)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _downloadTemplate(i);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Hub & Backups'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
        children: [
          // ── Templates Section ──────────────────────────────────
          const SectionLabel('EXCEL IMPORT TEMPLATES'),
          FintechGroupedCard(
            title: 'Data Ingestion Templates',
            icon: Icons.file_download_outlined,
            children: [
              _SettingActionTile(
                icon: Icons.table_view_rounded,
                color: const Color(0xFF10B981),
                title: 'Download Category Templates (.xlsx)',
                subtitle:
                    'Generate pre-formatted Excel spreadsheets for any data category (Laptops, MiFis, Users, Expenses...)',
                onTap: _showTemplatesSheet,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Data Storage & Backups ─────────────────────────────
          const SectionLabel('DATABASE BACKUP & RESTORE'),
          FintechGroupedCard(
            title: 'Local Database Vault',
            icon: Icons.sd_card_outlined,
            children: [
              _SettingActionTile(
                icon: Icons.save_alt_rounded,
                color: theme.colorScheme.primary,
                title: 'Create Backup Snapshot',
                subtitle:
                    'Export an encrypted offline JSON snapshot of all inventory and records',
                onTap: _backup,
              ),
              const Divider(height: 16),
              _SettingActionTile(
                icon: Icons.settings_backup_restore_rounded,
                color: Colors.orange,
                title: 'Restore Database',
                subtitle:
                    'Rebuild database from an existing JSON backup file',
                onTap: _restore,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Export & Integrations ──────────────────────────────
          const SectionLabel('DATA EXPORT & INTEGRATIONS'),
          FintechGroupedCard(
            title: 'Spreadsheets & PDF Reports',
            icon: Icons.table_chart_outlined,
            children: [
              _SettingActionTile(
                icon: Icons.table_view_rounded,
                color: Colors.teal,
                title: 'Export Category Table (.xlsx)',
                subtitle:
                    'Export all records from any category into a formatted Excel sheet',
                onTap: _exportCatalogTable,
              ),
              const Divider(height: 16),
              _SettingActionTile(
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF10B981),
                title: 'Export Expenses by Timeframe (.xlsx)',
                subtitle:
                    'Filter expenditure records by date into an Excel financial ledger',
                onTap: _exportExpenses,
              ),
              const Divider(height: 16),
              _SettingActionTile(
                icon: Icons.picture_as_pdf_rounded,
                color: const Color(0xFFE11D48),
                title: 'Executive Financial Report (PDF)',
                subtitle:
                    'Generate branded executive PDF summary of expenses, bills & subscriptions',
                onTap: _exportPdfReport,
              ),
              const Divider(height: 16),
              _SettingActionTile(
                icon: Icons.assignment_turned_in_rounded,
                color: Colors.indigo,
                title: 'Bulk Laptop Custody Slips (PDF)',
                subtitle:
                    'Generate consolidated multi-page PDF custody slips for selected laptops',
                onTap: _bulkExportLaptopCustody,
              ),
              const Divider(height: 16),
              _SettingActionTile(
                icon: Icons.analytics_outlined,
                color: const Color(0xFF6366F1),
                title: 'Executive Health Infographic (PDF)',
                subtitle:
                    'Full executive health and hardware fleet summary report',
                onTap: () async => await ExecutiveHealthPdfService.generateAndShareExecutiveReport(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Data Ingestion / Import ────────────────────────────
          const SectionLabel('DATA INGESTION / IMPORT'),
          FintechGroupedCard(
            title: 'Batch Excel Ingestion',
            icon: Icons.download_rounded,
            children: [
              _SettingActionTile(
                icon: Icons.file_upload_outlined,
                color: const Color(0xFF3B82F6),
                title: 'Import Inventory Sheets (.xlsx)',
                subtitle:
                    'Batch import devices, staff directory, credentials, or tickets',
                onTap: _importInventory,
              ),
              const Divider(height: 16),
              _SettingActionTile(
                icon: Icons.post_add_rounded,
                color: const Color(0xFF10B981),
                title: 'Import Expense Ledger (.xlsx)',
                subtitle: 'Append or replace corporate spending records',
                onTap: _importExpenses,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            IconBox(icon: icon, color: color, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}
