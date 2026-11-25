import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/log_entry.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import '../../theme/app_theme.dart';
import 'log_form_screen.dart';

const _logColor = Color(0xFF6366F1);

class LogsScreen extends StatefulWidget {
  final bool embedded;
  final int? initialItemId;
  final int? focusRequestToken;
  const LogsScreen({
    super.key,
    this.embedded = false,
    this.initialItemId,
    this.focusRequestToken,
  });

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  Timer? _debounce;
  final _db = DatabaseHelper();
  final _searchCtrl = TextEditingController();

  List<LogEntry> _all = [];
  List<LogEntry> _filtered = [];
  List<int> _availableYears = [];

  // Filter state
  int? _selectedYear;
  int? _selectedMonth; // null = all months
  String _searchMode = 'problem'; // 'problem' or 'employee'
  String? _stateFilter; // null | 'Open' | 'Closed' | 'High'

  bool _loading = true;
  bool _handledInitial = false;
  int? _lastHandledToken;
  String _sortField = 'date'; // 'date' | 'priority' | 'state'
  bool _sortAsc = false;
  final Set<int> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;
  StreamSubscription<List<LogEntry>>? _logsSubscription;

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (_debounce?.isActive ?? false) {
        _debounce!.cancel();
      }
      _debounce = Timer(const Duration(milliseconds: 300), _applyFilter);
    });
    _load();
  }

  @override
  void dispose() {
    _logsSubscription?.cancel();
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader && _all.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      _availableYears = await _db.getLogYears();
      final now = DateTime.now().year;
      _selectedYear ??= _availableYears.isNotEmpty
          ? (_availableYears.contains(now) ? now : _availableYears.first)
          : now;

      await _fetchEntries();
      await _tryOpenInitialItem();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void didUpdateWidget(LogsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialItemId != null &&
        widget.focusRequestToken != _lastHandledToken) {
      _handledInitial = false;
      _tryOpenInitialItem();
    }
  }

  Future<void> _tryOpenInitialItem() async {
    final targetId = widget.initialItemId;
    if (targetId == null || _handledInitial) {
      return;
    }
    var match = _all.where((e) => e.id == targetId).firstOrNull;
    if (match == null) {
      final allEntries = await _db.getLogEntries();
      match = allEntries.where((e) => e.id == targetId).firstOrNull;
      if (match != null) {
        final parsedYear = DateTime.tryParse(match.date)?.year;
        if (parsedYear != null && parsedYear != _selectedYear) {
          _selectedYear = parsedYear;
          _selectedMonth = null;
          await _fetchEntries();
        }
      }
    }
    if (match != null && mounted) {
      _handledInitial = true;
      _lastHandledToken = widget.focusRequestToken;
      final target = match;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTicketDetails(target);
        }
      });
    }
  }

  Future<void> _fetchEntries() async {
    _logsSubscription?.cancel();
    _logsSubscription = _db.watchLogEntries(
      year: _selectedYear,
      month: _selectedMonth,
    ).listen((entries) {
      if (mounted) {
        setState(() {
          _all = entries;
          _applyFilter();
        });
      }
    });
    // Initial fetch to populate immediately
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

    if (q.isNotEmpty) {
      if (_searchMode == 'employee') {
        result = result.where((e) => e.employeeName.toLowerCase().contains(q)).toList();
      } else {
        result = result.where((e) => e.problem.toLowerCase().contains(q)).toList();
      }
    }

    if (_stateFilter == 'Open') {
      result = result.where((e) => e.state.toLowerCase() == 'open').toList();
    } else if (_stateFilter == 'Closed') {
      result = result
          .where((e) =>
              e.state.toLowerCase() == 'closed' ||
              e.state.toLowerCase() == 'resolved')
          .toList();
    } else if (_stateFilter == 'High') {
      result = result.where((e) => e.state.toLowerCase() == 'open' && e.priority == 'High').toList();
    }

    result.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case 'priority':
          const order = {'High': 0, 'Medium': 1, 'Low': 2};
          cmp = (order[a.priority] ?? 1).compareTo(order[b.priority] ?? 1);
          break;
        case 'state':
          cmp = a.state.compareTo(b.state);
          break;
        default:
          cmp = a.date.compareTo(b.date);
      }
      return _sortAsc ? cmp : -cmp;
    });

    if (mounted) {
      setState(() => _filtered = result);
    }
  }

  void _showFilterAndSortSheet() {
    final allYears = {..._availableYears, DateTime.now().year}.toList()
      ..sort((a, b) => b.compareTo(a));

    showFintechBottomSheet(
      context: context,
      title: 'Filter & Sort Tickets',
      subtitle: 'Organize IT support logs',
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
                  const Text('Time Period', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  TextButton(
                    onPressed: () async {
                      setState(() {
                        _selectedYear = DateTime.now().year;
                        _selectedMonth = null;
                        _sortField = 'date';
                        _sortAsc = false;
                      });
                      setS(() {});
                      await _fetchEntries();
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
                    selected: _selectedYear == null,
                    onTap: () async {
                      setState(() {
                        _selectedYear = null;
                        _selectedMonth = null;
                      });
                      setS(() {});
                      await _fetchEntries();
                    },
                  ),
                  ...allYears.map((y) => FintechFilterPill(
                        label: '$y',
                        selected: _selectedYear == y,
                        onTap: () async {
                          setState(() {
                            _selectedYear = y;
                            _selectedMonth = null;
                          });
                          setS(() {});
                          await _fetchEntries();
                        },
                      )),
                ],
              ),
              if (_selectedYear != null) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FintechFilterPill(
                      label: 'All Months',
                      selected: _selectedMonth == null,
                      onTap: () async {
                        setState(() => _selectedMonth = null);
                        setS(() {});
                        await _fetchEntries();
                      },
                    ),
                    for (int m = 1; m <= 12; m++)
                      FintechFilterPill(
                        label: _monthNames[m].substring(0, 3),
                        selected: _selectedMonth == m,
                        onTap: () async {
                          setState(() => _selectedMonth = m);
                          setS(() {});
                          await _fetchEntries();
                        },
                      ),
                  ],
                ),
              ],
              const Divider(height: 28),
              const Text('Sort Ordering', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 10),
              ...[('date', 'Date Added'), ('priority', 'Ticket Priority'), ('state', 'Current Status')].map((pair) {
                final isSelected = _sortField == pair.$1;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? _logColor.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _logColor : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(pair.$2, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                    trailing: isSelected
                        ? IconButton(
                            icon: Icon(_sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: _logColor),
                            onPressed: () {
                              setState(() => _sortAsc = !_sortAsc);
                              setS(() {});
                              _applyFilter();
                            },
                          )
                        : null,
                    onTap: () {
                      setState(() => _sortField = pair.$1);
                      setS(() {});
                      _applyFilter();
                    },
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openForm([LogEntry? entry]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LogFormScreen(entry: entry)),
    );
    if (ok == true && mounted) {
      _availableYears = await _db.getLogYears();
      await _fetchEntries();
    }
  }

  Future<void> _delete(LogEntry e) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Ticket',
      message: 'Are you sure you want to delete this IT log entry?',
    );
    if (!ok || !mounted) {
      return;
    }
    await _db.deleteLogEntry(e.id!);
    if (!mounted) {
      return;
    }
    showSnack(context, 'Ticket deleted');
    _load();
  }

  String _fmtDate(String d) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

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

  void _showTicketDetails(LogEntry entry) {
    final isClosed = entry.state.toLowerCase() == 'closed';
    final pColor = entry.priority == 'High'
        ? Colors.red
        : (entry.priority == 'Medium' ? Colors.orange : Colors.green);

    showFintechBottomSheet(
      context: context,
      title: 'Support Ticket',
      subtitle: '#${entry.id ?? 0} • ${_fmtDate(entry.date)}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                entry.state,
                color: isClosed ? Colors.green : Colors.amber.shade800,
              ),
              const SizedBox(width: 8),
              StatusBadge(
                '${entry.priority} Priority',
                color: pColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FintechGroupedCard(
            title: 'Problem Description',
            icon: Icons.report_problem_outlined,
            children: [
              Text(
                entry.problem,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, height: 1.4),
              ),
              if (entry.employeeName.isNotEmpty) ...[
                const SizedBox(height: 12),
                DetailRow(
                  label: 'Reported By',
                  value: entry.employeeName,
                  icon: Icons.person_outline,
                ),
              ],
            ],
          ),
          if (entry.solution.isNotEmpty) ...[
            const SizedBox(height: 14),
            FintechGroupedCard(
              title: 'Resolution Details',
              icon: Icons.check_circle_outline,
              children: [
                Text(
                  entry.solution,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _delete(entry);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openForm(entry);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _logColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final openTickets = _all.where((e) => e.state.toLowerCase() == 'open').toList();
    final closedTickets = _all.where((e) => e.state.toLowerCase() == 'closed').toList();
    final highPriorityOpen = openTickets.where((e) => e.priority == 'High').length;
    final hasActiveFilterOrSort = _selectedMonth != null || _selectedYear != DateTime.now().year || _sortField != 'date' || _sortAsc;

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SearchBar2(
                  controller: _searchCtrl,
                  hintText: _searchMode == 'problem' ? 'Search problem description…' : 'Search requester employee…',
                  noPadding: true,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: _searchMode == 'problem' ? 'Switch to user search' : 'Switch to problem search',
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _searchMode = _searchMode == 'problem' ? 'employee' : 'problem';
                    });
                    _applyFilter();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _logColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _logColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _searchMode == 'problem' ? Icons.report_problem_rounded : Icons.person_rounded,
                          size: 16,
                          color: _logColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _searchMode == 'problem' ? 'Issue' : 'User',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _logColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FintechActionButton(
                icon: Icons.tune_rounded,
                tooltip: 'Filter & Sort Tickets',
                isActive: hasActiveFilterOrSort,
                activeColor: _logColor,
                onTap: _showFilterAndSortSheet,
              ),
            ],
          ),
        ),
        if (_all.isNotEmpty)
          _TicketDashboardCard(
            total: _all.length,
            openCount: openTickets.length,
            closedCount: closedTickets.length,
            highPriorityOpen: highPriorityOpen,
            activeFilter: _stateFilter,
            onFilterChanged: (f) {
              setState(() {
                _stateFilter = f;
                _applyFilter();
              });
            },
          ),
        const SizedBox(height: 4),
        Expanded(
          child: _filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.confirmation_number_outlined,
                  title: 'No IT Tickets Found',
                  subtitle: 'Tap + to report or log an IT support ticket',
                )
              : _buildList(theme),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: widget.embedded ? Colors.transparent : null,
      appBar: widget.embedded
          ? null
          : FintechAppBar(
              title: 'Tickets',
              subtitle: '${_filtered.length} logged tickets',
            ),
      body: _loading ? const ShimmerListLoader() : content,
      bottomNavigationBar: _isSelectionMode
          ? SelectionBottomBar(
              selectedCount: _selectedIds.length,
              totalCount: _filtered.length,
              onSelectAll: () {
                setState(() {
                  _selectedIds.addAll(_filtered.where((e) => e.id != null).map((e) => e.id!));
                });
              },
              onDeselectAll: () => setState(() => _selectedIds.clear()),
              onClose: () => setState(() => _selectedIds.clear()),
              onDelete: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Delete Tickets',
                  message: 'Delete ${_selectedIds.length} ticket log(s)?',
                );
                if (!ok || !mounted) return;
                for (final id in _selectedIds) {
                  await _db.deleteLogEntry(id);
                }
                setState(() => _selectedIds.clear());
                _load();
              },
            )
          : null,
      floatingActionButton: _isSelectionMode
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: widget.embedded ? 80 : 0),
              child: FintechFab(
                onPressed: () => _openForm(),
                tooltip: 'Add Ticket',
                icon: Icons.add_rounded,
              ),
            ),
    );
  }

  Widget _buildList(ThemeData theme) {
    final grouped = _grouped();
    final monthKeys = grouped.keys.toList();

    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate((_, si) {
            final monthKey = monthKeys[si];
            final items = grouped[monthKey]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          monthKey,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${items.length} ${items.length == 1 ? 'ticket' : 'tickets'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...items.asMap().entries.map((kv) {
                  final i = kv.key;
                  final e = kv.value;
                  final isSelected = _selectedIds.contains(e.id);
                  return SlideInAndFade(
                    index: i,
                    child: _LogCard(
                      entry: e,
                      theme: theme,
                      isSelected: isSelected,
                      onTap: _isSelectionMode
                          ? () => _toggleSelection(e.id!)
                          : () => _showTicketDetails(e),
                      onLongPress: () => _toggleSelection(e.id!),
                      onEdit: () => _openForm(e),
                      onDelete: () => _delete(e),
                      fmtDate: _fmtDate,
                    ),
                  );
                }),
              ],
            );
          }, childCount: monthKeys.length),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  final LogEntry entry;
  final ThemeData theme;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(String) fmtDate;

  const _LogCard({
    required this.entry,
    required this.theme,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
    required this.fmtDate,
  });

  Color _priorityColor() {
    switch (entry.priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final isClosed = entry.state.toLowerCase() == 'closed';
    final pColor = _priorityColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected
            ? _logColor.withValues(alpha: 0.08)
            : (isDark ? AppColors.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? _logColor
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (isClosed ? Colors.green : pColor).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isClosed ? Icons.check_circle_rounded : Icons.report_problem_rounded,
                  color: isClosed ? Colors.green : pColor,
                  size: 20,
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
                            entry.problem,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              decoration: isClosed ? TextDecoration.lineThrough : null,
                              color: isClosed ? theme.colorScheme.onSurface.withValues(alpha: 0.5) : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          entry.priority,
                          color: pColor,
                        ),
                      ],
                    ),
                    if (entry.employeeName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 12, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            entry.employeeName,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (entry.solution.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Resolution: ${entry.solution}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          fmtDate(entry.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        StatusBadge(
                          entry.state,
                          color: isClosed ? Colors.green : Colors.amber.shade800,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketDashboardCard extends StatelessWidget {
  final int total;
  final int openCount;
  final int closedCount;
  final int highPriorityOpen;
  final String? activeFilter;
  final ValueChanged<String?> onFilterChanged;

  const _TicketDashboardCard({
    required this.total,
    required this.openCount,
    required this.closedCount,
    required this.highPriorityOpen,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rate = total > 0 ? (closedCount / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _logColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.confirmation_number_outlined, color: _logColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Ticket Resolution Rate',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
              Text(
                '${(rate * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: rate >= 0.7 ? const Color(0xFF10B981) : _logColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(rate >= 0.7 ? const Color(0xFF10B981) : _logColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TicketMetricPill(
                  label: 'Open',
                  count: openCount,
                  color: const Color(0xFFF59E0B),
                  isSelected: activeFilter == 'Open',
                  onTap: () => onFilterChanged(activeFilter == 'Open' ? null : 'Open'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TicketMetricPill(
                  label: 'High Alert',
                  count: highPriorityOpen,
                  color: const Color(0xFFEF4444),
                  isSelected: activeFilter == 'High',
                  onTap: () => onFilterChanged(activeFilter == 'High' ? null : 'High'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TicketMetricPill(
                  label: 'Resolved',
                  count: closedCount,
                  color: const Color(0xFF10B981),
                  isSelected: activeFilter == 'Closed',
                  onTap: () => onFilterChanged(activeFilter == 'Closed' ? null : 'Closed'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketMetricPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TicketMetricPill({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}