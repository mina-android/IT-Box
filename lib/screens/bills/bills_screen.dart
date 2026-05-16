import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/bill.dart';
import '../../services/theme_service.dart';
import '../../widgets/common_widgets.dart';
import '../settings/settings_screen.dart';
import 'bill_form_screen.dart';

const _billColor = Color(0xFF7C3AED);

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});
  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final _db = DatabaseHelper();
  List<Bill> _all = [];
  List<Bill> _filtered = [];
  String? _catFilter;
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
      final bills = await _db.getBills();
      if (!mounted) return;
      setState(() {
        _all = bills;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Error loading bills: $e', error: true);
    }
  }

  void _applyFilter() {
    _filtered = _catFilter == null
        ? List.from(_all)
        : _all.where((b) => b.category == _catFilter).toList();
  }

  void _setFilter(String? cat) {
    setState(() {
      _catFilter = cat;
      _applyFilter();
    });
  }

  Future<void> _openForm([Bill? b]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BillFormScreen(bill: b)),
    );
    if (ok == true && mounted) _load();
  }

  Future<void> _delete(Bill b) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Bill',
      message: 'Delete this bill?',
    );
    if (!ok || !mounted) return;
    await _db.deleteBill(b.id!);
    if (!mounted) return;
    showSnack(context, 'Bill deleted');
    _load();
  }

  String _fmt(double v) => NumberFormat('#,##0.00').format(v);

  Color _catColor(String cat) => switch (cat) {
    'MiFis'             => const Color(0xFF0EA5E9),
    '4G Internet'       => const Color(0xFF10B981),
    'Landline Internet' => const Color(0xFF3B82F6),
    'Landline Phone'    => const Color(0xFFF59E0B),
    'Mobile Phone'      => const Color(0xFFEF4444),
    _                   => _billColor,
  };

  IconData _catIcon(String cat) => switch (cat) {
    'MiFis'             => Icons.wifi_tethering_outlined,
    '4G Internet'       => Icons.cell_tower_outlined,
    'Landline Internet' => Icons.router_outlined,
    'Landline Phone'    => Icons.phone_outlined,
    'Mobile Phone'      => Icons.smartphone_outlined,
    _                   => Icons.receipt_outlined,
  };

  double get _totalShown => _filtered.fold(0.0, (s, b) => s + b.price);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(themeService: ThemeService()),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Category filter chips — use Wrap so they always fit ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _CatChip(
                  label: 'All',
                  selected: _catFilter == null,
                  onTap: () => _setFilter(null),
                ),
                ...Bill.categories.map((c) => _CatChip(
                  label: c,
                  selected: _catFilter == c,
                  color: _catColor(c),
                  onTap: () => _setFilter(_catFilter == c ? null : c),
                )),
              ],
            ),
          ),

          // ── Total bar ─────────────────────────────────────────────
          if (!_loading && _filtered.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _billColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _billColor.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.receipt_outlined, color: _billColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_filtered.length} bills',
                  style: const TextStyle(
                    color: _billColor, fontWeight: FontWeight.w600, fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  'Total: ${_fmt(_totalShown)} EGP',
                  style: const TextStyle(
                    color: _billColor, fontWeight: FontWeight.w800, fontSize: 13,
                  ),
                ),
              ]),
            ),

          // ── List / empty / loading ─────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Bills',
                        subtitle: 'Tap + to add a bill',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final b = _filtered[i];
                            final cc = _catColor(b.category);
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Icon
                                    CircleAvatar(
                                      backgroundColor: cc.withValues(alpha: 0.15),
                                      child: Icon(_catIcon(b.category),
                                          color: cc, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    // Middle
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            b.number,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(children: [
                                            // Category badge — text centered inside
                                            IntrinsicWidth(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: cc.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    b.category,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: cc,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (b.person.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  b.person,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: theme.colorScheme.onSurface
                                                        .withValues(alpha: 0.5),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ]),
                                        ],
                                      ),
                                    ),
                                    // Trailing: price + actions
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _fmt(b.price),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: cc,
                                          ),
                                        ),
                                        const Text(
                                          'EGP',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(mainAxisSize: MainAxisSize.min, children: [
                                          GestureDetector(
                                            onTap: () => _openForm(b),
                                            child: const Icon(Icons.edit_outlined,
                                                size: 16, color: Colors.grey),
                                          ),
                                          const SizedBox(width: 10),
                                          GestureDetector(
                                            onTap: () => _delete(b),
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
        label: const Text('Add Bill'),
        backgroundColor: _billColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _CatChip({
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
