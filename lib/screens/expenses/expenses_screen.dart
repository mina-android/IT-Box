import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/database_helper.dart';
import '../../models/expense.dart';
import '../../services/currency_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import '../documents_vault/document_viewer_screen.dart';
import 'expense_form_screen.dart';

const _expenseColor = Color(0xFF10B981);

class ExpensesScreen extends StatefulWidget {
  final int? initialItemId;
  const ExpensesScreen({super.key, this.initialItemId});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _db = DatabaseHelper();
  List<Expense> _expenses = [];
  List<int> _availableYears = [];
  int? _selectedYear;
  bool _initializedYear = false;
  bool _loading = true;
  bool _showSearch = false;
  bool _handledInitial = false;
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
    if (!_initializedYear) {
      _initializedYear = true;
      if (_availableYears.isNotEmpty) {
        _selectedYear =
            _availableYears.contains(now) ? now : _availableYears.first;
      } else {
        _selectedYear = now;
      }
    }
    _expenses = _selectedYear != null
        ? await _db.getExpensesByYear(_selectedYear!)
        : await _db.getExpenses();

    if (!_handledInitial && widget.initialItemId != null) {
      var match = _expenses.where((e) => e.id == widget.initialItemId).firstOrNull;
      if (match == null) {
        final all = await _db.getExpenses();
        match = all.where((e) => e.id == widget.initialItemId).firstOrNull;
        if (match != null) {
          final parsedYear = DateTime.tryParse(match.date)?.year;
          if (parsedYear != null) {
            _selectedYear = parsedYear;
            _expenses = await _db.getExpensesByYear(parsedYear);
          } else {
            _selectedYear = null;
            _expenses = all;
          }
        }
      }
      if (match != null) {
        _handledInitial = true;
        final target = match;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showDetail(target);
          }
        });
      }
    }

    _compute();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadYear(int? year) async {
    setState(() {
      _selectedYear = year;
      _loading = true;
    });
    _expenses = year != null
        ? await _db.getExpensesByYear(year)
        : await _db.getExpenses();
    _compute();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _compute() {
    final now = DateTime.now();
    final curMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final selectedYearStr = '${_selectedYear ?? now.year}';
    _monthlyTotal = 0;
    _yearlyTotal = 0;
    _grouped = {};
    _monthlyTrend = List.filled(12, 0.0);

    final q = _searchCtrl.text.toLowerCase().trim();
    for (final e in _expenses) {
      if (e.date.startsWith(curMonth)) {
        _monthlyTotal += e.price;
      }
      if (_selectedYear == null || e.date.startsWith(selectedYearStr)) {
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

  void _showFilterAndSortSheet() {
    final allYears = {..._availableYears, DateTime.now().year}.toList()
      ..sort((a, b) => b.compareTo(a));

    showFintechBottomSheet(
      context: context,
      title: 'Filter & Sort Expenses',
      subtitle: 'Organize spending & departmental budget',
      child: StatefulBuilder(
        builder: (ctx, setS) {
          final theme = Theme.of(ctx);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Time Period',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: () async {
                      setState(() {
                        _sortField = 'date';
                        _sortAsc = false;
                      });
                      await _loadYear(DateTime.now().year);
                      setS(() {});
                    },
                    child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FintechFilterPill(
                    label: 'All Years',
                    color: _expenseColor,
                    selected: _selectedYear == null,
                    onTap: () async {
                      await _loadYear(null);
                      setS(() {});
                    },
                  ),
                  ...allYears.map((y) => FintechFilterPill(
                        label: '$y',
                        color: _expenseColor,
                        selected: _selectedYear == y,
                        onTap: () async {
                          await _loadYear(y);
                          setS(() {});
                        },
                      )),
                ],
              ),
              const Divider(height: 28),
              const Text(
                'Sort Ordering',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 10),
              for (final pair in const [
                ('date', 'Transaction Date'),
                ('price', 'Amount / Cost'),
                ('item', 'Item Name'),
              ])
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: _sortField == pair.$1
                        ? _expenseColor.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _sortField == pair.$1
                          ? _expenseColor
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      pair.$2,
                      style: TextStyle(
                        fontWeight: _sortField == pair.$1
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: _sortField == pair.$1
                        ? IconButton(
                            icon: Icon(
                              _sortAsc
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: _expenseColor,
                            ),
                            tooltip: _sortAsc ? 'Ascending' : 'Descending',
                            onPressed: () {
                              setState(() {
                                _sortAsc = !_sortAsc;
                                _compute();
                              });
                              setS(() {});
                            },
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _sortField = pair.$1;
                        _compute();
                      });
                      setS(() {});
                    },
                  ),
                ),
            ],
          );
        },
      ),
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

  String _fmtDate(String d) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveFilter =
        _selectedYear != DateTime.now().year || _sortField != 'date' || _sortAsc;

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Expenses Ledger',
        subtitle: 'Spending & departmental budget',
        actions: [
          FintechCircleButton(
            icon: _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
            tooltip: 'Search',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                }
              });
            },
          ),
          FintechCircleButton(
            icon: Icons.tune_rounded,
            tooltip: 'Filter & Sort',
            iconColor: hasActiveFilter ? theme.colorScheme.primary : null,
            onPressed: _showFilterAndSortSheet,
          ),
        ],
      ),
      body: _loading
          ? const ShimmerListLoader()
          : CustomScrollView(
              slivers: [
                  if (_showSearch)
                    SliverToBoxAdapter(
                      child: SearchBar2(
                        controller: _searchCtrl,
                        hint: 'Search item, details...',
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryCard(
                                  label: (_selectedYear == null || _selectedYear == DateTime.now().year)
                                      ? 'This Month'
                                      : 'Monthly Avg',
                                  amount: (_selectedYear == null || _selectedYear == DateTime.now().year)
                                      ? _monthlyTotal
                                      : (_yearlyTotal / 12),
                                  icon: Icons.calendar_today_rounded,
                                  color: _expenseColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SummaryCard(
                                  label: _selectedYear != null
                                      ? '$_selectedYear Total'
                                      : 'All-Time Total',
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
                  if (_expenses.isEmpty)
                    const SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'No Expenses Logged',
                        subtitle: 'Tap + to record your first operational expense',
                      ),
                    )
                  else if (_monthKeys.isEmpty)
                    SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No Matching Expenses',
                        subtitle: 'No records match "${_searchCtrl.text}"',
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
                                          CurrencyService().format(monthTotal),
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
                                              CurrencyService().format(e.price),
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
          : SmoothExitFab(
              child: FintechFab(
                onPressed: () => _openForm(),
                tooltip: 'Add Expense',
                icon: Icons.add_rounded,
                color: _expenseColor,
              ),
            ),
      bottomNavigationBar: _isSelectionMode
          ? SelectionBottomBar(
              selectedCount: _selectedIds.length,
              totalCount: _grouped.values.fold<int>(0, (sum, list) => sum + list.length),
              onSelectAll: () {
                setState(() {
                  for (final list in _grouped.values) {
                    _selectedIds.addAll(list.where((e) => e.id != null).map((e) => e.id!));
                  }
                });
              },
              onDeselectAll: () => setState(() => _selectedIds.clear()),
              onClose: () => setState(() => _selectedIds.clear()),
              onDelete: _bulkDelete,
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
              '${CurrencyService().currency} Total',
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
                'Peak: ${CurrencyService().format(maxVal, decimalDigits: 0)}',
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
                        '${months[group.x.toInt()]}\n${CurrencyService().format(rod.toY)}',
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
                        CurrencyService().format(expense.price),
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
                value: CurrencyService().format(expense.price),
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
          if (expense.receiptPath.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentViewerScreen(
                        title: 'Receipt • ${expense.item}',
                        filePath: expense.receiptPath,
                        isPdf: expense.receiptPath.toLowerCase().endsWith('.pdf'),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('View Attached Receipt'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
