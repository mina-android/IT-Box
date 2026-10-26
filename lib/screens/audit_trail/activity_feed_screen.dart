// lib/screens/audit_trail/activity_feed_screen.dart
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../services/audit_export_service.dart';
import '../../widgets/common_widgets.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _db.getAuditActivities(limit: 150);
    if (mounted) {
      setState(() {
        _activities = data;
        _loading = false;
      });
    }
  }

  Future<void> _exportCsv() async {
    try {
      final file = await AuditExportService().exportAuditCsv();
      if (!mounted) return;
      showSnack(context, 'Audit CSV saved to ${file.path}');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Failed to export CSV: $e', error: true);
    }
  }

  Future<void> _exportPdf() async {
    try {
      final file = await AuditExportService().exportAuditPdf();
      if (!mounted) return;
      showSnack(context, 'Audit PDF report saved to ${file.path}');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Failed to export PDF: $e', error: true);
    }
  }

  Future<void> _clearAuditTrail() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Clear Audit Trail',
      message: 'Are you sure you want to permanently clear all audit activity records? This action cannot be undone.',
      confirmText: 'Clear All',
      confirmColor: Colors.red,
    );
    if (!ok || !mounted) return;
    await _db.clearAuditActivities();
    if (mounted) {
      _load();
      showSnack(context, 'Audit trail cleared');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Audit & Activity Trail',
        subtitle: '${_activities.length} recorded events',
        actions: [
          if (_activities.isNotEmpty) ...[
            FintechCircleButton(
              icon: Icons.table_chart_rounded,
              tooltip: 'Export CSV',
              onPressed: _exportCsv,
            ),
            FintechCircleButton(
              icon: Icons.picture_as_pdf_rounded,
              tooltip: 'Export PDF Report',
              onPressed: _exportPdf,
            ),
            FintechCircleButton(
              icon: Icons.delete_sweep_rounded,
              tooltip: 'Clear Audit Trail',
              onPressed: _clearAuditTrail,
            ),
          ],
        ],
      ),
      body: _loading
          ? const ShimmerListLoader()
          : _activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 64, color: cs.primary.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'No operational activities logged yet.',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activities.length,
                  itemBuilder: (ctx, i) {
                    final a = _activities[i];
                    final action = a['action_type'] as String? ?? 'ACTION';
                    final entity = a['entity_type'] as String? ?? 'SYSTEM';
                    final desc = a['description'] as String? ?? '';
                    final ts = (a['timestamp'] as String? ?? '').replaceAll('T', ' ').split('.').first;

                    Color badgeColor;
                    if (action == 'CREATE') {
                      badgeColor = Colors.green;
                    } else if (action == 'DELETE' || action == 'OFFBOARD') {
                      badgeColor = Colors.redAccent;
                    } else if (action == 'UPDATE') {
                      badgeColor = Colors.blue;
                    } else {
                      badgeColor = Colors.amber;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                action,
                                style: TextStyle(
                                  color: badgeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    desc,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$entity • $ts',
                                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
