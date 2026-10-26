import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/bill.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import 'bill_form_screen.dart';

const _billColor = Color(0xFF8B5CF6); // Electric Purple

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
      title: 'Delete Bills',
      message: 'Delete ${_selectedIds.length} bill(s)?',
    );
    if (!ok || !mounted) {
      return;
    }
    for (final id in _selectedIds) {
      await _db.deleteBill(id);
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
      final bills = await _db.getBills();
      if (!mounted) {
        return;
      }
      setState(() {
        _all = bills;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
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

  void _showDetail(Bill b) {
    showFintechBottomSheet(
      context: context,
      child: _BillDetailSheet(
        bill: b,
        onEdit: () {
          Navigator.pop(context);
          _openForm(b);
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(b);
        },
      ),
    );
  }

  Future<void> _openForm([Bill? b]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BillFormScreen(bill: b)),
    );
    if (ok == true && mounted) {
      _load();
    }
  }

  Future<void> _delete(Bill b, {bool confirm = true}) async {
    bool ok = false;
    if (confirm) {
      ok = await showConfirmDialog(
        context,
        title: 'Delete Bill',
        message: 'Delete bill for ${b.number}?',
      );
    } else {
      ok = true;
    }
    if (!ok || !mounted) {
      return;
    }
    await _db.deleteBill(b.id!);
    if (!mounted) {
      return;
    }
    if (confirm) {
      showSnack(context, 'Bill deleted');
    }
    _load();
  }

  String _fmt(double v) => NumberFormat('#,##0.00').format(v);

  Color _catColor(String cat) => switch (cat) {
        'MiFis' => const Color(0xFF0EA5E9),
        '4G Internet' => const Color(0xFF10B981),
        'Landline Internet' => const Color(0xFF3B82F6),
        'Landline Phone' => const Color(0xFFF59E0B),
        'Mobile Phone' => const Color(0xFFEF4444),
        _ => _billColor,
      };

  IconData _catIcon(String cat) => switch (cat) {
        'MiFis' => Icons.wifi_tethering_rounded,
        '4G Internet' => Icons.cell_tower_rounded,
        'Landline Internet' => Icons.router_rounded,
        'Landline Phone' => Icons.phone_rounded,
        'Mobile Phone' => Icons.smartphone_rounded,
        _ => Icons.receipt_long_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSum = _filtered.fold(0.0, (s, b) => s + b.price);

    final categories = [
      null,
      'MiFis',
      '4G Internet',
      'Landline Internet',
      'Landline Phone',
      'Mobile Phone',
    ];

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Recurring Bills',
        subtitle: _filtered.isEmpty
            ? 'Fixed lines & cellular services'
            : '${_filtered.length} active bills • EGP ${_fmt(totalSum)}',
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                final isSelected = _catFilter == cat;
                final label = cat ?? 'All Bills';
                final color = cat != null ? _catColor(cat) : _billColor;

                return InkWell(
                  onTap: () => _setFilter(cat),
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

          // Total Bar
          if (_filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _billColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _billColor.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        color: _billColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      '${_filtered.length} Bill${_filtered.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Total: EGP ${_fmt(totalSum)}',
                      style: const TextStyle(
                        color: _billColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        letterSpacing: -0.2,
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
                        icon: Icons.receipt_long_rounded,
                        title: 'No Bills Logged',
                        subtitle: 'Tap + to register internet or phone bills',
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
                          final b = _filtered[i];
                          final cc = _catColor(b.category);
                          final isSelected = _selectedIds.contains(b.id);
                          return SlideInAndFade(
                            index: i,
                            child: InventoryGridCard(
                              selected: isSelected,
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(b.id!)
                                  : () => _showDetail(b),
                              onLongPress: () => _toggleSelection(b.id!),
                              leading: IconBox(
                                icon: _catIcon(b.category),
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
                                  b.category,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: cc,
                                  ),
                                ),
                              ),
                              title: 'EGP ${_fmt(b.price)}',
                              subtitle: b.number,
                              extra:
                                  b.person.isNotEmpty ? b.person : null,
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
                tooltip: 'Add Bill',
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

class _BillDetailSheet extends StatelessWidget {
  final Bill bill;
  final VoidCallback onEdit, onDelete;
  const _BillDetailSheet({
    required this.bill,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final cc = switch (bill.category) {
      'MiFis' => const Color(0xFF0EA5E9),
      '4G Internet' => const Color(0xFF10B981),
      'Landline Internet' => const Color(0xFF3B82F6),
      'Landline Phone' => const Color(0xFFF59E0B),
      'Mobile Phone' => const Color(0xFFEF4444),
      _ => const Color(0xFF8B5CF6),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cc.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: cc.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                IconBox(
                  icon: switch (bill.category) {
                    'MiFis' => Icons.wifi_tethering_rounded,
                    '4G Internet' => Icons.cell_tower_rounded,
                    'Landline Internet' => Icons.router_rounded,
                    'Landline Phone' => Icons.phone_rounded,
                    'Mobile Phone' => Icons.smartphone_rounded,
                    _ => Icons.receipt_long_rounded,
                  },
                  color: cc,
                  size: 48,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.number,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'EGP ${fmt.format(bill.price)}',
                        style: TextStyle(
                          color: cc,
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
                  label: const Text('Edit Bill'),
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
          const SectionLabel('BILL STATEMENT DETAILS'),
          FintechGroupedCard(
            children: [
              DetailRow(
                label: 'Category',
                value: bill.category,
                icon: Icons.category_rounded,
              ),
              DetailRow(
                label: 'Account / Number',
                value: bill.number,
                icon: Icons.tag_rounded,
                copyable: true,
              ),
              if (bill.person.isNotEmpty)
                DetailRow(
                  label: 'Responsible Person',
                  value: bill.person,
                  icon: Icons.person_outline_rounded,
                ),
              if (bill.notes.isNotEmpty)
                DetailRow(
                  label: 'Notes / Provider',
                  value: bill.notes,
                  icon: Icons.notes_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
