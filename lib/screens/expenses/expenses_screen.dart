import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/database_helper.dart';
import '../../models/expense.dart';
import '../../services/pdf_report_service.dart';
import '../../widgets/common_widgets.dart';
import 'expense_form_screen.dart';

const _expenseColor = Color(0xFF10B981);

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _db = DatabaseHelper();
  List<Expense> _expenses = [];
  List<int> _availableYears = [];
  int? _selectedYear;
  bool _loading = true;
  String _sortField = 'date'; // 'date' | 'price' | 'item'
  bool _sortAsc = false;
  final Set<int> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDelete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Expenses',
      message: 'Delete ${_selectedIds.length} expense(s)?',
    );
    if (!ok || !mounted) {
      return;
    }
    for (final id in _selectedIds) {
      await _db.deleteExpense(id);
    }
    setState(() => _selectedIds.clear());
    _load();
  }

  double _monthlyTotal = 0;
  double _yearlyTotal = 0;
  List<double> _monthlyTrend = List.filled(12, 0.0);
  Map<String, List<Expense>> _grouped = {};
  List<String> _monthKeys = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbChanged);
    _searchCtrl.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _compute();
    });
  }

  void _onDbChanged() {
    if (mounted) {
      _load(showLoader: false);
    }
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader && _expenses.isEmpty) {
      setState(() => _loading = true);
    }
    _availableYears = await _db.getExpenseYears();
    final now = DateTime.now().year;
    if (_selectedYear == null && _availableYears.isNotEmpty) {
      _selectedYear =
          _availableYears.contains(now) ? now : _availableYears.first;
    } else if (_availableYears.isEmpty) {
      _selectedYear = now;
    }
    _expenses = _selectedYear != null
        ? await _db.getExpensesByYear(_selectedYear!)
        : await _db.getExpenses();
    _compute();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadYear(int year) async {
    setState(() {
      _selectedYear = year;
      _loading = true;
    });
    _expenses = await _db.getExpensesByYear(year);
    _compute();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _compute() {
    final now = DateTime.now();
    final curMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final curYear = '${now.year}';
    _monthlyTotal = 0;
    _yearlyTotal = 0;
    _grouped = {};
    _monthlyTrend = List.filled(12, 0.0);

    final q = _searchCtrl.text.toLowerCase().trim();
    for (final e in _expenses) {
      if (e.date.startsWith(curMonth)) {
        _monthlyTotal += e.price;
      }
      if (e.date.startsWith(curYear)) {
        _yearlyTotal += e.price;
      }
      try {
        final d = DateTime.parse(e.date);
        if (d.year == (_selectedYear ?? now.year)) {
          _monthlyTrend[d.month - 1] += e.price;
        }

        final matchesQuery = q.isEmpty ||
            e.item.toLowerCase().contains(q) ||
            e.details.toLowerCase().contains(q) ||
            e.price.toString().contains(q);

        if (matchesQuery) {
          final key = DateFormat('MMMM yyyy').format(d);
          _grouped.putIfAbsent(key, () => []).add(e);
        }
      } catch (_) {}
    }
    _monthKeys = _grouped.keys.toList();

    // Apply sort
    for (final key in _monthKeys) {
      _grouped[key]!.sort((a, b) {
        int cmp;
        switch (_sortField) {
          case 'price':
            cmp = a.price.compareTo(b.price);
            break;
          case 'item':
            cmp = a.item.compareTo(b.item);
            break;
          default:
            cmp = a.date.compareTo(b.date);
        }
        return _sortAsc ? cmp : -cmp;
      });
    }
  }

  void _showSortSheet() {
    showFintechBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sort Expenses',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _sortAsc = !_sortAsc);
                      _compute();
                      setS(() {});
                    },
                    icon: Icon(
                      _sortAsc
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 16,
                    ),
                    label: Text(_sortAsc ? 'Ascending' : 'Descending'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FintechGroupedCard(
                children: [
                  _sortTile('date', 'Transaction Date', Icons.calendar_today_rounded, setS),
                  const Divider(height: 1),
                  _sortTile('price', 'Amount / Cost', Icons.payments_rounded, setS),
                  const Divider(height: 1),
                  _sortTile('item', 'Item Name', Icons.sort_by_alpha_rounded, setS),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortTile(String field, String label, IconData icon, StateSetter setS) {
    final theme = Theme.of(context);
    final isSelected = _sortField == field;
    return InkWell(
      onTap: () {
        setState(() {
          _sortField = field;
          _compute();
        });
        setS(() {});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdfReport() async {
    final bills = await _db.getBills();
    final subs = await _db.getSubscriptions();
    await PdfReportService.generateAndShareMonthlyReport(
      periodLabel: '${_selectedYear ?? DateTime.now().year}',
      expenses: _expenses,
      bills: bills,
      subscriptions: subs,
    );
  }

  void _showDetail(Expense e) {
    showFintechBottomSheet(
      context: context,
      child: _ExpenseDetailSheet(
        expense: e,
        onEdit: () {
          Navigator.pop(context);
          _openForm(e);
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(e);
        },
      ),
    );
  }

  Future<void> _openForm([Expense? e]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ExpenseFormScreen(expense: e)),
    );
    if (ok == true && mounted) {
      _load();
    }
  }

  Future<void> _delete(Expense e, {bool confirm = true}) async {
    bool ok = false;
    if (confirm) {
      ok = await showConfirmDialog(
        context,
        title: 'Delete Expense',
        message: 'Delete "${e.item}"?',
      );
    } else {
      ok = true;
    }
    if (!ok || !mounted) {
      return;
    }
    await _db.deleteExpense(e.id!);
    if (!mounted) {
      return;
    }
    if (confirm) {
      showSnack(context, 'Expense deleted');
    }
    _load();
  }

  String _fmt(double v) => NumberFormat('#,##0.00').format(v);
  String _fmtDate(String d) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  Widget _buildYearSelector(ThemeData theme, List<int> allYears) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          isDense: true,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          items: allYears
              .map((y) => DropdownMenuItem(
                    value: y,
                    child: Text(
                      '$y',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (y) {
            if (y != null) {
              _loadYear(y);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allYears = {
      ..._availableYears,
      DateTime.now().year,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: const FintechAppBar(
        title: 'Expenses Ledger',
        subtitle: 'Spending & departmental budget',
      ),
      body: _loading
          ? const ShimmerListLoader()
          : CustomScrollView(
              slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryCard(
                                  label: 'This Month',
                                  amount: _monthlyTotal,
                                  icon: Icons.calendar_today_rounded,
                                  color: _expenseColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SummaryCard(
                                  label: '$_selectedYear Total',
                                  amount: _yearlyTotal,
                                  icon: Icons.calendar_month_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          if (_expenses.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _MonthlyChartCard(
                              monthlyTrend: _monthlyTrend,
                              year: _selectedYear ?? DateTime.now().year,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: SearchBar2(
                              controller: _searchCtrl,
                              hint: 'Search item, details...',
                              noPadding: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FintechActionButton(
                            icon: Icons.picture_as_pdf_outlined,
                            tooltip: 'Export Financial PDF Report',
                            onTap: _exportPdfReport,
                          ),
                          if (allYears.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _buildYearSelector(theme, allYears),
                          ],
                          const SizedBox(width: 8),
                          FintechActionButton(
                            icon: Icons.tune_rounded,
                            tooltip: 'Sort Options',
                            isActive: _sortField != 'date' || _sortAsc,
                            onTap: _showSortSheet,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_expenses.isEmpty)
                    SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'No Expenses Logged',
                        subtitle: 'Tap + to record your first operational expense',
                        onRefresh: _load,
                      ),
                    )
                  else if (_monthKeys.isEmpty)
                    SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No Matching Expenses',
                        subtitle: 'No records match "${_searchCtrl.text}"',
                        onRefresh: _load,
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, si) {
                          final monthKey = _monthKeys[si];
                          final items = _grouped[monthKey]!;
                          final monthTotal =
                              items.fold(0.0, (s, e) => s + e.price);
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(6, 14, 6, 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          monthKey.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: theme.colorScheme.primary,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Text(
                                          'EGP ${_fmt(monthTotal)}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...items.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final e = entry.value;
                                  final isSelected =
                                      _selectedIds.contains(e.id);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: SlideInAndFade(
                                      index: i,
                                      child: CustomItemCard(
                                        selected: isSelected,
                                        onTap: _isSelectionMode
                                            ? () => _toggleSelection(e.id!)
                                            : () => _showDetail(e),
                                        onLongPress: () =>
                                            _toggleSelection(e.id!),
                                        leading: const IconBox(
                                          icon: Icons.payments_rounded,
                                          color: _expenseColor,
                                          size: 42,
                                        ),
                                        title: e.item,
                                        subtitle: _fmtDate(e.date),
                                        trailing: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${_fmt(e.price)} EGP',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: _expenseColor,
                                              ),
                                            ),
                                            if (e.details.isNotEmpty)
                                              SizedBox(
                                                width: 110,
                                                child: Text(
                                                  e.details,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(fontSize: 11),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                        childCount: _monthKeys.length,
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 90)),
                ],
              ),
      floatingActionButton: _isSelectionMode
          ? null
          : FintechFab(
              onPressed: () => _openForm(),
              tooltip: 'Add Expense',
              icon: Icons.add_rounded,
              color: _expenseColor,
            ),
      bottomNavigationBar: _isSelectionMode
          ? BottomAppBar(
              elevation: 4,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _selectedIds.clear()),
                  ),
                  Text(
                    '${_selectedIds.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red),
                    onPressed: _bulkDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              NumberFormat('#,##0.00').format(amount),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: color,
              ),
            ),
            Text(
              'EGP Total',
              style: TextStyle(
                fontSize: 10.5,
                color: color.withValues(alpha: 0.75),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _MonthlyChartCard extends StatelessWidget {
  final List<double> monthlyTrend;
  final int year;
  const _MonthlyChartCard({required this.monthlyTrend, required this.year});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxVal = monthlyTrend.fold(0.0, (m, v) => max(m, v));
    final maxY = (maxVal * 1.25).clamp(100.0, double.infinity);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded,
                      size: 20, color: _expenseColor),
                  const SizedBox(width: 8),
                  Text(
                    '$year Spending Cadence',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
              Text(
                'Peak: EGP ${NumberFormat('#,##0').format(maxVal)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      const months = [
                        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                      ];
                      return BarTooltipItem(
                        '${months[group.x.toInt()]}\nEGP ${NumberFormat('#,##0.00').format(rod.toY)}',
                        TextStyle(
                          color: theme.colorScheme.onInverseSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        const months = [
                          'J', 'F', 'M', 'A', 'M', 'J',
                          'J', 'A', 'S', 'O', 'N', 'D'
                        ];
                        final idx = value.toInt();
                        if (idx < 0 || idx >= 12) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            months[idx],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(12, (i) {
                  final val = monthlyTrend[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: val > 0
                            ? _expenseColor
                            : _expenseColor.withValues(alpha: 0.2),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseDetailSheet extends StatelessWidget {
  final Expense expense;
  final VoidCallback onEdit, onDelete;
  const _ExpenseDetailSheet({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,##0.00', 'en_US');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _expenseColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _expenseColor.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const IconBox(
                  icon: Icons.receipt_long_rounded,
                  color: _expenseColor,
                  size: 48,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.item,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'EGP ${fmt.format(expense.price)}',
                        style: const TextStyle(
                          color: _expenseColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Expense'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 16, color: theme.colorScheme.error),
                  label: Text('Delete',
                      style: TextStyle(color: theme.colorScheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: theme.colorScheme.error.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionLabel('EXPENSE RECEIPT DETAILS'),
          FintechGroupedCard(
            children: [
              DetailRow(
                label: 'Payment Date',
                value: expense.date,
                icon: Icons.calendar_today_rounded,
              ),
              DetailRow(
                label: 'Amount Paid',
                value: 'EGP ${fmt.format(expense.price)}',
                icon: Icons.payments_rounded,
                copyable: true,
              ),
              if (expense.details.isNotEmpty)
                DetailRow(
                  label: 'Notes / Reason',
                  value: expense.details,
                  icon: Icons.notes_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
