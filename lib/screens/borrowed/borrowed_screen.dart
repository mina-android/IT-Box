import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/database_helper.dart';
import '../../models/borrow_log.dart';
import '../../services/notification_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import 'add_borrow_screen.dart';
import '../../services/custody_pdf_service.dart';
import 'package:signature/signature.dart';

class BorrowedScreen extends StatefulWidget {
  final bool embedded;
  const BorrowedScreen({super.key, this.embedded = false});
  @override
  State<BorrowedScreen> createState() => _BorrowedScreenState();
}

class _BorrowedScreenState extends State<BorrowedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _db = DatabaseHelper();
  List<BorrowLog> _all = [], _active = [], _history = [];
  bool _loading = true;

  String? _filterEmployee;
  bool _filterOverdueOnly = false;
  final TextEditingController _searchCtrl = TextEditingController();
  StreamSubscription<List<BorrowLog>>? _borrowSubscription;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _applyFilter());
    });
    _tabs.addListener(() {
      if (mounted && !_tabs.indexIsChanging) {
        setState(() {});
      }
    });
    _borrowSubscription = _db.watchBorrowLogs().listen((logs) {
      if (mounted) {
        setState(() {
          _all = logs;
          _applyFilter();
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _borrowSubscription?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader && _all.isEmpty) {
      setState(() => _loading = true);
    }
    _all = await _db.getBorrowLogs();
    _applyFilter();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _all.where((l) {
      if (_filterEmployee != null &&
          _filterEmployee!.isNotEmpty &&
          l.employeeName != _filterEmployee) {
        return false;
      }
      if (_filterOverdueOnly) {
        if (!l.isOverdue()) {
          return false;
        }
      }
      if (q.isNotEmpty) {
        final matchesDevice = l.deviceName.toLowerCase().contains(q);
        final matchesEmployee = l.employeeName.toLowerCase().contains(q);
        final matchesId = l.deviceId.toString().contains(q);
        if (!matchesDevice && !matchesEmployee && !matchesId) {
          return false;
        }
      }
      return true;
    }).toList();
    _active = filtered.where((l) => !l.isReturned).toList();
    _history = filtered.where((l) => l.isReturned).toList();
  }

  void _showFilterModal() {
    final employees = _all.map((l) => l.employeeName).toSet().toList()..sort();
    String? tempEmployee = _filterEmployee;
    bool tempOverdueOnly = _filterOverdueOnly;

    showFintechBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Borrow Logs',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterEmployee = null;
                        _filterOverdueOnly = false;
                        _applyFilter();
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Reset All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FintechGroupedCard(
                children: [
                  CheckboxListTile(
                    title: const Text(
                      'Overdue only',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Show devices past their due date',
                        style: TextStyle(fontSize: 12)),
                    value: tempOverdueOnly,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: Theme.of(context).colorScheme.error,
                    onChanged: (v) =>
                        setMState(() => tempOverdueOnly = v ?? false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const SectionLabel('BY EMPLOYEE'),
              if (employees.isEmpty)
                const Text('No employees with borrow records.',
                    style: TextStyle(fontSize: 12, color: Colors.grey))
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: employees.map((emp) {
                        final selected = tempEmployee == emp;
                        return FilterChip(
                          label: Text(emp),
                          selected: selected,
                          onSelected: (sel) => setMState(
                              () => tempEmployee = sel ? emp : null),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      _filterEmployee = tempEmployee;
                      _filterOverdueOnly = tempOverdueOnly;
                      _applyFilter();
                    });
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text('Apply Filter',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markReturned(BorrowLog log) async {
    final now = DateTime.now();
    final outDate = DateTime.tryParse(log.outDate) ?? now;
    final initial = now.isBefore(outDate) ? outDate : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: outDate,
      lastDate: initial.add(const Duration(days: 365)),
      helpText: 'Select Return Date',
    );
    if (picked == null || !mounted) {
      return;
    }
    await _db.markReturned(
      log.id!,
      log.deviceId,
      log.deviceType,
      DateFormat('yyyy-MM-dd').format(picked),
    );
    if (log.id != null) {
      await NotificationService().cancelReminder(log.id!);
    }
    if (!mounted) {
      return;
    }
    showSnack(context, 'Device marked as returned');
    _load(showLoader: false);
  }

  Future<void> _delete(BorrowLog log) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Record?',
      message: 'Delete borrow record for ${log.deviceName} (${log.employeeName})?',
    );
    if (!ok || !mounted) {
      return;
    }
    await _db.deleteBorrowLog(log.id!);
    if (log.id != null) {
      await NotificationService().cancelReminder(log.id!);
    }
    if (!mounted) {
      return;
    }
    showSnack(context, 'Borrow record deleted');
    _load(showLoader: false);
  }

  Future<void> _generateCustodySlip(BorrowLog log) async {
    final sigCtrl = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    // Fetch employee email / phone if available
    final emps = await _db.getEmployees();
    final emails = await _db.getEmailAccounts();
    final emp = emps.where((e) => e.name.toLowerCase() == log.employeeName.toLowerCase()).firstOrNull;
    final empEmail = emails.where((e) => e.employeeName.toLowerCase() == log.employeeName.toLowerCase()).firstOrNull?.email ?? '';

    if (!mounted) return;

    String selectedCondition = 'Good / Verified';
    final conditions = ['Good / Verified', 'Fair / Operational', 'Needs Maintenance', 'Damaged'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Custody Slip: ${log.deviceName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Issued to ${log.employeeName} (#${log.deviceNumber})',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const Divider(height: 20),
              FintechDropdown<String>(
                value: selectedCondition,
                labelText: 'Device Condition',
                items: conditions
                    .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.w600))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setS(() => selectedCondition = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign Below to Acknowledge Receipt:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Signature(
                    controller: sigCtrl,
                    height: 160,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => sigCtrl.clear(),
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('Clear Signature'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final sigBytes = sigCtrl.isNotEmpty ? await sigCtrl.toPngBytes() : null;
                        final file = await CustodyPdfService.generateCustodyPdf(
                          employeeName: log.employeeName,
                          employeePhone: emp?.phoneNumber ?? '',
                          employeeEmail: empEmail,
                          deviceType: log.deviceType,
                          deviceName: log.deviceName,
                          deviceNumber: log.deviceNumber,
                          condition: selectedCondition,
                          serialNumber: log.deviceNumber,
                          handoverDate: log.outDate,
                          dueDate: log.dueDate ?? '',
                          signatureBytes: sigBytes,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await CustodyPdfService.shareCustodyFile(file, log.employeeName, log.deviceName);
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share PDF'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final sigBytes = sigCtrl.isNotEmpty ? await sigCtrl.toPngBytes() : null;
                        final file = await CustodyPdfService.generateCustodyPdf(
                          employeeName: log.employeeName,
                          employeePhone: emp?.phoneNumber ?? '',
                          employeeEmail: empEmail,
                          deviceType: log.deviceType,
                          deviceName: log.deviceName,
                          deviceNumber: log.deviceNumber,
                          condition: selectedCondition,
                          serialNumber: log.deviceNumber,
                          handoverDate: log.outDate,
                          dueDate: log.dueDate ?? '',
                          signatureBytes: sigBytes,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await CustodyPdfService.emailCustodyDirect(
                          file: file,
                          recipientEmail: empEmail,
                          employeeName: log.employeeName,
                          device: log.deviceName,
                        );
                      },
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: const Text('Email to User'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bodyContent = Column(
      children: [
        // Segments
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SearchBar2(
                  controller: _searchCtrl,
                  hintText: 'Search device, employee or tag…',
                  noPadding: true,
                ),
              ),
              const SizedBox(width: 8),
              FintechActionButton(
                icon: Icons.tune_rounded,
                tooltip: 'Filter Borrow Logs',
                isActive: _filterEmployee != null || _filterOverdueOnly,
                activeColor: AppColors.borrowed,
                onTap: _showFilterModal,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: _BorrowSegmentCard(
                  title: 'Active Borrows',
                  count: _active.length,
                  icon: Icons.swap_horiz_rounded,
                  isSelected: _tabs.index == 0,
                  highlightColor: AppColors.borrowed,
                  onTap: () {
                    _tabs.animateTo(0);
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BorrowSegmentCard(
                  title: 'History',
                  count: _history.length,
                  icon: Icons.history_rounded,
                  isSelected: _tabs.index == 1,
                  highlightColor: AppColors.available,
                  onTap: () {
                    _tabs.animateTo(1);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),

        // Active Filter indicator if any
        if (_filterEmployee != null || _filterOverdueOnly)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list_rounded, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filtered by: ${_filterEmployee ?? ''} ${_filterOverdueOnly ? '(Overdue only)' : ''}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() {
                      _filterEmployee = null;
                      _filterOverdueOnly = false;
                      _applyFilter();
                    }),
                    child: const Icon(Icons.close_rounded, size: 16),
                  ),
                ],
              ),
            ),
          ),

        Expanded(
          child: _loading
              ? const ShimmerListLoader()
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildList(
                      logs: _active,
                      emptyIcon: Icons.swap_horiz_rounded,
                      emptyTitle: 'No Active Borrows',
                      emptySubtitle: 'All devices are currently in inventory',
                      showChart: true,
                    ),
                    _buildList(
                      logs: _history,
                      emptyIcon: Icons.history_rounded,
                      emptyTitle: 'No Return History',
                      emptySubtitle: 'Returned device records will appear here',
                      showChart: false,
                    ),
                  ],
                ),
        ),
      ],
    );

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: bodyContent,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: FintechFab(
            onPressed: () async {
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const AddBorrowScreen()),
              );
              if (ok == true && mounted) {
                _load(showLoader: false);
              }
            },
            color: Theme.of(context).colorScheme.primary,
            tooltip: 'Add Borrow',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Borrowed Devices',
        subtitle: '${_active.length} active gear borrows',
      ),
      body: bodyContent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FintechFab(
          onPressed: () async {
            final ok = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const AddBorrowScreen()),
            );
            if (ok == true && mounted) {
              _load(showLoader: false);
            }
          },
          color: Theme.of(context).colorScheme.primary,
          tooltip: 'Add Borrow',
        ),
      ),
    );
  }

  Widget _buildList({
    required List<BorrowLog> logs,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    required bool showChart,
  }) {
    if (logs.isEmpty && !showChart) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
        onRefresh: _load,
      );
    }

    return CustomScrollView(
      slivers: [
        if (showChart && _all.isNotEmpty)
          SliverToBoxAdapter(child: _BorrowStatsCard(allLogs: _all)),
        if (logs.isEmpty)
          SliverFillRemaining(
            child: EmptyState(
              icon: emptyIcon,
              title: emptyTitle,
              subtitle: emptySubtitle,
              onRefresh: _load,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BorrowCard(
                    log: logs[i],
                    onReturn: () => _markReturned(logs[i]),
                    onDelete: () => _delete(logs[i]),
                    onCustodySlip: () => _generateCustodySlip(logs[i]),
                    onEdit: () async {
                        final ok = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddBorrowScreen(logToEdit: logs[i])),
                        );
                        if (ok == true && mounted) {
                          _load(showLoader: false);
                        }
                      },
                    ),
                  ),
                  childCount: logs.length,
                ),
              ),
            ),
        ],
      );
  }
}

class _BorrowCard extends StatelessWidget {
  final BorrowLog log;
  final VoidCallback onReturn, onDelete, onEdit, onCustodySlip;
  const _BorrowCard({
    required this.log,
    required this.onReturn,
    required this.onDelete,
    required this.onEdit,
    required this.onCustodySlip,
  });

  String _fmt(String d) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final returned = log.isReturned;
    final isOverdue = log.isOverdue();

    final icon = log.deviceType == 'mifi'
        ? Icons.wifi_tethering_rounded
        : Icons.devices_other_rounded;
    final iconColor = log.deviceType == 'mifi'
        ? const Color(0xFF0EA5E9)
        : AppColors.electronicColor;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOverdue
              ? theme.colorScheme.error.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBox(icon: icon, color: iconColor, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.deviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          letterSpacing: -0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '# ${log.deviceNumber}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(returned ? 'Available' : 'Borrowed'),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _infoRow(Icons.person_rounded, 'Borrower', log.employeeName),
                  if (log.reason.isNotEmpty)
                    _infoRow(Icons.info_outline_rounded, 'Reason', log.reason),
                  _infoRow(
                      Icons.calendar_today_rounded, 'Out Date', _fmt(log.outDate)),
                  if (log.dueDate != null && log.dueDate!.isNotEmpty) ...[
                    if (isOverdue)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 14, color: theme.colorScheme.error),
                              const SizedBox(width: 6),
                              Text(
                                'OVERDUE (Due: ${_fmt(log.dueDate!)})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      _infoRow(Icons.event_busy_rounded, 'Due Date',
                          _fmt(log.dueDate!)),
                  ],
                  if (log.backDate != null && log.backDate!.isNotEmpty)
                    _infoRow(Icons.event_available_rounded, 'Returned On',
                        _fmt(log.backDate!)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!returned)
                  FilledButton.tonalIcon(
                    onPressed: onReturn,
                    icon: const Icon(Icons.keyboard_return_rounded, size: 15),
                    label: const Text('Mark Returned',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w800)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.picture_as_pdf_outlined,
                      size: 18, color: theme.colorScheme.secondary),
                  tooltip: 'Generate Custody Slip',
                  onPressed: onCustodySlip,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  tooltip: 'Edit Borrow Record',
                  onPressed: onEdit,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 18, color: theme.colorScheme.error),
                  tooltip: 'Delete Borrow Record',
                  onPressed: onDelete,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey),
          const SizedBox(width: 6),
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BorrowStatsCard extends StatelessWidget {
  final List<BorrowLog> allLogs;
  const _BorrowStatsCard({required this.allLogs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCount = allLogs.where((l) => !l.isReturned).length;
    final returnedCount = allLogs.where((l) => l.isReturned).length;
    final electronicCount =
        allLogs.where((l) => l.deviceType == 'electronic').length;
    final mifiCount = allLogs.where((l) => l.deviceType == 'mifi').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 22,
                sections: [
                  PieChartSectionData(
                    value: activeCount == 0 && returnedCount == 0
                        ? 1.0
                        : activeCount.toDouble(),
                    color: activeCount == 0 && returnedCount == 0
                        ? Colors.grey
                        : AppColors.borrowed,
                    radius: 16,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: returnedCount.toDouble(),
                    color: AppColors.available,
                    radius: 16,
                    showTitle: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Borrow Portfolio Status',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.borrowed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$activeCount Active Borrows',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.available,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$returnedCount Returned History',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Hardware: $electronicCount Electronics, $mifiCount MiFis',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BorrowSegmentCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final bool isSelected;
  final Color? highlightColor;
  final VoidCallback onTap;

  const _BorrowSegmentCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.isSelected,
    this.highlightColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = highlightColor ?? theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.14)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? activeColor
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? activeColor
                  : theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? activeColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
