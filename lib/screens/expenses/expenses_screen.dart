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

  double _monthlyTotal = 0;
  double _yearlyTotal = 0;
  List<double> _monthlyTrend = List.filled(12, 0.0);
  Map<String, List<Expense>> _grouped = {};
  List<String> _monthKeys = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _availableYears = await _db.getExpenseYears();
    final now = DateTime.now().year;
    if (_selectedYear == null && _availableYears.isNotEmpty) {
      _selectedYear = _availableYears.contains(now) ? now : _availableYears.first;
    } else if (_availableYears.isEmpty) {
      _selectedYear = now;
    }
    _expenses = _selectedYear != null
      ? await _db.getExpensesByYear(_selectedYear!)
      : await _db.getExpenses();
    _compute();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadYear(int year) async {
    setState(() { _selectedYear = year; _loading = true; });
    _expenses = await _db.getExpensesByYear(year);
    _compute();
    if (mounted) setState(() => _loading = false);
  }

  void _compute() {
    final now = DateTime.now();
    final curMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final curYear = '${now.year}';
    _monthlyTotal = 0; _yearlyTotal = 0; _grouped = {};
    _monthlyTrend = List.filled(12, 0.0);

    for (final e in _expenses) {
      if (e.date.startsWith(curMonth)) _monthlyTotal += e.price;
      if (e.date.startsWith(curYear))  _yearlyTotal  += e.price;
      try {
        final d = DateTime.parse(e.date);
        if (d.year == (_selectedYear ?? now.year)) {
          _monthlyTrend[d.month - 1] += e.price;
        }
        final key = DateFormat('MMMM yyyy').format(d);
        _grouped.putIfAbsent(key, () => []).add(e);
      } catch (_) {}
    }
    _monthKeys = _grouped.keys.toList();
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

  Future<void> _openForm([Expense? e]) async {
    final ok = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => ExpenseFormScreen(expense: e)));
    if (ok == true && mounted) _load();
  }

  Future<void> _delete(Expense e) async {
    final ok = await showConfirmDialog(context, title: 'Delete Expense', message: 'Delete "${e.item}"?');
    if (!ok || !mounted) return;
    await _db.deleteExpense(e.id!);
    if (!mounted) return;
    showSnack(context, 'Expense deleted');
    _load();
  }

  String _fmt(double v) => NumberFormat('#,##0.00').format(v);
  String _fmtDate(String d) {
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(d)); } catch (_) { return d; }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allYears = {
      ..._availableYears,
      DateTime.now().year,
    }.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export Financial PDF Report',
            onPressed: _exportPdfReport,
          ),
          // Year selector
          if (allYears.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: DropdownButton<int>(
                value: _selectedYear,
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.expand_more, size: 18),
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14),
                items: allYears.map((y) => DropdownMenuItem(
                  value: y,
                  child: Text('$y', style: TextStyle(color: theme.colorScheme.onSurface)))).toList(),
                onChanged: (y) { if (y != null) _loadYear(y); },
              ),
            ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(slivers: [
              // Summary cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _SummaryCard(label: 'This Month', amount: _monthlyTotal,
                        icon: Icons.calendar_today_outlined, color: _expenseColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryCard(label: '$_selectedYear Total', amount: _yearlyTotal,
                        icon: Icons.calendar_month_outlined, color: theme.colorScheme.primary)),
                    ]),
                    if (_expenses.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _MonthlyChartCard(monthlyTrend: _monthlyTrend, year: _selectedYear ?? DateTime.now().year),
                    ],
                  ]),
                ),
              ),
              if (_expenses.isEmpty)
                const SliverFillRemaining(child: EmptyState(icon: Icons.receipt_long_outlined,
                  title: 'No Expenses', subtitle: 'Tap + to log your first expense'))
              else
                SliverList(delegate: SliverChildBuilderDelegate((_, si) {
                  final monthKey = _monthKeys[si];
                  final items = _grouped[monthKey]!;
                  final monthTotal = items.fold(0.0, (s, e) => s + e.price);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
                      child: Row(children: [
                        Expanded(child: Text(monthKey, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary, letterSpacing: 0.3))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20)),
                          child: Text('${_fmt(monthTotal)} EGP',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.primary))),
                      ]),
                    ),
                    ...items.map((e) => Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: const IconBox(icon: Icons.receipt_outlined, color: _expenseColor),
                        title: Text(e.item, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_fmtDate(e.date), style: TextStyle(fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                          if (e.details.isNotEmpty) Text(e.details, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11)),
                        ]),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(_fmt(e.price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _expenseColor)),
                          const Text('EGP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _expenseColor)),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            GestureDetector(onTap: () => _openForm(e),
                              child: const Icon(Icons.edit_outlined, size: 14, color: Colors.grey)),
                            const SizedBox(width: 8),
                            GestureDetector(onTap: () => _delete(e),
                              child: Icon(Icons.delete_outline, size: 14, color: theme.colorScheme.error)),
                          ]),
                        ]),
                      ),
                    )),
                  ]);
                }, childCount: _monthKeys.length)),
              const SliverPadding(padding: EdgeInsets.only(bottom: 90)),
            ]),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        backgroundColor: _expenseColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label; final double amount; final IconData icon; final Color color;
  const _SummaryCard({required this.label, required this.amount, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6),
        Expanded(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color), overflow: TextOverflow.ellipsis))]),
      const SizedBox(height: 8),
      Text(NumberFormat('#,##0.00').format(amount),
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
      Text('EGP', style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
    ]),
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Icon(Icons.bar_chart, size: 18, color: _expenseColor),
            const SizedBox(width: 6),
            Text('$year Monthly Trend', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
          Text('Max: ${NumberFormat('#,##0').format(maxVal)} EGP', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        ]),
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
                    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    return BarTooltipItem(
                      '${months[group.x.toInt()]}\n${NumberFormat('#,##0.00').format(rod.toY)} EGP',
                      TextStyle(color: theme.colorScheme.onInverseSurface, fontWeight: FontWeight.bold, fontSize: 11),
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
                      const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
                      final idx = value.toInt();
                      if (idx < 0 || idx >= 12) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(months[idx], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                      color: val > 0 ? _expenseColor : _expenseColor.withValues(alpha: 0.2),
                      width: 12,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ]),
    );
  }
}
