import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/borrow_log.dart';
import '../../services/theme_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import '../settings/settings_screen.dart';
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

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _all    = await _db.getBorrowLogs();
    _active = _all.where((l) => !l.isReturned).toList();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markReturned(BorrowLog log) async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: now,
      firstDate: DateTime.parse(log.outDate),
      lastDate: now.add(const Duration(days: 365)), helpText: 'Select Return Date');
    if (picked == null || !mounted) return;
    await _db.markReturned(log.id!, log.deviceId, log.deviceType,
      DateFormat('yyyy-MM-dd').format(picked));
    if (!mounted) return;
    showSnack(context, 'Device marked as returned');
    _load();
  }

  Future<void> _delete(BorrowLog log) async {
    final ok = await showConfirmDialog(context, title: 'Delete Record',
      message: 'Remove borrow record for "${log.deviceName}"?');
    if (!ok || !mounted) return;
    await _db.deleteBorrowLog(log.id!);
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
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => SettingsScreen(themeService: ThemeService())))),
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
              emptySubtitle: 'Tap + to log a borrow.', emptyIcon: Icons.check_circle_outline),
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
      required String emptySubtitle, required IconData emptyIcon}) {
    if (logs.isEmpty) return EmptyState(icon: emptyIcon, title: emptyTitle, subtitle: emptySubtitle);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 90, top: 6),
        itemCount: logs.length,
        itemBuilder: (_, i) => _BorrowCard(log: logs[i],
          onReturn: () => _markReturned(logs[i]),
          onDelete: () => _delete(logs[i])),
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
