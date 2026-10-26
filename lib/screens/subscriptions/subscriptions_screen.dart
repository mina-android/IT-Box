import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/subscription.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import 'subscription_form_screen.dart';

const _subColor = Color(0xFFF43F5E); // Electric Rose

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});
  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final _db = DatabaseHelper();
  List<Subscription> _all = [];
  List<Subscription> _filtered = [];
  String? _typeFilter;
  bool _loading = true;
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
      title: 'Delete Subscriptions',
      message: 'Delete ${_selectedIds.length} subscription(s)?',
    );
    if (!ok || !mounted) {
      return;
    }
    for (final id in _selectedIds) {
      await _db.deleteSubscription(id);
    }
    setState(() => _selectedIds.clear());
    _load();
  }

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbChanged);
    _load();
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChanged);
    super.dispose();
  }

  void _onDbChanged() {
    if (mounted) {
      _load(showLoader: false);
    }
  }

  Future<void> _load({bool showLoader = true}) async {
    if (!mounted) {
      return;
    }
    if (showLoader && _all.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final subs = await _db.getSubscriptions();
      if (!mounted) {
        return;
      }
      setState(() {
        _all = subs;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      showSnack(context, 'Error loading subscriptions: $e', error: true);
    }
  }

  void _applyFilter() {
    _filtered = _typeFilter == null
        ? List.from(_all)
        : _all.where((s) => s.type == _typeFilter).toList();
  }

  void _setFilter(String? type) {
    setState(() {
      _typeFilter = type;
      _applyFilter();
    });
  }

  Future<void> _openForm([Subscription? s]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionFormScreen(subscription: s),
      ),
    );
    if (ok == true && mounted) {
      _load();
    }
  }

  Future<void> _delete(Subscription s, {bool confirm = true}) async {
    bool ok;
    if (confirm) {
      ok = await showConfirmDialog(
        context,
        title: 'Delete Subscription',
        message: 'Delete "${s.service}"?',
      );
    } else {
      ok = true;
    }
    if (!ok || !mounted) {
      return;
    }
    await _db.deleteSubscription(s.id!);
    if (!mounted) {
      return;
    }
    if (confirm) {
      showSnack(context, 'Subscription deleted');
    }
    _load();
  }

  void _showDetail(Subscription s) {
    showFintechBottomSheet(
      context: context,
      child: _SubscriptionDetailSheet(
        sub: s,
        onEdit: () {
          Navigator.pop(context);
          _openForm(s);
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(s);
        },
      ),
    );
  }

  String _fmt(double v) => NumberFormat('#,##0.00').format(v);

  Color _typeColor(String type) => switch (type) {
        'Monthly' => const Color(0xFFF43F5E),
        'Yearly' => const Color(0xFF0EA5E9),
        'Weekly' => const Color(0xFF10B981),
        _ => _subColor,
      };

  IconData _typeIcon(String type) => switch (type) {
        'Monthly' => Icons.calendar_today_rounded,
        'Yearly' => Icons.event_repeat_rounded,
        'Weekly' => Icons.next_plan_rounded,
        _ => Icons.all_inclusive_rounded,
      };

  double get _totalMonthlyEquivalent =>
      _filtered.fold(0.0, (s, sub) => s + sub.monthlyEquivalent);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intervals = [null, 'Monthly', 'Yearly', 'Weekly'];

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Subscriptions',
        subtitle: _filtered.isEmpty
            ? 'Software licenses & memberships'
            : '${_filtered.length} active • EGP ${_fmt(_totalMonthlyEquivalent)}/mo',
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: intervals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final interval = intervals[i];
                final isSelected = _typeFilter == interval;
                final label = interval ?? 'All Cadences';
                final color =
                    interval != null ? _typeColor(interval) : _subColor;

                return InkWell(
                  onTap: () => _setFilter(interval),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.22),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? color
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Total Metric Card
          if (_filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _subColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _subColor.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _subColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.all_inclusive_rounded,
                          color: _subColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Monthly Burn',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '≈ EGP ${_fmt(_totalMonthlyEquivalent)} / month',
                          style: const TextStyle(
                            color: _subColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _subColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_filtered.length} active',
                        style: const TextStyle(
                          color: _subColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.all_inclusive_rounded,
                        title: 'No Subscriptions Logged',
                        subtitle:
                            'Tap + to add software or service subscriptions',
                        onRefresh: _load,
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.32,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final s = _filtered[i];
                          final cc = _typeColor(s.type);
                          final isSelected = _selectedIds.contains(s.id);
                          return SlideInAndFade(
                            index: i,
                            child: InventoryGridCard(
                              selected: isSelected,
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(s.id!)
                                  : () => _showDetail(s),
                              onLongPress: () => _toggleSelection(s.id!),
                              leading: IconBox(
                                icon: _typeIcon(s.type),
                                color: cc,
                                size: 36,
                              ),
                              badge: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: cc.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: cc.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Text(
                                  s.type,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: cc,
                                  ),
                                ),
                              ),
                              title: s.service,
                              subtitle: 'EGP ${_fmt(s.price)}',
                              extra: s.renewalDate.isNotEmpty
                                  ? 'Renews: ${s.renewalDate}'
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : SmoothExitFab(
              child: FintechFab(
                onPressed: () => _openForm(),
                color: Theme.of(context).colorScheme.primary,
                tooltip: 'Add Subscription',
              ),
            ),
      bottomNavigationBar: _isSelectionMode
          ? SelectionBottomBar(
              selectedCount: _selectedIds.length,
              onClose: () => setState(() => _selectedIds.clear()),
              onDelete: _bulkDelete,
            )
          : null,
    );
  }
}

class _SubscriptionDetailSheet extends StatelessWidget {
  final Subscription sub;
  final VoidCallback onEdit, onDelete;
  const _SubscriptionDetailSheet({
    required this.sub,
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
              color: _subColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _subColor.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const IconBox(
                  icon: Icons.all_inclusive_rounded,
                  color: _subColor,
                  size: 48,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.service,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'EGP ${fmt.format(sub.price)} / ${sub.type.toLowerCase()}',
                        style: const TextStyle(
                          color: _subColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
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
                  label: const Text('Edit Subscription'),
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
          const SectionLabel('SUBSCRIPTION SPECIFICATIONS'),
          FintechGroupedCard(
            children: [
              DetailRow(
                label: 'Billing Interval',
                value: sub.type,
                icon: Icons.repeat_rounded,
              ),
              DetailRow(
                label: 'Monthly Equivalent',
                value: '≈ EGP ${fmt.format(sub.monthlyEquivalent)} / mo',
                icon: Icons.functions_rounded,
              ),
              if (sub.renewalDate.isNotEmpty)
                DetailRow(
                  label: 'Renewal Date',
                  value: sub.renewalDate,
                  icon: Icons.event_rounded,
                  copyable: true,
                ),
              if (sub.notes.isNotEmpty)
                DetailRow(
                  label: 'Notes / Account',
                  value: sub.notes,
                  icon: Icons.notes_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
