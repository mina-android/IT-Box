import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../database/database_helper.dart';
import '../../models/bill.dart';
import '../../models/expense.dart';
import '../../models/laptop.dart';
import '../../models/subscription.dart';
import '../../services/auto_backup_service.dart';
import '../../services/currency_service.dart';
import '../../services/custody_pdf_service.dart';
import '../../services/excel_import_service.dart';
import '../../services/excel_service.dart';
import '../../services/executive_health_pdf_service.dart';
import '../../services/pdf_report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../../widgets/common_widgets.dart';

class DataHubScreen extends StatefulWidget {
  const DataHubScreen({super.key});

  @override
  State<DataHubScreen> createState() => _DataHubScreenState();
}

class _DataHubScreenState extends State<DataHubScreen> {
  final _db = DatabaseHelper();
  String? _lastPreRestoreSnapshotPath;
  bool _canUndoRestore = false;

  // ── Database Backup (Full) ────────────────────────────────────
  Future<void> _backup() async {
    try {
      final encrypt = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Backup Options'),
          content: const Text(
            'Would you like to encrypt this backup with a secure passphrase (AES-256-GCM)?\n\n'
            'Encrypted backups (.itbox.enc) protect sensitive credentials and embedded Vault documents.',
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
      if (encrypt == null || !mounted) {
        return;
      }

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
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Passphrase *',
                prefixIcon: Icon(Icons.key_rounded),
                hintText: 'Enter a strong password (min 4 chars)',
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
        passphrase = passCtrl.text.trim();
        Future.delayed(const Duration(milliseconds: 350), passCtrl.dispose);
        if (confirmed != true || !mounted) {
          return;
        }
      }

      final json = await _db.exportJson(
        passphrase: passphrase,
        includeVaultBinaries: true,
      );
      final ts = DateTime.now()
          .toString()
          .replaceAll(RegExp(r'[: .]'), '-')
          .substring(0, 19);
      final fileName = encrypt ? 'itbox_backup_$ts.itbox.enc' : 'itbox_backup_$ts.json';

      final saveUri = await FilePickerPlatform.instance.saveFile(
        dialogTitle: 'Save Backup',
        fileName: fileName,
        bytes: utf8.encode(json),
        mimeType: encrypt ? 'application/octet-stream' : 'application/json',
      );
      final outputPath = saveUri?.toString();

      if (!mounted) {
        return;
      }
      if (outputPath != null) {
        showSnack(context, 'Backup saved to:\n$outputPath');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(context, 'Backup failed: $e', error: true);
    }
  }

  // ── Selective Backup Sheet ────────────────────────────────────
  void _showSelectiveBackupSheet() {
    showFintechBottomSheet(
      context: context,
      title: 'Selective Backup',
      subtitle: 'Choose specific tables & documents to export',
      child: _SelectiveBackupSheet(
        onSaved: (msg) {
          if (mounted) {
            showSnack(context, msg);
          }
        },
      ),
    );
  }

  // ── Database Restore (Full or Selective + Pre-Restore Undo) ───
  Future<void> _restore() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'enc'],
      );
      if (result.isEmpty || !mounted) {
        return;
      }
      final rawStr = utf8.decode(await result.first.readAsBytes());
      if (!mounted) {
        return;
      }

      var summary = await _db.inspectBackupJson(rawStr);
      String? passphrase;

      if (summary.isEncrypted && !summary.isValid) {
        if (!mounted) {
          return;
        }
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
                  enableSuggestions: false,
                  autocorrect: false,
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
        passphrase = passCtrl.text.trim();
        Future.delayed(const Duration(milliseconds: 350), passCtrl.dispose);
        if (okPass != true || !mounted) {
          return;
        }
        summary = await _db.inspectBackupJson(rawStr, passphrase: passphrase);
      }

      if (!mounted) {
        return;
      }
      if (!summary.isValid) {
        showSnack(context, summary.validationError ?? 'Invalid backup file.', error: true);
        return;
      }

      _showRestoreModeSheet(rawStr, summary, passphrase);
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(context, 'Restore failed: $e', error: true);
    }
  }

  void _showRestoreModeSheet(
    String rawStr,
    BackupManifestSummary summary,
    String? passphrase,
  ) {
    final cs = Theme.of(context).colorScheme;
    final totalRecords = summary.tableCounts.values.fold<int>(0, (a, b) => a + b);

    showFintechBottomSheet(
      context: context,
      title: 'Choose Restore Mode',
      subtitle:
          '${summary.companyName.isNotEmpty ? summary.companyName : "IT Box"} • Schema v${summary.schemaVersion} • $totalRecords records',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.embeddedVaultFilesCount > 0 || summary.embeddedReceiptFilesCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Includes ${[
                  if (summary.embeddedVaultFilesCount > 0)
                    '${summary.embeddedVaultFilesCount} Vault file(s)',
                  if (summary.embeddedReceiptFilesCount > 0)
                    '${summary.embeddedReceiptFilesCount} Receipt file(s)',
                ].join(' • ')}.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
              ),
            ),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
            ),
            tileColor: cs.primaryContainer.withValues(alpha: 0.25),
            leading: Icon(Icons.checklist_rounded, color: cs.primary, size: 28),
            title: const Text('Selective Restore', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Pick specific tables to restore while keeping other data'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pop(context);
              showFintechBottomSheet(
                context: context,
                title: 'Selective Restore',
                subtitle: 'Dependent prerequisite tables are auto-selected',
                child: _SelectiveRestoreSheet(
                  summary: summary,
                  onConfirm: (selectedTables) async {
                    final snap = await _db.createPreRestoreSnapshot();
                    await _db.importJsonSelective(
                      rawStr,
                      selectedTables,
                      passphrase: passphrase,
                      restorePrefs: false,
                    );
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _lastPreRestoreSnapshotPath = snap;
                      _canUndoRestore = snap != null;
                    });
                    showSnack(context, 'Restored ${selectedTables.length} selected table(s)');
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.error.withValues(alpha: 0.35)),
            ),
            tileColor: cs.errorContainer.withValues(alpha: 0.2),
            leading: Icon(Icons.restore_outlined, color: cs.error, size: 28),
            title: const Text('Full Restore', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Replace all tables, branding, and preferences'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              Navigator.pop(context);
              final shouldRestore = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Full Restore'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Organization: ${summary.companyName.isNotEmpty ? summary.companyName : "IT Box"}'),
                      Text('Exported: ${summary.exportedAt}'),
                      Text('Schema Version: v${summary.schemaVersion}'),
                      Text('Total Records: $totalRecords across ${summary.tableCounts.length} tables'),
                      if (summary.embeddedVaultFilesCount > 0)
                        Text('Embedded Vault Files: ${summary.embeddedVaultFilesCount}'),
                      if (summary.embeddedReceiptFilesCount > 0)
                        Text('Embedded Receipt Files: ${summary.embeddedReceiptFilesCount}'),
                      const SizedBox(height: 12),
                      const Text(
                        'WARNING: This will replace ALL existing data with the contents of this backup file.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
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
              if (shouldRestore != true || !mounted) {
                return;
              }
              final snap = await _db.createPreRestoreSnapshot();
              await _db.importJson(rawStr, passphrase: passphrase);
              if (!mounted) {
                return;
              }
              setState(() {
                _lastPreRestoreSnapshotPath = snap;
                _canUndoRestore = snap != null;
              });
              showSnack(context, 'Database restored successfully ($totalRecords records)');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _undoLastRestore() async {
    final path = _lastPreRestoreSnapshotPath;
    if (path == null) {
      return;
    }
    try {
      await _db.restoreFromSnapshotPath(path);
      if (!mounted) {
        return;
      }
      setState(() {
        _canUndoRestore = false;
        _lastPreRestoreSnapshotPath = null;
      });
      showSnack(context, 'Previous database state restored (Undo complete)');
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Undo failed: $e', error: true);
      }
    }
  }

  // ── Table Definitions for Export & Templates ─────────────────
  static List<(String, String, IconData, List<String>)> get _catalogDefs => [
        (
          'Laptops',
          'laptops',
          Icons.laptop_outlined,
          ['#', 'Laptop No.', 'Model', 'CPU', 'GPU', 'RAM', 'Storage', 'Condition', 'User']
        ),
        (
          'Routers',
          'network_devices',
          Icons.router_outlined,
          ['#', 'Device No.', 'Model', 'Phone No.', 'Location', 'Provider', 'WiFi Name', 'Status']
        ),
        (
          'MiFis',
          'mifis',
          Icons.wifi_tethering_outlined,
          ['#', 'Device No.', 'Model', 'Phone No.', 'WiFi Name', 'Quota', 'Provider', 'Status']
        ),
        (
          'APs',
          'access_points',
          Icons.cell_tower_outlined,
          ['#', 'Device No.', 'Model', 'Port No.', 'Location']
        ),
        (
          'Printers',
          'printers',
          Icons.print_outlined,
          ['#', 'Printer No.', 'Model', 'Condition', 'Location']
        ),
        (
          'Electronics',
          'electronics',
          Icons.devices_other_outlined,
          ['#', 'Device No.', 'Device Name', 'Details', 'Status']
        ),
        ('Employees', 'employees', Icons.people_outline, ['#', 'Name', 'Phone Number']),
        (
          'Bills',
          'bills',
          Icons.receipt_outlined,
          ['#', 'Person', 'Number', 'Category', 'Price (${CurrencyService().currency})', 'Notes']
        ),
        (
          'Email Accounts',
          'email_accounts',
          Icons.email_outlined,
          ['#', 'Employee', 'Email', 'Password']
        ),
        (
          'Tickets / Log',
          'log_entries',
          Icons.history_outlined,
          ['#', 'Date', 'Employee', 'Problem', 'Solution']
        ),
        (
          'Subscriptions',
          'subscriptions',
          Icons.subscriptions_outlined,
          ['#', 'Service Name', 'Billing Interval', 'Price (${CurrencyService().currency})', 'Renewal Date', 'Notes']
        ),
        (
          'Expenses',
          'expenses',
          Icons.payments_outlined,
          ['#', 'Date', 'Item', 'Price (${CurrencyService().currency})', 'Details']
        ),
        (
          'Others',
          'other_devices',
          Icons.devices_outlined,
          ['#', 'Device Type', 'Device Name', 'Model', 'Notes']
        ),
        (
          'Vendor Contacts',
          'vendor_contacts',
          Icons.contact_phone_outlined,
          ['#', 'Type', 'Name', 'Company', 'Role', 'Phone', 'Email', 'Portal URL', 'Account No.', 'SLA Tier', 'Notes']
        ),
        (
          'Wi-Fi Networks',
          'wifi_networks',
          Icons.wifi_password_rounded,
          ['#', 'Network Name', 'Password', 'Phone/Line', 'Location/Device', 'Admin User', 'Admin Pass', 'Notes']
        ),
        (
          'Accounts & Passwords',
          'account_passwords',
          Icons.vpn_key_outlined,
          ['#', 'Platform', 'Email/Username', 'Password']
        ),
        (
          'Static IPs',
          'static_ips',
          Icons.lan_outlined,
          ['#', 'IP Address', 'Subnet Mask', 'MAC Address', 'Assigned Device', 'Device Type', 'Notes']
        ),
        (
          'Borrows',
          'borrow_logs',
          Icons.swap_horiz_rounded,
          ['#', 'Employee', 'Device Type', 'Device Name', 'Device No.', 'Out Date', 'Due Date', 'Returned', 'Reason', 'Notes']
        ),
        (
          'Maintenance Logs',
          'device_maintenance_logs',
          Icons.build_outlined,
          ['#', 'Device Type', 'Device ID', 'Date', 'Service Type', 'Cost (${CurrencyService().currency})', 'Performed By', 'Details']
        ),
      ];

  Future<void> _exportCatalogTable() async {
    final defs = _catalogDefs;
    final selected = <int>{};
    final pickedIndices = await showFintechBottomSheet<List<int>>(
      context: context,
      title: 'Export Tables to Excel',
      subtitle: 'Select one or more categories to export (.xlsx)',
      child: StatefulBuilder(
        builder: (ctx, setS) {
          final allSelected = selected.length == defs.length;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${selected.length} of ${defs.length} selected',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setS(() {
                        if (allSelected) {
                          selected.clear();
                        } else {
                          selected.addAll(List.generate(defs.length, (i) => i));
                        }
                      });
                    },
                    child: Text(allSelected ? 'Deselect All' : 'Select All'),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: defs.length,
                  itemBuilder: (ctx, i) => CheckboxListTile(
                    dense: true,
                    value: selected.contains(i),
                    onChanged: (v) {
                      setS(() {
                        if (v == true) {
                          selected.add(i);
                        } else {
                          selected.remove(i);
                        }
                      });
                    },
                    secondary: IconBox(
                      icon: defs[i].$3,
                      color: Theme.of(ctx).colorScheme.primary,
                      size: 34,
                    ),
                    title: Text(
                      defs[i].$1,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, selected.toList()..sort()),
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: Text(
                    selected.isEmpty
                        ? 'Select Tables to Export'
                        : 'Export ${selected.length} ${selected.length == 1 ? 'Table' : 'Tables'} (.xlsx)',
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    if (pickedIndices == null || pickedIndices.isEmpty || !mounted) {
      return;
    }

    try {
      final exportPayload = <({
        String sheetName,
        List<String> headers,
        List<List<dynamic>> rows,
        String fileLabel,
      })>[];

      for (final idx in pickedIndices) {
        final def = defs[idx];
        final rawRows = await _db.query(def.$2);
        final rows = _buildRows(def.$2, rawRows);
        exportPayload.add((
          sheetName: def.$1.replaceAll('/', '-'),
          headers: def.$4,
          rows: rows,
          fileLabel: def.$1.replaceAll(' ', '_'),
        ));
      }

      await ExcelService.exportMultipleTables(exportPayload);
    } catch (e) {
      if (!mounted) {
        return;
      }
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
        'vendor_contacts' => [
            i,
            r['contact_type'],
            r['name'],
            r['company'] ?? '',
            r['role'] ?? '',
            r['phone_number'] ?? '',
            r['email'] ?? '',
            r['portal_url'] ?? '',
            r['account_number'] ?? '',
            r['sla_tier'] ?? '',
            r['notes'] ?? '',
          ],
        'wifi_networks' => [
            i,
            r['network_name'],
            '(hidden)',
            r['phone_number'] ?? '',
            r['location_device'] ?? '',
            r['admin_username'] ?? '',
            '(hidden)',
            r['notes'] ?? '',
          ],
        'account_passwords' => [
            i,
            r['platform'],
            r['email_username'] ?? '',
            '(hidden)',
          ],
        'static_ips' => [
            i,
            r['ip_address'],
            r['subnet_mask'] ?? '',
            r['mac_address'] ?? '',
            r['assigned_device'] ?? '',
            r['device_type'] ?? '',
            r['notes'] ?? '',
          ],
        'borrow_logs' => [
            i,
            r['employee_name'],
            r['device_type'],
            r['device_name'],
            r['device_number'],
            r['out_date'],
            r['due_date'] ?? '',
            (r['is_returned'] == 1) ? 'Yes' : 'No',
            r['reason'] ?? '',
            r['notes'] ?? '',
          ],
        'device_maintenance_logs' => [
            i,
            r['device_type'],
            r['device_id'],
            r['date'],
            r['service_type'],
            r['cost'] ?? 0.0,
            r['performed_by'] ?? '',
            r['details'] ?? '',
          ],
        _ => [i, ...r.values],
      };
    }).toList();
  }

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

    if (confirmed != true || !mounted) {
      return;
    }

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
      if (!mounted) {
        return;
      }
      showSnack(context, 'Export failed: $e', error: true);
    }
  }

  Future<void> _exportPdfReport() async {
    final years = await _db.getExpenseYears();
    if (!mounted) {
      return;
    }
    final allYears = {...years, DateTime.now().year}.toList()
      ..sort((a, b) => b.compareTo(a));

    final selectedPeriod = await showFintechBottomSheet<int?>(
      context: context,
      title: 'Executive Financial Report (PDF)',
      subtitle: 'Choose a fiscal year or full catalog history',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: IconBox(
              icon: Icons.all_inclusive_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 36,
            ),
            title: const Text('All Time (Full Catalog)', style: TextStyle(fontWeight: FontWeight.w700)),
            trailing: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            onTap: () => Navigator.pop(context, -1),
          ),
          const Divider(height: 1),
          for (final y in allYears)
            ListTile(
              leading: const IconBox(
                icon: Icons.calendar_month_rounded,
                color: Color(0xFFE11D48),
                size: 36,
              ),
              title: Text('Year $y', style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              onTap: () => Navigator.pop(context, y),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );

    if (selectedPeriod == null || !mounted) {
      return;
    }

    final results = await Future.wait([
      selectedPeriod == -1 ? _db.getExpenses() : _db.getExpensesByYear(selectedPeriod),
      _db.getBills(),
      _db.getSubscriptions(),
    ]);
    if (!mounted) {
      return;
    }
    await PdfReportService.generateAndShareMonthlyReport(
      periodLabel: selectedPeriod == -1 ? 'Full Catalog' : '$selectedPeriod',
      expenses: results[0] as List<Expense>,
      bills: results[1] as List<Bill>,
      subscriptions: results[2] as List<Subscription>,
    );
  }

  Future<void> _bulkExportLaptopCustody() async {
    final laptops = await _db.getLaptops();
    if (!mounted) {
      return;
    }
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
                        title: Text('${lap.laptopNumber} • ${lap.model}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
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
        if (!mounted) {
          return;
        }
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
        if (!mounted) {
          return;
        }
        showSnack(context, 'Bulk export failed: $e', error: true);
      }
    }
  }

  Widget _dateRow(BuildContext ctx, IconData icon, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      );

  // ── Data Ingestion / Import ──────────────────────────────────
  static const _importDefs = [
    ('Laptops', 'laptops', Icons.laptop_outlined),
    ('Routers', 'network_devices', Icons.router_outlined),
    ('MiFis', 'mifis', Icons.wifi_tethering_outlined),
    ('APs', 'access_points', Icons.cell_tower_outlined),
    ('Printers', 'printers', Icons.print_outlined),
    ('Electronics', 'electronics', Icons.devices_other_outlined),
    ('Employees', 'employees', Icons.people_outline),
    ('Bills', 'bills', Icons.receipt_outlined),
    ('Email Accounts', 'email_accounts', Icons.email_outlined),
    ('Log', 'log_entries', Icons.history_outlined),
    ('Subscriptions', 'subscriptions', Icons.subscriptions_outlined),
    ('Others', 'other_devices', Icons.devices_outlined),
    ('Vendor Contacts', 'vendor_contacts', Icons.contact_phone_outlined),
    ('Wi-Fi Networks', 'wifi_networks', Icons.wifi_password_rounded),
    ('Accounts & Passwords', 'account_passwords', Icons.vpn_key_outlined),
    ('Static IPs', 'static_ips', Icons.lan_outlined),
  ];

  Future<void> _importInventory() async {
    final picked = await showFintechBottomSheet<int>(
      context: context,
      title: 'Select Category to Import',
      subtitle: 'Pick an Excel (.xlsx) file exported from IT Box or a template',
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _importDefs.length,
          itemBuilder: (ctx, i) => ListTile(
            dense: true,
            leading: IconBox(
              icon: _importDefs[i].$3,
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
    );
    if (picked == null || !mounted) {
      return;
    }
    await _runImport(picked);
  }

  Future<void> _runImport(int categoryIdx) async {
    final excel = await ExcelImportService.pickExcel();
    if (excel == null || !mounted) {
      return;
    }

    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Import Mode', style: TextStyle(fontWeight: FontWeight.w800)),
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
    if (mode == null || mode == 'cancel' || !mounted) {
      return;
    }

    final replace = mode == 'replace';
    if (replace) {
      final counts = await _db.getCounts();
      if (!mounted) {
        return;
      }
      final def = _importDefs[categoryIdx];
      final existingCount = counts[def.$2] ?? 0;
      final categoryName = def.$1;
      final confirmed = await showConfirmDialog(
        context,
        title: 'Confirm Replace All',
        message:
            'This will permanently delete all $existingCount existing $categoryName record${existingCount == 1 ? '' : 's'} and replace them with rows from the Excel sheet.\n\nAre you sure you want to proceed?',
        confirmText: 'Replace $existingCount Records',
        confirmColor: Colors.red,
      );
      if (!confirmed || !mounted) {
        return;
      }
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
        12 => await ExcelImportService.importVendorContacts(excel, replace: replace),
        13 => await ExcelImportService.importWifiNetworks(excel, replace: replace),
        14 => await ExcelImportService.importAccountPasswords(excel, replace: replace),
        15 => await ExcelImportService.importStaticIps(excel, replace: replace),
        _ => const ImportResult(inserted: 0, skipped: 0),
      };
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(context, 'Import failed: $e', error: true);
      return;
    }

    if (!mounted) {
      return;
    }

    if (result.errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Import Finished — ${result.summary}'),
          content: SingleChildScrollView(
            child: Text(result.errors.join('\n'), style: const TextStyle(fontSize: 12)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
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
    if (excel == null || !mounted) {
      return;
    }

    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Import Expenses', style: TextStyle(fontWeight: FontWeight.w800)),
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
    if (mode == null || mode == 'cancel' || !mounted) {
      return;
    }

    if (mode == 'replace') {
      final counts = await _db.getCounts();
      if (!mounted) {
        return;
      }
      final existingCount = counts['expenses'] ?? 0;
      final confirmed = await showConfirmDialog(
        context,
        title: 'Confirm Replace All Expenses',
        message:
            'This will permanently delete all $existingCount existing expense record${existingCount == 1 ? '' : 's'} and replace them with rows from the Excel sheet.\n\nAre you sure you want to proceed?',
        confirmText: 'Replace $existingCount Expenses',
        confirmColor: Colors.red,
      );
      if (!confirmed || !mounted) {
        return;
      }
    }

    ImportResult result;
    try {
      result = await ExcelImportService.importExpenses(excel, replace: mode == 'replace');
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(context, 'Import failed: $e', error: true);
      return;
    }

    if (!mounted) {
      return;
    }
    showSnack(context, '✓ ${result.summary}');
  }

  Future<void> _downloadTemplate(int index) async {
    try {
      final def = _catalogDefs[index];
      final headers = def.$4;

      final sampleRow = switch (def.$2) {
        'laptops' => [1, 'L-01', 'Dell XPS 15', 'i7-12700H', 'RTX 3050', '32GB', '1TB NVMe', 'Good', 'John Doe'],
        'network_devices' => [1, 'R-01', 'TP-Link AX3000', '01000000000', 'Floor 2 IT Rack', 'WE', 'IT-Office-5G', 'Operational'],
        'mifis' => [1, 'M-01', 'ZTE MF927U', '01100000000', 'WE_MiFi_1', '140 GB', 'Orange', 'Available'],
        'access_points' => [1, 'AP-01', 'Ubiquiti U6 Pro', 'Port 14', 'Main Lobby'],
        'printers' => [1, 'P-01', 'HP LaserJet Pro M404n', 'Good', 'Operations Room'],
        'electronics' => [1, 'E-01', 'HDMI Switcher 4K', '4-port switcher with remote', 'Available'],
        'employees' => [1, 'Jane Smith', '+20 123 456 7890'],
        'bills' => [1, 'WE Telecom', '101', 'Landline Internet', 1500.0, 'Monthly office connection'],
        'email_accounts' => [1, 'Jane Smith', 'jane.smith@company.com', 'InitialTempPass123!'],
        'log_entries' => [1, '2026-10-05', 'Jane Smith', 'Network printer offline', 'Reconnected static IP'],
        'subscriptions' => [1, 'Figma Organization', 'Yearly', 5400.0, '2027-01-15', 'Design team license'],
        'expenses' => [1, '2026-10-05', 'Ethernet Patch Cables (10x)', 450.0, 'Cat6 3m patch cords'],
        'other_devices' => [1, 'Barcode Scanner', 'Zebra DS2208', 'DS2208-SR', 'USB handheld 2D imager'],
        'vendor_contacts' => [1, 'ISP', 'Ahmed Ali', 'WE Business', 'Account Manager', '+20100000000', 'support@isp.com', 'https://portal.isp.com', 'CID-9910', '24/7 Critical (1h)', 'Fiber SLA'],
        'wifi_networks' => [1, 'Corp-WiFi-5G', 'StrongPass#2026', '01000000000', 'Floor 1 Router', 'admin', 'AdminPass123', 'Primary office SSID'],
        'account_passwords' => [1, 'Cloudflare', 'it@company.com', 'VaultPass!99'],
        'static_ips' => [1, '192.168.1.50', '255.255.255.0', 'AA:BB:CC:DD:EE:FF', 'Core Printer HP', 'Printer', 'Operations room'],
        'borrow_logs' => [1, 'Jane Smith', 'mifi', 'ZTE MF927U', 'M-01', '2026-11-01', '2026-11-15', 'No', 'Field site visit', 'Includes charger'],
        'device_maintenance_logs' => [1, 'laptop', 1, '2026-11-01', 'Repair', 850.0, 'IT Support', 'Replaced cooling fan'],
        _ => [1, 'Sample Data 1', 'Sample Data 2'],
      };

      await ExcelService.exportTable(
        sheetName: '${def.$1.replaceAll('/', '-')} Template',
        headers: headers,
        rows: [sampleRow],
        fileLabel: '${def.$1}_Template',
      );
      if (mounted) {
        showSnack(context, 'Template for ${def.$1} generated');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(context, 'Template export failed: $e', error: true);
    }
  }

  void _showTemplatesSheet() {
    final defs = _catalogDefs;
    showFintechBottomSheet(
      context: context,
      title: 'Download Excel Import Template',
      subtitle: 'Pre-formatted spreadsheets with headers and sample data',
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: defs.length,
          itemBuilder: (ctx, i) => ListTile(
            dense: true,
            leading: IconBox(
              icon: defs[i].$3,
              color: const Color(0xFF10B981),
              size: 36,
            ),
            title: Text(
              defs[i].$1,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              '${defs[i].$4.length} columns: ${defs[i].$4.take(3).join(', ')}...',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const FintechAppBar(
        title: 'Data Hub & Backups',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
        children: [
          if (_canUndoRestore && _lastPreRestoreSnapshotPath != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.undo_rounded, color: Colors.amber),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Database was recently restored. You can undo back to the pre-restore snapshot.',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _undoLastRestore,
                    child: const Text('UNDO', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],

          // ── Daily Auto-Backup (Expensy-ported SAF + WorkManager) ──
          const SectionLabel('AUTOMATIC SCHEDULED BACKUP'),
          const _AutoBackupSection(),
          const SizedBox(height: 18),

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
                    'Generate pre-formatted Excel spreadsheets for any data category',
                onTap: _showTemplatesSheet,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Data Storage & Backups ─────────────────────────────
          const SectionLabel('MANUAL BACKUP & RESTORE'),
          FintechGroupedCard(
            title: 'Local Database Vault',
            icon: Icons.sd_card_outlined,
            children: [
              _SettingActionTile(
                icon: Icons.save_alt_rounded,
                color: theme.colorScheme.primary,
                title: 'Create Full Backup Snapshot',
                subtitle:
                    'Export encrypted (.itbox.enc) or JSON snapshot of all 23 tables & Vault files',
                onTap: _backup,
              ),
              const Divider(height: 16),
              _SettingActionTile(
                icon: Icons.checklist_rounded,
                color: const Color(0xFF0EA5E9),
                title: 'Selective Backup',
                subtitle: 'Choose specific tables and documents to back up',
                onTap: _showSelectiveBackupSheet,
              ),
              const Divider(height: 16),
              _SettingActionTile(
                icon: Icons.settings_backup_restore_rounded,
                color: Colors.orange,
                title: 'Restore Database',
                subtitle:
                    'Full or selective restore from .json / .itbox.enc backup with Undo support',
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
                title: 'Import Inventory & Directory (.xlsx)',
                subtitle:
                    'Batch import devices, staff, credentials, vendors, IPs, or tickets',
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

class _AutoBackupSection extends StatefulWidget {
  const _AutoBackupSection();

  @override
  State<_AutoBackupSection> createState() => _AutoBackupSectionState();
}

class _AutoBackupSectionState extends State<_AutoBackupSection> {
  AutoBackupState? _state;
  bool _runningNow = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final s = await AutoBackupService.loadState();
    if (mounted) {
      setState(() => _state = s);
    }
  }

  Future<void> _toggleEncryption() async {
    final st = _state;
    if (st == null) {
      return;
    }
    if (st.encrypted) {
      await AutoBackupService.setEncryption(on: false);
      await _reload();
      if (mounted) {
        showSnack(context, 'Auto-backup encryption disabled');
      }
      return;
    }

    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorText;

    final set = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Encrypt Auto-Backups'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Protect scheduled backups with AES-256-GCM. The passphrase is stored in Android Keystore.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passCtrl,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Passphrase',
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Confirm Passphrase'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (passCtrl.text.trim().length < 4) {
                  setDlgState(() => errorText = 'Minimum 4 characters');
                  return;
                }
                if (passCtrl.text != confirmCtrl.text) {
                  setDlgState(() => errorText = 'Passwords do not match');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Enable'),
            ),
          ],
        ),
      ),
    );
    final pwd = passCtrl.text.trim();
    Future.delayed(const Duration(milliseconds: 350), () {
      passCtrl.dispose();
      confirmCtrl.dispose();
    });

    if (set == true && mounted) {
      try {
        await AutoBackupService.setEncryption(on: true, password: pwd);
        await _reload();
        if (mounted) {
          showSnack(context, 'Auto-backup AES-256-GCM encryption enabled');
        }
      } catch (e) {
        if (mounted) {
          showSnack(context, 'Encryption setup failed: $e', error: true);
        }
      }
    }
  }

  Future<void> _runNow() async {
    setState(() => _runningNow = true);
    AppHaptics.tap(context, HapticStrength.medium);
    try {
      final res = await AutoBackupService.runNow(BackupTrigger.manual);
      await _reload();
      if (!mounted) {
        return;
      }
      if (res.success) {
        showSnack(context, 'Auto-backup created: ${res.fileName}');
      } else {
        showSnack(context, 'Auto-backup failed: ${res.error ?? "Unknown"}', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _runningNow = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final st = _state;
    if (st == null) {
      return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
    }

    return FintechGroupedCard(
      title: 'Daily Auto-Backup (02:00 AM)',
      icon: Icons.schedule_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Nightly SAF snapshot per organization',
                style: TextStyle(fontSize: 12.5, color: cs.onSurface.withValues(alpha: 0.7)),
              ),
            ),
            Switch.adaptive(
              value: st.enabled,
              onChanged: (val) async {
                AppHaptics.tap(context, HapticStrength.light);
                await AutoBackupService.setEnabled(val);
                await _reload();
              },
            ),
          ],
        ),
        if (st.enabled) ...[
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.folder_open_rounded, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  st.folderName.isNotEmpty ? st.folderName : 'No SAF folder selected',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () async {
                  await AutoBackupService.chooseFolder();
                  await _reload();
                },
                child: Text(st.folderName.isNotEmpty ? 'Change' : 'Choose Folder'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Keep copies:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              for (final count in const [3, 7, 14, 30])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      await AutoBackupService.setRetention(count);
                      await _reload();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: st.retention == count ? cs.primary : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: st.retention == count ? cs.onPrimary : cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    st.encrypted ? Icons.lock_rounded : Icons.lock_open_rounded,
                    size: 18,
                    color: st.encrypted ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  const Text('Encrypt with AES-256-GCM',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              Switch.adaptive(
                value: st.encrypted,
                onChanged: (_) => _toggleEncryption(),
              ),
            ],
          ),
          if (st.lastError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Last error: ${st.lastError}',
              style: TextStyle(fontSize: 11.5, color: cs.error, fontWeight: FontWeight.w600),
            ),
          ] else if (st.lastSuccessMs > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Last backup: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(st.lastSuccessMs))} (${(st.lastSize / 1024).toStringAsFixed(1)} KB)',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _runningNow ? null : _runNow,
            icon: _runningNow
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(_runningNow ? 'Backing Up...' : 'Back Up Now'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectiveBackupSheet extends StatefulWidget {
  final ValueChanged<String> onSaved;
  const _SelectiveBackupSheet({required this.onSaved});

  @override
  State<_SelectiveBackupSheet> createState() => _SelectiveBackupSheetState();
}

class _SelectiveBackupSheetState extends State<_SelectiveBackupSheet> {
  final Set<String> _selected = DatabaseHelper.allBackupTables.toSet();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final tables = DatabaseHelper.allBackupTables;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selected.length == tables.length) {
                    _selected.clear();
                  } else {
                    _selected.addAll(tables);
                  }
                });
              },
              child: Text(_selected.length == tables.length ? 'Deselect All' : 'Select All'),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: tables.length,
            itemBuilder: (_, i) {
              final t = tables[i];
              return CheckboxListTile(
                dense: true,
                title: Text(t, style: credentialFont(fontSize: 13)),
                value: _selected.contains(t),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selected.add(t);
                    } else {
                      _selected.remove(t);
                    }
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: (_selected.isEmpty || _exporting)
                ? null
                : () async {
                    setState(() => _exporting = true);
                    try {
                      final json = await DatabaseHelper().exportJson(
                        selectedTables: _selected,
                        includeVaultBinaries:
                            _selected.contains('vault_documents') ||
                            _selected.contains('expenses'),
                      );
                      final ts = DateTime.now()
                          .toString()
                          .replaceAll(RegExp(r'[: .]'), '-')
                          .substring(0, 19);
                      final saveUri = await FilePickerPlatform.instance.saveFile(
                        dialogTitle: 'Save Selective Backup',
                        fileName: 'itbox_selective_$ts.json',
                        bytes: utf8.encode(json),
                        mimeType: 'application/json',
                      );
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.pop(context);
                      if (saveUri != null) {
                        widget.onSaved('Selective backup saved (${_selected.length} tables)');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showSnack(context, 'Selective backup failed: $e', error: true);
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _exporting = false);
                      }
                    }
                  },
            icon: const Icon(Icons.save_alt_rounded),
            label: Text('Export Selected (${_selected.length})'),
          ),
        ),
      ],
    );
  }
}

class _SelectiveRestoreSheet extends StatefulWidget {
  final BackupManifestSummary summary;
  final Future<void> Function(Set<String> selectedTables) onConfirm;
  const _SelectiveRestoreSheet({required this.summary, required this.onConfirm});

  @override
  State<_SelectiveRestoreSheet> createState() => _SelectiveRestoreSheetState();
}

class _SelectiveRestoreSheetState extends State<_SelectiveRestoreSheet> {
  final Set<String> _selected = {};
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.summary.tableCounts.keys);
  }

  void _toggle(String table, bool select) {
    setState(() {
      if (select) {
        _selected.add(table);
        final deps = DatabaseHelper.restoreDependencyGroups[table] ?? const [];
        for (final dep in deps) {
          if (widget.summary.tableCounts.containsKey(dep)) {
            _selected.add(dep);
          }
        }
      } else {
        _selected.remove(table);
        for (final entry in DatabaseHelper.restoreDependencyGroups.entries) {
          if (entry.value.contains(table)) {
            _selected.remove(entry.key);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.summary.tableCounts.entries.toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (_, i) {
              final e = available[i];
              return CheckboxListTile(
                dense: true,
                title: Text(e.key, style: credentialFont(fontSize: 13)),
                subtitle: Text('${e.value} records'),
                value: _selected.contains(e.key),
                onChanged: (v) => _toggle(e.key, v == true),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: (_selected.isEmpty || _restoring)
                ? null
                : () async {
                    setState(() => _restoring = true);
                    try {
                      await widget.onConfirm(_selected);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _restoring = false);
                      }
                    }
                  },
            icon: const Icon(Icons.restore_page_outlined),
            label: Text('Restore Selected (${_selected.length})'),
          ),
        ),
      ],
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
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
