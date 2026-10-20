// lib/screens/maintenance/device_maintenance_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/expense.dart';
import '../../widgets/common_widgets.dart';

class DeviceMaintenanceScreen extends StatefulWidget {
  final String deviceType;
  final int deviceId;
  final String deviceName;
  final String deviceNumber;

  const DeviceMaintenanceScreen({
    super.key,
    required this.deviceType,
    required this.deviceId,
    required this.deviceName,
    required this.deviceNumber,
  });

  @override
  State<DeviceMaintenanceScreen> createState() => _DeviceMaintenanceScreenState();
}

class _DeviceMaintenanceScreenState extends State<DeviceMaintenanceScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _db.getMaintenanceLogsForDevice(widget.deviceType, widget.deviceId);
    if (mounted) {
      setState(() {
        _logs = data;
        _loading = false;
      });
    }
  }

  void _showAddLogDialog() {
    final typeCtrl = TextEditingController(text: 'Repair');
    final costCtrl = TextEditingController(text: '0.0');
    final detailsCtrl = TextEditingController();
    final technicianCtrl = TextEditingController(text: 'Internal IT');
    DateTime selectedDate = DateTime.now();
    bool addToExpenses = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Log Maintenance / Repair'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Service Type'),
                  child: DropdownButton<String>(
                    value: typeCtrl.text,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'Repair', child: Text('Hardware Repair')),
                      DropdownMenuItem(value: 'Upgrade', child: Text('Component Upgrade (RAM/SSD)')),
                      DropdownMenuItem(value: 'Maintenance', child: Text('Cleaning / Repaste / Service')),
                      DropdownMenuItem(value: 'Inspection', child: Text('Inspection / Testing')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => typeCtrl.text = v);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: costCtrl,
                  decoration: const InputDecoration(labelText: 'Cost (EGP)', prefixIcon: Icon(Icons.attach_money_rounded)),
                  keyboardType: TextInputType.number,
                  enableSuggestions: false,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: detailsCtrl,
                  decoration: const InputDecoration(labelText: 'Work Details *', hintText: 'Replaced thermal paste & cooling fan'),
                  enableSuggestions: false,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: technicianCtrl,
                  decoration: const InputDecoration(labelText: 'Performed By / Vendor', hintText: 'Internal IT / Dell Support'),
                  enableSuggestions: false,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Add cost to Department Expenses', style: TextStyle(fontSize: 12)),
                  value: addToExpenses,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onChanged: (v) => setDlgState(() => addToExpenses = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (detailsCtrl.text.trim().isEmpty) return;
                final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

                await _db.insertMaintenanceLog({
                  'device_type': widget.deviceType,
                  'device_id': widget.deviceId,
                  'date': dateStr,
                  'service_type': typeCtrl.text,
                  'cost': cost,
                  'details': detailsCtrl.text.trim(),
                  'performed_by': technicianCtrl.text.trim(),
                });

                if (addToExpenses && cost > 0) {
                  await _db.insertExpense(Expense(
                    date: dateStr,
                    item: '${typeCtrl.text}: ${widget.deviceName} (#${widget.deviceNumber})',
                    price: cost,
                    details: detailsCtrl.text.trim(),
                  ));
                }

                await _db.logAuditActivity(
                  'MAINTENANCE',
                  widget.deviceType,
                  entityId: widget.deviceId,
                  description: '${typeCtrl.text} on ${widget.deviceName} (#${widget.deviceNumber})',
                );

                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Save Record'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteLog(int id, String details) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Maintenance Record'),
        content: Text('Are you sure you want to delete this maintenance record?\n\n"$details"'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _db.deleteMaintenanceLog(id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final totalCost = _logs.fold(0.0, (sum, l) => sum + (l['cost'] as num? ?? 0.0));

    return Scaffold(
      appBar: FintechAppBar(
        title: '${widget.deviceName} — Maintenance',
      ),
      floatingActionButton: FintechFab(
        onPressed: _showAddLogDialog,
        tooltip: 'Log Service',
        icon: Icons.build_rounded,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FintechHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL MAINTENANCE EXPENSE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text('${totalCost.toStringAsFixed(2)} EGP', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('${_logs.length} Service interventions recorded for #${widget.deviceNumber}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.handyman_outlined, size: 64, color: cs.primary.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'No maintenance or repairs logged for this device.',
                              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _logs.length,
                        itemBuilder: (ctx, i) {
                          final log = _logs[i];
                          final type = log['service_type'] as String? ?? 'Service';
                          final cost = log['cost'] as num? ?? 0.0;
                          final details = log['details'] as String? ?? '';
                          final by = log['performed_by'] as String? ?? '';
                          final date = log['date'] as String? ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: cs.primaryContainer.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          type,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${cost.toStringAsFixed(2)} EGP',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          if (log['id'] != null) ...[
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: Icon(Icons.delete_outline_rounded, size: 18, color: cs.error),
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                              tooltip: 'Delete record',
                                              onPressed: () => _confirmDeleteLog(log['id'] as int, details),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(details, style: const TextStyle(fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$date • By: $by',
                                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
