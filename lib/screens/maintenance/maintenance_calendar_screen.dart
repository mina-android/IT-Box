// lib/screens/maintenance/maintenance_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../services/currency_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';

class MaintenanceCalendarScreen extends StatefulWidget {
  const MaintenanceCalendarScreen({super.key});

  @override
  State<MaintenanceCalendarScreen> createState() => _MaintenanceCalendarScreenState();
}

class _MaintenanceCalendarScreenState extends State<MaintenanceCalendarScreen> {
  final _db = DatabaseHelper();
  late final Listenable _tablesListenable;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay = DateTime.now();

  List<Map<String, dynamic>> _allLogs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tablesListenable = _db.tables(['device_maintenance_logs']);
    _tablesListenable.addListener(_onTablesChanged);
    _load();
  }

  @override
  void dispose() {
    _tablesListenable.removeListener(_onTablesChanged);
    super.dispose();
  }

  void _onTablesChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final logs = await _db.getAllMaintenanceLogs();
    if (!mounted) return;
    setState(() {
      _allLogs = logs;
      _loading = false;
    });
  }

  void _prevMonth() {
    AppHaptics.tap(context, HapticStrength.light);
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    AppHaptics.tap(context, HapticStrength.light);
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  Map<int, List<Map<String, dynamic>>> _getLogsByDayForMonth() {
    final map = <int, List<Map<String, dynamic>>>{};
    for (final log in _allLogs) {
      final dateStr = (log['is_planned'] == 1 && (log['planned_date'] as String? ?? '').isNotEmpty)
          ? log['planned_date'] as String
          : log['date'] as String? ?? '';
      try {
        final dt = DateTime.parse(dateStr);
        if (dt.year == _selectedMonth.year && dt.month == _selectedMonth.month) {
          map.putIfAbsent(dt.day, () => []).add(log);
        }
      } catch (_) {}
    }
    return map;
  }

  List<Map<String, dynamic>> _getLogsForSelectedDay() {
    if (_selectedDay == null) return const [];
    return _allLogs.where((log) {
      final dateStr = (log['is_planned'] == 1 && (log['planned_date'] as String? ?? '').isNotEmpty)
          ? log['planned_date'] as String
          : log['date'] as String? ?? '';
      try {
        final dt = DateTime.parse(dateStr);
        return dt.year == _selectedDay!.year &&
            dt.month == _selectedDay!.month &&
            dt.day == _selectedDay!.day;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final firstWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday % 7; // Sunday = 0
    final logsByDay = _getLogsByDayForMonth();
    final dayLogs = _getLogsForSelectedDay();

    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      appBar: const FintechAppBar(
        title: 'Maintenance Schedule & Calendar',
      ),
      body: _loading
          ? const ShimmerListLoader()
          : Column(
              children: [
                // Month Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: _prevMonth,
                      ),
                      Text(
                        monthName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                ),

                // Days of week header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                        .map((d) => SizedBox(
                              width: 38,
                              child: Text(
                                d,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            ))
                        .toList(),
                  ),
                ),

                // Calendar Grid
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: firstWeekday + daysInMonth,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1.1,
                    ),
                    itemBuilder: (ctx, i) {
                      if (i < firstWeekday) {
                        return const SizedBox.shrink();
                      }
                      final dayNum = i - firstWeekday + 1;
                      final currentDay = DateTime(_selectedMonth.year, _selectedMonth.month, dayNum);
                      final isSelected = _selectedDay != null &&
                          _selectedDay!.year == currentDay.year &&
                          _selectedDay!.month == currentDay.month &&
                          _selectedDay!.day == currentDay.day;
                      final isToday = DateUtils.isSameDay(currentDay, DateTime.now());
                      final dayEvents = logsByDay[dayNum] ?? [];

                      return InkWell(
                        onTap: () {
                          AppHaptics.tap(context, HapticStrength.selection);
                          setState(() => _selectedDay = currentDay);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? cs.primary
                                : (isToday ? cs.primary.withValues(alpha: 0.12) : Colors.transparent),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? cs.primary
                                  : (isToday ? cs.primary.withValues(alpha: 0.4) : Colors.transparent),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : (isToday ? cs.primary : cs.onSurface),
                                  fontSize: 13,
                                ),
                              ),
                              if (dayEvents.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white : Colors.amber.shade700,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(height: 24),

                // Selected Day Logs List
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        _selectedDay != null
                            ? DateFormat('EEEE, MMM d').format(_selectedDay!)
                            : 'Select a Day',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Spacer(),
                      Text(
                        '${dayLogs.length} events',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: dayLogs.isEmpty
                      ? Center(
                          child: Text(
                            'No maintenance or service scheduled on this date.',
                            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: dayLogs.length,
                          itemBuilder: (ctx, i) {
                            final log = dayLogs[i];
                            final type = log['service_type'] as String? ?? 'Service';
                            final details = log['details'] as String? ?? '';
                            final deviceType = log['device_type'] as String? ?? 'Device';
                            final isPlanned = log['is_planned'] == 1;
                            final cost = (log['cost'] as num? ?? 0.0).toDouble();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.cardSurface(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (isPlanned ? Colors.amber : Colors.blue).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isPlanned ? Icons.event_available_rounded : Icons.build_rounded,
                                      color: isPlanned ? Colors.amber.shade800 : Colors.blue.shade700,
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
                                                '$type • $deviceType',
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                              ),
                                            ),
                                            if (cost > 0)
                                              Text(
                                                CurrencyService().format(cost.toDouble(), decimalDigits: 0),
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                              ),
                                          ],
                                        ),
                                        if (details.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(details, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.75))),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          isPlanned ? 'Status: Planned / Scheduled' : 'Status: Completed',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isPlanned ? Colors.amber.shade800 : Colors.green.shade700,
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
                ),
              ],
            ),
    );
  }
}
