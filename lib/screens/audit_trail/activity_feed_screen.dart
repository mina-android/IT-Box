// lib/screens/audit_trail/activity_feed_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../services/audit_export_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final TextEditingController _searchCtrl = TextEditingController();
  late final Listenable _tablesListenable;
  Timer? _debounce;

  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _filtered = [];
  DateTimeRange? _dateRange;
  bool _loading = true;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tablesListenable = _db.tables(['audit_activities']);
    _tablesListenable.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _tablesListenable.removeListener(_onChanged);
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _db.getAuditActivities(limit: 300);
    if (!mounted) {
      return;
    }
    _activities = data;
    _loading = false;
    _applyFilters();
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _activities.where((a) {
        if (_dateRange != null) {
          final tsStr = a['timestamp']?.toString() ?? '';
          final dt = DateTime.tryParse(tsStr);
          if (dt == null) {
            return false;
          }
          final day = DateTime(dt.year, dt.month, dt.day);
          final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
          final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
          if (day.isBefore(start) || day.isAfter(end)) {
            return false;
          }
        }
        if (q.isEmpty) {
          return true;
        }
        final action = (a['action_type'] ?? '').toString().toLowerCase();
        final entity = (a['entity_type'] ?? '').toString().toLowerCase();
        final desc = (a['description'] ?? '').toString().toLowerCase();
        return action.contains(q) || entity.contains(q) || desc.contains(q);
      }).toList();
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null && mounted) {
      _dateRange = picked;
      _applyFilters();
    }
  }

  Future<void> _exportCsv() async {
    try {
      await AuditExportService().exportAuditCsv();
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(context, 'Failed to export CSV: $e', error: true);
    }
  }

  Future<void> _exportPdf() async {
    try {
      await AuditExportService().exportAuditPdf();
    } catch (e) {
      if (!mounted) {
        return;
      }
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
    if (!ok || !mounted) {
      return;
    }
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Audit & Activity Trail',
        subtitle: '${_filtered.length} recorded events',
        actions: [
          FintechCircleButton(
            icon: _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
            tooltip: 'Search',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _applyFilters();
                }
              });
            },
          ),
          FintechCircleButton(
            icon: Icons.date_range_rounded,
            tooltip: 'Filter Date Range',
            iconColor: _dateRange != null ? cs.primary : null,
            onPressed: _pickDateRange,
          ),
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
              iconColor: cs.error,
              onPressed: _clearAuditTrail,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            SearchBar2(
              controller: _searchCtrl,
              hint: 'Search action, entity, or description...',
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 250), () {
                  if (mounted) {
                    _applyFilters();
                  }
                });
              },
            ),
          if (_dateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  FintechFilterPill(
                    label:
                        '${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} → ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}',
                    selected: true,
                    icon: Icons.date_range_rounded,
                    onDeleted: () {
                      _dateRange = null;
                      _applyFilters();
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.history_rounded,
                        title: 'No Audit Events',
                        subtitle: _searchCtrl.text.isNotEmpty || _dateRange != null
                            ? 'No audit activities match your current filters.'
                            : 'No operational activities logged yet.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final a = _filtered[i];
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

                          return SlideInAndFade(
                            index: i,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.cardSurface(context),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      action,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: badgeColor,
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
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: cs.onSurface.withValues(alpha: 0.55),
                                          ),
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
          ),
        ],
      ),
    );
  }
}
