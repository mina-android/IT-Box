import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/borrow_log.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import '../borrowed/add_borrow_screen.dart';
import '../borrowed/borrowed_screen.dart';
import '../subscriptions/subscriptions_screen.dart';
import '../employees/employees_screen.dart';
import '../emails/emails_screen.dart';
import '../bills/bills_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex)? onSwitchTab;
  const DashboardScreen({super.key, this.onSwitchTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseHelper();
  bool _loading = true;

  Map<String, int> _counts = {};
  double _thisMonthExpenses = 0.0;
  double _monthlySubsEquivalent = 0.0;
  List<BorrowLog> _overdueBorrows = [];
  List<BorrowLog> _recentBorrows = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final counts = await _db.getCounts();
    final expenses = await _db.getExpenses();
    final subs = await _db.getSubscriptions();
    final borrows = await _db.getBorrowLogs();

    // Calculate this month's expenses
    final now = DateTime.now();
    final prefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    double monthExp = 0.0;
    for (final e in expenses) {
      if (e.date.startsWith(prefix)) {
        monthExp += e.price;
      }
    }

    // Calculate monthly equivalent subs
    double subsEq = 0.0;
    for (final s in subs) {
      subsEq += s.monthlyEquivalent;
    }

    // Overdue borrows & active borrows
    final active = borrows.where((l) => !l.isReturned).toList();
    final overdue = active.where((l) {
      if (l.dueDate == null || l.dueDate!.isEmpty) return false;
      final due = DateTime.tryParse(l.dueDate!);
      return due != null && due.isBefore(DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0));
    }).toList();

    if (!mounted) return;
    setState(() {
      _counts = counts;
      _thisMonthExpenses = monthExp;
      _monthlySubsEquivalent = subsEq;
      _overdueBorrows = overdue;
      _recentBorrows = active.take(5).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,##0.00', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text('IT Box Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  // Overdue alert banner if any
                  if (_overdueBorrows.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle),
                          child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              '${_overdueBorrows.length} Overdue Device${_overdueBorrows.length > 1 ? 's' : ''}',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: theme.colorScheme.error),
                            ),
                            const SizedBox(height: 2),
                            const Text('Tap to review and follow up with employees.', style: TextStyle(fontSize: 12)),
                          ]),
                        ),
                        IconButton(
                          icon: Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.error),
                          onPressed: () => widget.onSwitchTab?.call(2),
                        ),
                      ]),
                    ),
                  ],

                  const SectionLabel('QUICK ACTIONS'),
                  Row(children: [
                    Expanded(
                      child: _QuickActionBtn(
                        icon: Icons.swap_horiz,
                        label: 'Borrow Device',
                        color: AppColors.borrowed,
                        onTap: () async {
                          final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddBorrowScreen()));
                          if (ok == true && mounted) _loadData();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionBtn(
                        icon: Icons.email_outlined,
                        label: 'Emails',
                        color: const Color(0xFF0EA5E9),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmailsScreen())),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionBtn(
                        icon: Icons.receipt_outlined,
                        label: 'Bills',
                        color: const Color(0xFF7C3AED),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillsScreen())),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionBtn(
                        icon: Icons.subscriptions_outlined,
                        label: 'Subscriptions',
                        color: const Color(0xFFE11D48),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsScreen())),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),
                  const SectionLabel('SUMMARY & COUNTS'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.45,
                    children: [
                      _StatCard(
                        title: 'Currently Borrowed',
                        value: '${_counts['active_borrows'] ?? 0}',
                        subtitle: _overdueBorrows.isNotEmpty ? '${_overdueBorrows.length} Overdue!' : 'Devices out',
                        icon: Icons.swap_horiz_outlined,
                        color: AppColors.borrowed,
                        alert: _overdueBorrows.isNotEmpty,
                        onTap: () => widget.onSwitchTab?.call(2),
                      ),
                      _StatCard(
                        title: 'This Month Expenses',
                        value: 'EGP ${fmt.format(_thisMonthExpenses)}',
                        subtitle: DateFormat('MMMM yyyy').format(DateTime.now()),
                        icon: Icons.receipt_long_outlined,
                        color: const Color(0xFF10B981),
                        onTap: () => widget.onSwitchTab?.call(3),
                      ),
                      _StatCard(
                        title: 'Employees',
                        value: '${_counts['employees'] ?? 0}',
                        subtitle: 'In directory',
                        icon: Icons.people_outline,
                        color: AppColors.employeeColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeesScreen())),
                      ),
                      _StatCard(
                        title: 'Subscriptions',
                        value: '${_counts['subscriptions'] ?? 0}',
                        subtitle: '≈ EGP ${fmt.format(_monthlySubsEquivalent)}/mo',
                        icon: Icons.subscriptions_outlined,
                        color: const Color(0xFFE11D48),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsScreen())),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const SectionLabel('ACTIVE BORROWED DEVICES'),
                    if (_recentBorrows.isNotEmpty)
                      TextButton(
                        onPressed: () => widget.onSwitchTab?.call(2),
                        child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                  ]),
                  if (_recentBorrows.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(children: [
                        Icon(Icons.check_circle_outline, size: 36, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                        const SizedBox(height: 8),
                        const Text('No active borrowed devices right now.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ]),
                    )
                  else
                    ..._recentBorrows.map((log) => _CompactBorrowItem(log: log, onRefresh: _loadData)),
                ],
              ),
            ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool alert;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.alert = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: alert ? theme.colorScheme.error : color.withValues(alpha: 0.3),
          width: alert ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color),
              ),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: alert ? theme.colorScheme.error : theme.colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: alert ? theme.colorScheme.error : color.withValues(alpha: 0.8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _CompactBorrowItem extends StatelessWidget {
  final BorrowLog log;
  final VoidCallback onRefresh;
  const _CompactBorrowItem({required this.log, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = log.dueDate != null && log.dueDate!.isNotEmpty && DateTime.tryParse(log.dueDate!)?.isBefore(DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)) == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: isOverdue ? theme.colorScheme.error.withValues(alpha: 0.5) : theme.colorScheme.outlineVariant.withValues(alpha: 0.4))),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: AppColors.borrowed.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.swap_horiz, color: AppColors.borrowed),
        ),
        title: Row(children: [
          Expanded(child: Text(log.deviceName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis)),
          if (isOverdue)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: theme.colorScheme.error, borderRadius: BorderRadius.circular(6)),
              child: const Text('OVERDUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
        ]),
        subtitle: Text('${log.employeeName} · Out: ${log.outDate}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BorrowedScreen())).then((_) => onRefresh()),
      ),
    );
  }
}
