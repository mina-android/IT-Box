// lib/screens/maintenance/device_maintenance_screen.dart
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../services/currency_service.dart';
import '../../widgets/common_widgets.dart';
import 'device_maintenance_form_screen.dart';

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

  Future<void> _openAddLogForm() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceMaintenanceFormScreen(
          deviceType: widget.deviceType,
          deviceId: widget.deviceId,
          deviceName: widget.deviceName,
          deviceNumber: widget.deviceNumber,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _load();
    }
  }

  Future<void> _confirmDeleteLog(int id, String details) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Maintenance Record',
      message: 'Are you sure you want to delete this maintenance record?\n\n"$details"',
      confirmText: 'Delete',
    );
    if (confirmed && mounted) {
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
        onPressed: _openAddLogForm,
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
                  Text(CurrencyService().format(totalCost), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
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
                          final cost = (log['cost'] as num? ?? 0.0).toDouble();
                          final details = log['details'] as String? ?? '';
                          final by = log['performed_by'] as String? ?? '';
                          final date = log['date'] as String? ?? '';
                          final isPlanned = (log['is_planned'] as int? ?? 0) == 1;

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
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
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
                                          if (isPlanned) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'PLANNED',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.amber.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            CurrencyService().format(cost),
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
