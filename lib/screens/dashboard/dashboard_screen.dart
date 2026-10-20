import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/borrow_log.dart';
import '../../models/log_entry.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import '../../services/company_service.dart';
import '../borrowed/add_borrow_screen.dart';
import '../borrowed/borrowed_screen.dart';
import '../subscriptions/subscriptions_screen.dart';
import '../employees/employees_screen.dart';
import '../expenses/expenses_screen.dart';
import '../logs/log_form_screen.dart';
import '../employees/employee_form_screen.dart';
import '../emails/email_form_screen.dart';
import '../expenses/expense_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex, {int subTab})? onSwitchTab;
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
  List<LogEntry> _recentOpenTickets = [];
  int _openTicketsCount = 0;
  int _highPriorityTicketsCount = 0;
  StreamSubscription<Map<String, int>>? _countsSub;

  @override
  void initState() {
    super.initState();
    _countsSub = _db.watchCounts().listen((counts) {
      if (mounted) {
        setState(() => _counts = counts);
      }
    });
    _db.addListener(_onDbChanged);
    _loadData();
  }

  @override
  void dispose() {
    _countsSub?.cancel();
    _db.removeListener(_onDbChanged);
    super.dispose();
  }

  void _onDbChanged() {
    if (mounted) {
      _loadData(showLoader: false);
    }
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _loading = true);
    }
    final counts = await _db.getCounts();
    final expenses = await _db.getExpenses();
    final subs = await _db.getSubscriptions();
    final borrows = await _db.getBorrowLogs();
    final logs = await _db.getLogEntries();

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
    final overdue = active.where((l) => l.isOverdue()).toList();

    // Tickets
    final openTickets =
        logs.where((l) => l.state.toLowerCase() == 'open').toList();
    final highOpen =
        openTickets.where((l) => l.priority == 'High').length;

    if (!mounted) {
      return;
    }
    setState(() {
      _counts = counts;
      _thisMonthExpenses = monthExp;
      _monthlySubsEquivalent = subsEq;
      _overdueBorrows = overdue;
      _recentBorrows = active.take(5).toList();
      _recentOpenTickets = openTickets.take(5).toList();
      _openTicketsCount = openTickets.length;
      _highPriorityTicketsCount = highOpen;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,##0.00', 'en_US');

    return Scaffold(
      appBar: FintechAppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: DateFormat('EEEE, d MMMM').format(DateTime.now()),
      ),
      body: _loading
          ? const ShimmerListLoader()
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
              children: [
                // Company Logo & Branding Banner if configured
                ListenableBuilder(
                  listenable: CompanyService(),
                  builder: (context, _) {
                    final comp = CompanyService();
                    if (!comp.hasLogo) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(comp.logoPath),
                              width: 48,
                              height: 48,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.corporate_fare_rounded, size: 36),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comp.name.isNotEmpty ? comp.name : 'Organization Fleet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'IT Operations & Infrastructure Hub',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Overdue alert banner if any
                if (_overdueBorrows.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: theme.colorScheme.error,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_overdueBorrows.length} Overdue Device${_overdueBorrows.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to review and request return.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () =>
                              widget.onSwitchTab?.call(2, subTab: 0),
                        ),
                      ],
                    ),
                  ),
                ],

                // Open Tickets alert banner if any
                if (_openTicketsCount > 0) ...[
                  _DashboardTicketBanner(
                    openCount: _openTicketsCount,
                    highPriorityCount: _highPriorityTicketsCount,
                    onTap: () => widget.onSwitchTab?.call(2, subTab: 1),
                  ),
                  const SizedBox(height: 16),
                ],

                const SectionLabel('SUMMARY & METRICS'),
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      FintechStatCard(
                        title: 'Open Tickets',
                        value: '$_openTicketsCount',
                        subtitle: _highPriorityTicketsCount > 0
                            ? '$_highPriorityTicketsCount High Priority'
                            : 'Active issues',
                        icon: Icons.confirmation_number_outlined,
                        color: const Color(0xFF6366F1),
                        alert: _highPriorityTicketsCount > 0,
                        onTap: () => widget.onSwitchTab?.call(2, subTab: 1),
                      ),
                      const SizedBox(width: 12),
                      FintechStatCard(
                        title: 'Currently Borrowed',
                        value: '${_counts['active_borrows'] ?? 0}',
                        subtitle: _overdueBorrows.isNotEmpty
                            ? '${_overdueBorrows.length} Overdue!'
                            : 'Devices out',
                        icon: Icons.swap_horiz_rounded,
                        color: AppColors.borrowed,
                        alert: _overdueBorrows.isNotEmpty,
                        onTap: () => widget.onSwitchTab?.call(2, subTab: 0),
                      ),
                      const SizedBox(width: 12),
                      FintechStatCard(
                        title: 'Month Expenses',
                        value: 'EGP ${fmt.format(_thisMonthExpenses)}',
                        subtitle:
                            DateFormat('MMMM yyyy').format(DateTime.now()),
                        icon: Icons.payments_outlined,
                        color: const Color(0xFF10B981),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ExpensesScreen(),
                          ),
                        ).then((_) => _loadData()),
                      ),
                      const SizedBox(width: 12),
                      FintechStatCard(
                        title: 'Active Employees',
                        value: '${_counts['employees'] ?? 0}',
                        subtitle: 'In directory',
                        icon: Icons.people_outline_rounded,
                        color: AppColors.employeeColor,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmployeesScreen(),
                          ),
                        ).then((_) => _loadData()),
                      ),
                      const SizedBox(width: 12),
                      FintechStatCard(
                        title: 'Subscriptions',
                        value: '${_counts['subscriptions'] ?? 0}',
                        subtitle: '≈ EGP ${fmt.format(_monthlySubsEquivalent)}/mo',
                        icon: Icons.subscriptions_outlined,
                        color: const Color(0xFFF43F5E),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionsScreen(),
                          ),
                        ).then((_) => _loadData()),
                      ),
                    ],
                  ),
                ),

                // ── Open Tickets Section ──────────────────────────
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SectionLabel('OPEN TICKETS'),
                    if (_recentOpenTickets.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            widget.onSwitchTab?.call(2, subTab: 1),
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_recentOpenTickets.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 32,
                          color: const Color(0xFF10B981).withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No open support tickets.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._recentOpenTickets.map(
                    (ticket) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FintechTicketItem(
                        ticket: ticket,
                        onTap: () => widget.onSwitchTab?.call(2, subTab: 1),
                      ),
                    ),
                  ),

                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SectionLabel('ACTIVE BORROWED DEVICES'),
                    if (_recentBorrows.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            widget.onSwitchTab?.call(2, subTab: 0),
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_recentBorrows.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 32,
                          color: const Color(0xFF10B981).withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No active borrowed devices right now.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._recentBorrows.map(
                    (log) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FintechBorrowItem(
                        log: log,
                        onRefresh: _loadData,
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FintechFab(
          onPressed: _showCreateMenu,
          color: theme.colorScheme.primary,
          tooltip: 'Add',
        ),
      ),
    );
  }

  void _showCreateMenu() {
    showFintechBottomSheet(
      context: context,
      title: 'Quick Create',
      subtitle: 'Add new record to IT operations',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CreateActionTile(
            icon: Icons.swap_horiz_rounded,
            color: AppColors.borrowed,
            title: 'New Borrow',
            subtitle: 'Issue laptop, electronic or MiFi device',
            onTap: () async {
              Navigator.pop(context);
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const AddBorrowScreen()),
              );
              if (ok == true && mounted) {
                _loadData();
              }
            },
          ),
          const SizedBox(height: 8),
          _CreateActionTile(
            icon: Icons.confirmation_number_outlined,
            color: const Color(0xFF6366F1),
            title: 'New Ticket',
            subtitle: 'Log IT support ticket or repair problem',
            onTap: () async {
              Navigator.pop(context);
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const LogFormScreen()),
              );
              if (ok == true && mounted) {
                _loadData();
              }
            },
          ),
          const SizedBox(height: 8),
          _CreateActionTile(
            icon: Icons.person_add_alt_1_rounded,
            color: const Color(0xFF0EA5E9),
            title: 'New Employee',
            subtitle: 'Register staff member in directory',
            onTap: () async {
              Navigator.pop(context);
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
              );
              if (ok == true && mounted) {
                _loadData();
              }
            },
          ),
          const SizedBox(height: 8),
          _CreateActionTile(
            icon: Icons.alternate_email_rounded,
            color: const Color(0xFF38BDF8),
            title: 'New Email Account',
            subtitle: 'Store credentials and user mailbox',
            onTap: () async {
              Navigator.pop(context);
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const EmailFormScreen()),
              );
              if (ok == true && mounted) {
                _loadData();
              }
            },
          ),
          const SizedBox(height: 8),
          _CreateActionTile(
            icon: Icons.payments_rounded,
            color: const Color(0xFF10B981),
            title: 'New Expense',
            subtitle: 'Record departmental expense receipt',
            onTap: () async {
              Navigator.pop(context);
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
              );
              if (ok == true && mounted) {
                _loadData();
              }
            },
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _CreateActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FintechBorrowItem extends StatelessWidget {
  final BorrowLog log;
  final VoidCallback onRefresh;
  const _FintechBorrowItem({required this.log, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = log.isOverdue();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOverdue
              ? theme.colorScheme.error.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BorrowedScreen()),
          ).then((_) => onRefresh()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (isOverdue ? theme.colorScheme.error : AppColors.borrowed)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    color: isOverdue ? theme.colorScheme.error : AppColors.borrowed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              log.deviceName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOverdue)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'OVERDUE',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${log.employeeName} · Out: ${log.outDate}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTicketBanner extends StatelessWidget {
  final int openCount;
  final int highPriorityCount;
  final VoidCallback onTap;

  const _DashboardTicketBanner({
    required this.openCount,
    required this.highPriorityCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = Color(0xFF6366F1);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$openCount Open Support Ticket${openCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      highPriorityCount > 0
                          ? '$highPriorityCount high priority issue${highPriorityCount > 1 ? 's' : ''} require attention.'
                          : 'Tap to view and resolve open requests.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: highPriorityCount > 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: highPriorityCount > 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: color.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FintechTicketItem extends StatelessWidget {
  final LogEntry ticket;
  final VoidCallback onTap;

  const _FintechTicketItem({
    required this.ticket,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHigh = ticket.priority.toLowerCase() == 'high';
    const accentColor = Color(0xFF6366F1);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHigh
              ? theme.colorScheme.error.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
          width: isHigh ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (isHigh ? theme.colorScheme.error : accentColor)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.confirmation_number_outlined,
                    color: isHigh ? theme.colorScheme.error : accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket.problem,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isHigh
                                  ? theme.colorScheme.error
                                  : accentColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ticket.priority.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${ticket.employeeName.isNotEmpty ? ticket.employeeName : 'Unknown'} · ${ticket.date}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
