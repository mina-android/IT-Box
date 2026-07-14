import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/database_helper.dart';
import '../../models/borrow_log.dart';
import '../../services/notification_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import 'add_borrow_screen.dart';

class BorrowedScreen extends StatefulWidget {
  const BorrowedScreen({super.key});
  @override
  State<BorrowedScreen> createState() => _BorrowedScreenState();
}

class _BorrowedScreenState extends State<BorrowedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _db = DatabaseHelper();
  List<BorrowLog> _all = [], _active = [];
  bool _loading = true;

  String? _filterEmployee;
  bool _filterOverdueOnly = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _all = await _db.getBorrowLogs();
    _applyFilter();
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilter() {
    final filtered = _all.where((l) {
      if (_filterEmployee != null && _filterEmployee!.isNotEmpty && l.employeeName != _filterEmployee) {
        return false;
      }
      if (_filterOverdueOnly) {
        if (l.isReturned) return false;
        if (l.dueDate == null) return false;
        final due = DateTime.tryParse(l.dueDate!);
        if (due == null || !due.isBefore(DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0))) {
          return false;
        }
      }
      return true;
    }).toList();
    _active = filtered.where((l) => !l.isReturned).toList();
  }

  void _showFilterModal() {
    final employees = _all.map((l) => l.employeeName).toSet().toList()..sort();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Filter Borrows', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              TextButton(
                onPressed: () {
                  setState(() { _filterEmployee = null; _filterOverdueOnly = false; _applyFilter(); });
                  Navigator.pop(ctx);
                },
                child: const Text('Reset All')),
            ]),
            const SizedBox(height: 12),
            const Text('By Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            CheckboxListTile(
              title: const Text('Overdue only', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              value: _filterOverdueOnly,
              dense: true,
              activeColor: Theme.of(context).colorScheme.error,
              onChanged: (v) => setMState(() => _filterOverdueOnly = v ?? false),
            ),
            const SizedBox(height: 12),
            const Text('By Employee', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            if (employees.isEmpty)
              const Text('No employees with borrow records.', style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    children: employees.map((emp) {
                      final selected = _filterEmployee == emp;
                      return FilterChip(
                        label: Text(emp),
                        selected: selected,
                        onSelected: (sel) => setMState(() => _filterEmployee = sel ? emp : null),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  setState(() => _applyFilter());
                  Navigator.pop(ctx);
                },
                child: const Text('Apply Filter'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _markReturned(BorrowLog log) async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: now,
      firstDate: DateTime.parse(log.outDate),
      lastDate: now.add(const Duration(days: 365)), helpText: 'Select Return Date');
    if (picked == null || !mounted) return;
    await _db.markReturned(log.id!, log.deviceId, log.deviceType,
      DateFormat('yyyy-MM-dd').format(picked));
    if (log.id != null) {
      await NotificationService().cancelReminder(log.id!);
    }
    if (!mounted) return;
    showSnack(context, 'Device marked as returned');
    _load();
  }

  Future<void> _delete(BorrowLog log) async {
    final ok = await showConfirmDialog(context, title: 'Delete Record',
      message: 'Remove borrow record for "${log.deviceName}"?');
    if (!ok || !mounted) return;
    await _db.deleteBorrowLog(log.id!);
    if (log.id != null) {
      await NotificationService().cancelReminder(log.id!);
    }
    if (!mounted) return;
    showSnack(context, 'Record deleted');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = _active.isNotEmpty
      ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: theme.colorScheme.error, borderRadius: BorderRadius.circular(10)),
          child: Text('${_active.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)))
      : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrowed Devices'),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.filter_list, color: (_filterEmployee != null || _filterOverdueOnly) ? theme.colorScheme.primary : null),
                if (_filterEmployee != null || _filterOverdueOnly)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(width: 8, height: 8, decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle)),
                  ),
              ],
            ),
            onPressed: _showFilterModal,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.swap_horiz_outlined, size: 17),
              const SizedBox(width: 5),
              const Text('Active'),
              if (badge != null) ...[const SizedBox(width: 5), badge],
            ])),
            const Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history_outlined, size: 17),
              SizedBox(width: 5), Text('History'),
            ])),
          ],
        ),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _buildList(_active, emptyTitle: 'No Active Borrows',
              emptySubtitle: 'Tap + to log a borrow.', emptyIcon: Icons.check_circle_outline, showChart: true),
            _buildList(_all, emptyTitle: 'No History',
              emptySubtitle: 'Borrow records will appear here.', emptyIcon: Icons.history_outlined),
          ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push<bool>(context,
            MaterialPageRoute(builder: (_) => const AddBorrowScreen()));
          if (ok == true && mounted) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Borrow'),
        backgroundColor: AppColors.borrowed,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildList(List<BorrowLog> logs, {required String emptyTitle,
      required String emptySubtitle, required IconData emptyIcon, bool showChart = false}) {
    if (logs.isEmpty && !showChart) return EmptyState(icon: emptyIcon, title: emptyTitle, subtitle: emptySubtitle);
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          if (showChart && _all.isNotEmpty)
            SliverToBoxAdapter(child: _BorrowStatsCard(allLogs: _all)),
          if (logs.isEmpty)
            SliverFillRemaining(child: EmptyState(icon: emptyIcon, title: emptyTitle, subtitle: emptySubtitle))
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 90, top: 6),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => _BorrowCard(log: logs[i],
                  onReturn: () => _markReturned(logs[i]),
                  onDelete: () => _delete(logs[i])),
                childCount: logs.length,
              )),
            ),
        ],
      ),
    );
  }
}

class _BorrowCard extends StatelessWidget {
  final BorrowLog log;
  final VoidCallback onReturn, onDelete;
  const _BorrowCard({required this.log, required this.onReturn, required this.onDelete});

  String _fmt(String d) {
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(d)); } catch (_) { return d; }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final returned = log.isReturned;
    final statusColor = returned ? AppColors.available : AppColors.borrowed;
    final icon = log.deviceType == 'mifi' ? Icons.wifi_tethering_outlined : Icons.devices_other_outlined;
    final iconColor = log.deviceType == 'mifi' ? const Color(0xFF0EA5E9) : AppColors.electronicColor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          // Header row — compact
          Row(children: [
            IconBox(icon: icon, color: iconColor, size: 34),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(log.deviceName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                overflow: TextOverflow.ellipsis),
              Text('# ${log.deviceNumber}', style: TextStyle(fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.4))),
              child: Text(returned ? 'Returned' : 'Borrowed',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor))),
          ]),
          const SizedBox(height: 6),
          // Info rows — tight
          _r(Icons.person_outline,          log.employeeName),
          _r(Icons.info_outline,            log.reason),
          _r(Icons.calendar_today_outlined, 'Out: ${_fmt(log.outDate)}'),
          if (log.dueDate != null && log.dueDate!.isNotEmpty) ...[
            if (!returned && DateTime.tryParse(log.dueDate!)?.isBefore(DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)) == true)
              Container(
                margin: const EdgeInsets.only(top: 2, bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 13, color: theme.colorScheme.error),
                  const SizedBox(width: 5),
                  Text('OVERDUE (Due: ${_fmt(log.dueDate!)})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: theme.colorScheme.error)),
                ]),
              )
            else
              _r(Icons.event_busy_outlined, 'Due: ${_fmt(log.dueDate!)}'),
          ],
          if (log.backDate != null)
            _r(Icons.event_available_outlined, 'Back: ${_fmt(log.backDate!)}'),
          // Action row
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (!returned)
              TextButton.icon(
                onPressed: onReturn,
                icon: const Icon(Icons.keyboard_return_outlined, size: 14),
                label: const Text('Mark Returned', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppColors.available,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
              onPressed: onDelete,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints()),
          ]),
        ]),
      ),
    );
  }

  Widget _r(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(children: [
      Icon(icon, size: 12, color: Colors.grey),
      const SizedBox(width: 5),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _BorrowStatsCard extends StatelessWidget {
  final List<BorrowLog> allLogs;
  const _BorrowStatsCard({required this.allLogs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCount = allLogs.where((l) => !l.isReturned).length;
    final returnedCount = allLogs.where((l) => l.isReturned).length;
    final electronicCount = allLogs.where((l) => l.deviceType == 'electronic').length;
    final mifiCount = allLogs.where((l) => l.deviceType == 'mifi').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        SizedBox(
          width: 80,
          height: 80,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 20,
              sections: [
                PieChartSectionData(
                  value: activeCount.toDouble() == 0 && returnedCount.toDouble() == 0 ? 1.0 : activeCount.toDouble(),
                  color: activeCount.toDouble() == 0 && returnedCount.toDouble() == 0 ? Colors.grey : AppColors.borrowed,
                  radius: 18,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: returnedCount.toDouble(),
                  color: AppColors.available,
                  radius: 18,
                  showTitle: false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Borrow Status Ratio', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 6),
            Row(children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.borrowed, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('$activeCount Active Out', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.available, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('$returnedCount Returned History', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Text('Types: $electronicCount Electronics, $mifiCount MiFis', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ]),
        ),
      ]),
    );
  }
}
