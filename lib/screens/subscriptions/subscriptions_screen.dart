import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/subscription.dart';
import '../../widgets/common_widgets.dart';
import 'subscription_form_screen.dart';

const _subColor = Color(0xFFE11D48);

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final subs = await _db.getSubscriptions();
      if (!mounted) return;
      setState(() {
        _all = subs;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
      MaterialPageRoute(builder: (_) => SubscriptionFormScreen(subscription: s)),
    );
    if (ok == true && mounted) _load();
  }

  Future<void> _delete(Subscription s) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Subscription',
      message: 'Delete "${s.service}"?',
    );
    if (!ok || !mounted) return;
    await _db.deleteSubscription(s.id!);
    if (!mounted) return;
    showSnack(context, 'Subscription deleted');
    _load();
  }

  String _fmt(double v) => NumberFormat('#,##0.00').format(v);

  Color _typeColor(String type) => switch (type) {
    'Monthly' => const Color(0xFFE11D48),
    'Yearly'  => const Color(0xFF0EA5E9),
    'Weekly'  => const Color(0xFF10B981),
    _         => _subColor,
  };

  IconData _typeIcon(String type) => switch (type) {
    'Monthly' => Icons.calendar_today_outlined,
    'Yearly'  => Icons.event_repeat_outlined,
    'Weekly'  => Icons.next_plan_outlined,
    _         => Icons.subscriptions_outlined,
  };

  double get _totalMonthlyEquivalent =>
      _filtered.fold(0.0, (s, sub) => s + sub.monthlyEquivalent);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
      ),
      body: Column(
        children: [
          // ── Interval filter chips ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _TypeChip(
                  label: 'All',
                  selected: _typeFilter == null,
                  onTap: () => _setFilter(null),
                ),
                ...Subscription.types.map((t) => _TypeChip(
                  label: t,
                  selected: _typeFilter == t,
                  color: _typeColor(t),
                  onTap: () => _setFilter(_typeFilter == t ? null : t),
                )),
              ],
            ),
          ),

          // ── Total monthly spend summary bar ──
          if (!_loading && _filtered.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _subColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _subColor.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.subscriptions_outlined, color: _subColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_filtered.length} subs',
                  style: const TextStyle(
                    color: _subColor, fontWeight: FontWeight.w600, fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  'Monthly Eqv: ${_fmt(_totalMonthlyEquivalent)} EGP/mo',
                  style: const TextStyle(
                    color: _subColor, fontWeight: FontWeight.w800, fontSize: 13,
                  ),
                ),
              ]),
            ),

          // ── List / empty / loading ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.subscriptions_outlined,
                        title: 'No Subscriptions',
                        subtitle: 'Tap + to add a subscription',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final s = _filtered[i];
                            final tc = _typeColor(s.type);
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: tc.withValues(alpha: 0.15),
                                      child: Icon(_typeIcon(s.type),
                                          color: tc, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            s.service,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: tc.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                s.type,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: tc,
                                                ),
                                              ),
                                            ),
                                            if (s.renewalDate.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Icon(Icons.event_outlined, size: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                              const SizedBox(width: 3),
                                              Text(
                                                s.renewalDate,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: theme.colorScheme.onSurface
                                                      .withValues(alpha: 0.55),
                                                ),
                                              ),
                                            ],
                                          ]),
                                          if (s.notes.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              s.notes,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _fmt(s.price),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: tc,
                                          ),
                                        ),
                                        Text(
                                          'EGP / ${s.type.toLowerCase()}',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(mainAxisSize: MainAxisSize.min, children: [
                                          GestureDetector(
                                            onTap: () => _openForm(s),
                                            child: const Icon(Icons.edit_outlined,
                                                size: 16, color: Colors.grey),
                                          ),
                                          const SizedBox(width: 10),
                                          GestureDetector(
                                            onTap: () => _delete(s),
                                            child: Icon(Icons.delete_outline,
                                                size: 16,
                                                color: theme.colorScheme.error),
                                          ),
                                        ]),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Subscription'),
        backgroundColor: _subColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c : c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : c.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : c,
          ),
        ),
      ),
    );
  }
}
