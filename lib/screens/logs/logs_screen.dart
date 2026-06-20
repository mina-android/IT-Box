import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/log_entry.dart';
import '../../widgets/common_widgets.dart';
import 'log_form_screen.dart';

const _logColor = Color(0xFF6366F1);

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _db = DatabaseHelper();
  final _searchCtrl = TextEditingController();

  List<LogEntry> _all = [];
  List<LogEntry> _filtered = [];
  List<int> _availableYears = [];

  // Filter state
  int? _selectedYear;
  int? _selectedMonth;        // null = all months
  String _searchMode = 'problem'; // 'problem' or 'employee'

  bool _loading = true;

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _availableYears = await _db.getLogYears();

      // Keep selected year if it still exists; default to current year
      final now = DateTime.now().year;
      if (_selectedYear == null) {
        _selectedYear = _availableYears.isNotEmpty
          ? (_availableYears.contains(now) ? now : _availableYears.first)
          : now;
      }

      await _fetchEntries();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchEntries() async {
    if (_selectedYear == null) {
      _all = await _db.getLogEntries();
    } else if (_selectedMonth != null) {
      _all = await _db.getLogEntriesByMonth(_selectedYear!, _selectedMonth!);
    } else {
      _all = await _db.getLogEntriesByYear(_selectedYear!);
    }
    _applyFilter();
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    List<LogEntry> result = List.of(_all);

    // Text search
    if (q.isNotEmpty) {
      if (_searchMode == 'employee') {
        result = result.where((e) => e.employeeName.toLowerCase().contains(q)).toList();
      } else {
        result = result.where((e) => e.problem.toLowerCase().contains(q)).toList();
      }
    }

    if (mounted) setState(() => _filtered = result);
  }

  Future<void> _openForm([LogEntry? entry]) async {
    final ok = await Navigator.push<bool>(
      context, MaterialPageRoute(builder: (_) => LogFormScreen(entry: entry)));
    if (ok == true && mounted) {
      // Re-fetch years in case a new year was added
      _availableYears = await _db.getLogYears();
      await _fetchEntries();
      setState(() {});
    }
  }

  Future<void> _delete(LogEntry e) async {
    final ok = await showConfirmDialog(context,
      title: 'Delete Log',
      message: 'Delete this log entry?');
    if (!ok || !mounted) return;
    await _db.deleteLogEntry(e.id!);
    if (!mounted) return;
    showSnack(context, 'Log deleted');
    _load();
  }

  String _fmtDate(String d) {
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(d)); } catch (_) { return d; }
  }

  // Build grouped map: "Month Year" → list
  Map<String, List<LogEntry>> _grouped() {
    final map = <String, List<LogEntry>>{};
    for (final e in _filtered) {
      try {
        final d = DateTime.parse(e.date);
        final key = DateFormat('MMMM yyyy').format(d);
        map.putIfAbsent(key, () => []).add(e);
      } catch (_) {}
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Year options: always include current year
    final allYears = {..._availableYears, DateTime.now().year}.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log'),
        actions: [
          // Year filter
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: DropdownButton<int?>(
              value: _selectedYear,
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.expand_more, size: 18),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All', style: TextStyle(color: theme.colorScheme.onSurface)),
                ),
                ...allYears.map((y) => DropdownMenuItem<int?>(
                  value: y,
                  child: Text('$y', style: TextStyle(color: theme.colorScheme.onSurface)),
                )),
              ],
              onChanged: (y) async {
                setState(() { _selectedYear = y; _selectedMonth = null; });
                await _fetchEntries();
              },
            ),
          ),
          // Month filter (only when year is selected)
          if (_selectedYear != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButton<int?>(
                value: _selectedMonth,
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.expand_more, size: 18),
                hint: Text('Month',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All months', style: TextStyle(color: theme.colorScheme.onSurface)),
                  ),
                  for (int m = 1; m <= 12; m++)
                    DropdownMenuItem<int?>(
                      value: m,
                      child: Text(_monthNames[m], style: TextStyle(color: theme.colorScheme.onSurface)),
                    ),
                ],
                onChanged: (m) async {
                  setState(() => _selectedMonth = m);
                  await _fetchEntries();
                },
              ),
            ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            // Search bar + mode toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: _searchMode == 'problem'
                        ? 'Search by problem...'
                        : 'Search by employee...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchCtrl.clear())
                        : null,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Toggle search mode
                Tooltip(
                  message: _searchMode == 'problem' ? 'Switch to employee search' : 'Switch to problem search',
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _searchMode = _searchMode == 'problem' ? 'employee' : 'problem';
                      });
                      _applyFilter();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _logColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _logColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          _searchMode == 'problem'
                            ? Icons.report_problem_outlined
                            : Icons.person_outline,
                          size: 16,
                          color: _logColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _searchMode == 'problem' ? 'Problem' : 'User',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _logColor),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            // List
            Expanded(
              child: _filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.history_outlined,
                    title: 'No Log Entries',
                    subtitle: 'Tap + to log your first IT issue')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _buildList(theme),
                  ),
            ),
          ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Log'),
        backgroundColor: _logColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    final grouped = _grouped();
    final monthKeys = grouped.keys.toList();

    return CustomScrollView(slivers: [
      SliverList(delegate: SliverChildBuilderDelegate((_, si) {
        final monthKey = monthKeys[si];
        final items = grouped[monthKey]!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
            child: Row(children: [
              Expanded(child: Text(monthKey, style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
                letterSpacing: 0.3,
              ))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${items.length} ${items.length == 1 ? 'entry' : 'entries'}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary)),
              ),
            ]),
          ),
          ...items.map((e) => _LogCard(
            entry: e,
            onEdit: () => _openForm(e),
            onDelete: () => _delete(e),
            fmtDate: _fmtDate,
          )),
        ]);
      }, childCount: monthKeys.length)),
      const SliverPadding(padding: EdgeInsets.only(bottom: 90)),
    ]);
  }
}

// ── Log Card ──────────────────────────────────────────────────────
class _LogCard extends StatelessWidget {
  final LogEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(String) fmtDate;
  const _LogCard({required this.entry, required this.onEdit, required this.onDelete, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSolution = entry.solution.isNotEmpty;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row: date + user + actions
          Row(children: [
            const IconBox(icon: Icons.history_outlined, color: _logColor),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fmtDate(entry.date),
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              if (entry.employeeName.isNotEmpty)
                Row(children: [
                  Icon(Icons.person_outline, size: 12, color: _logColor),
                  const SizedBox(width: 3),
                  Text(entry.employeeName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _logColor)),
                ]),
            ])),
            Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(onTap: onEdit,
                child: const Icon(Icons.edit_outlined, size: 16, color: Colors.grey)),
              const SizedBox(width: 12),
              GestureDetector(onTap: onDelete,
                child: Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error)),
            ]),
          ]),
          const SizedBox(height: 10),
          // Problem
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 5, right: 6),
              decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
            ),
            Expanded(child: Text(entry.problem,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          ]),
          // Solution (if any)
          if (hasSolution) ...[
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 5, right: 6),
                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
              ),
              Expanded(child: Text(entry.solution,
                style: TextStyle(fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75)))),
            ]),
          ] else ...[
            const SizedBox(height: 4),
            Text('No solution yet',
              style: TextStyle(fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                fontStyle: FontStyle.italic)),
          ],
        ]),
      ),
    );
  }
}
