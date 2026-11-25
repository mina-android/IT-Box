import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import '../../database/database_helper.dart';
import '../../models/laptop.dart';
import '../../models/employee.dart';
import '../../services/custody_pdf_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import 'laptop_form_screen.dart';
import '../maintenance/device_maintenance_screen.dart';

class LaptopsScreen extends StatefulWidget {
  final int? initialItemId;
  const LaptopsScreen({super.key, this.initialItemId});
  @override
  State<LaptopsScreen> createState() => _LaptopsScreenState();
}

class _LaptopsScreenState extends State<LaptopsScreen> with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper();
  StreamSubscription<List<Laptop>>? _sub;
  final _search = TextEditingController();
  List<Laptop> _all = [];
  List<Laptop> _filtered = [];
  bool _loading = true;
  bool _handledInitial = false;
  final Set<int> _selectedIds = <int>{};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sub = _db.watchLaptops().listen((list) {
      if (mounted) {
        setState(() {
          _all = list;
          _applyFilter();
          _loading = false;
        });
        if (!_handledInitial && widget.initialItemId != null) {
          final match = list.where((l) => l.id == widget.initialItemId).firstOrNull;
          if (match != null) {
            _handledInitial = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showDetail(match);
              }
            });
          }
        }
      }
    });
    _search.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoader = false}) async {
    if (showLoader || _all.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final list = await _db.getLaptops();
      if (!mounted) {
        return;
      }
      setState(() {
        _all = list;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to load laptops: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = _all.where((l) {
        return l.model.toLowerCase().contains(q) ||
            l.laptopNumber.toLowerCase().contains(q) ||
            l.user.toLowerCase().contains(q) ||
            l.cpu.toLowerCase().contains(q) ||
            l.gpu.toLowerCase().contains(q) ||
            l.ram.toLowerCase().contains(q) ||
            l.storage.toLowerCase().contains(q);
      }).toList();
    });
  }

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
    final confirm = await showConfirmDialog(
      context,
      title: 'Delete Selected?',
      message: 'Are you sure you want to delete ${_selectedIds.length} laptops?',
      confirmText: 'Delete',
    );
    if (!confirm || !mounted) {
      return;
    }
    for (final id in _selectedIds) {
      await _db.deleteLaptop(id);
    }
    if (!mounted) {
      return;
    }
    showSnack(context, '${_selectedIds.length} laptops deleted');
    _selectedIds.clear();
    _load(showLoader: false);
  }

  Future<void> _openForm([Laptop? l]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LaptopFormScreen(laptop: l)),
    );
    if (ok == true && mounted) {
      _load(showLoader: false);
    }
  }

  Future<void> _delete(Laptop l, {bool confirm = true}) async {
    bool ok = false;
    if (confirm) {
      ok = await showConfirmDialog(
        context,
        title: 'Delete Laptop?',
        message: 'Delete ${l.model} (#${l.laptopNumber})?',
      );
    } else {
      ok = true;
    }
    if (!ok || !mounted) {
      return;
    }
    await _db.deleteLaptop(l.id!);
    if (!mounted) {
      return;
    }
    if (confirm) {
      showSnack(context, 'Laptop deleted');
    }
    _load(showLoader: false);
  }

  void _showDetail(Laptop l) {
    showFintechBottomSheet(
      context: context,
      child: _LaptopDetailSheet(
        laptop: l,
        onEdit: () {
          Navigator.pop(context);
          _openForm(l);
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(l);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          SearchBar2(
            controller: _search,
            hint: 'Search model, number, user...',
          ),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.laptop_mac_rounded,
                        title: _search.text.isEmpty
                            ? 'No Laptops Yet'
                            : 'No Results',
                        subtitle: _search.text.isEmpty
                            ? 'Tap + to add a laptop'
                            : 'Try a different search',
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.32,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final l = _filtered[i];
                          final isSelected = _selectedIds.contains(l.id);
                          return SlideInAndFade(
                            index: i,
                            child: InventoryGridCard(
                              selected: isSelected,
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(l.id!)
                                  : () => _showDetail(l),
                              onLongPress: () => _toggleSelection(l.id!),
                              leading: IconBox(
                                icon: Icons.laptop_mac_rounded,
                                color: theme.colorScheme.primary,
                                size: 36,
                              ),
                              badge: ConditionBadge(l.condition),
                              title: l.model,
                              subtitle: '# ${l.laptopNumber}',
                              extra: l.user.isNotEmpty
                                  ? l.user
                                  : (l.ram.isNotEmpty ? l.ram : null),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FintechFab(
                onPressed: () => _openForm(),
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF81C784)
                    : const Color(0xFF2E7D32),
                tooltip: 'Add Laptop',
              ),
            ),
      bottomNavigationBar: _isSelectionMode
          ? SelectionBottomBar(
              selectedCount: _selectedIds.length,
              totalCount: _filtered.length,
              onSelectAll: () {
                setState(() {
                  _selectedIds.addAll(_filtered.where((l) => l.id != null).map((l) => l.id!));
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

class _LaptopDetailSheet extends StatefulWidget {
  final Laptop laptop;
  final VoidCallback onEdit, onDelete;
  const _LaptopDetailSheet({
    required this.laptop,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_LaptopDetailSheet> createState() => _LaptopDetailSheetState();
}

class _LaptopDetailSheetState extends State<_LaptopDetailSheet> {
  bool _showPass = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.laptop;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBox(
                icon: Icons.laptop_mac_rounded,
                color: theme.colorScheme.primary,
                size: 50,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.model,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '# ${l.laptopNumber}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ConditionBadge(l.condition),
            ],
          ),
          const SizedBox(height: 16),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Details'),
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
                  onPressed: widget.onDelete,
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
          const SectionLabel('SPECIFICATIONS & HARDWARE'),
          FintechGroupedCard(
            children: [
              DetailRow(
                label: 'CPU',
                value: l.cpu,
                icon: Icons.memory_rounded,
                copyable: true,
              ),
              DetailRow(
                label: 'GPU',
                value: l.gpu,
                icon: Icons.videogame_asset_outlined,
              ),
              DetailRow(
                label: 'RAM',
                value: l.ram,
                icon: Icons.storage_rounded,
              ),
              DetailRow(
                label: 'Storage',
                value: l.storage,
                icon: Icons.disc_full_outlined,
              ),
            ],
          ),
          const SectionLabel('ASSIGNMENT & CREDENTIALS'),
          FintechGroupedCard(
            children: [
              DetailRow(
                label: 'Assigned User',
                value: l.user.isNotEmpty ? l.user : 'Unassigned',
                icon: Icons.person_outline_rounded,
              ),
              if (l.password.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        child: Text(
                          'Password',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _showPass ? l.password : '••••••••',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _showPass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: () =>
                            setState(() => _showPass = !_showPass),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openCustodySlip(context, l),
              icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
              label: const Text('Create Custody Slip (PDF)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeviceMaintenanceScreen(
                      deviceType: 'laptop',
                      deviceId: l.id!,
                      deviceName: l.model,
                      deviceNumber: l.laptopNumber,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.build_circle_outlined, size: 18),
              label: const Text('View Maintenance & Repair History'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCustodySlip(BuildContext context, Laptop l) async {
    final db = DatabaseHelper();
    final employees = await db.getEmployees();
    Employee? emp;
    if (l.user.isNotEmpty) {
      for (final e in employees) {
        if (e.name.toLowerCase() == l.user.toLowerCase()) {
          emp = e;
          break;
        }
      }
    }
    String empEmail = '';
    final empPhone = emp?.phoneNumber ?? '';
    final empName = l.user.isNotEmpty ? l.user : 'Assigned Recipient';

    final emails = await db.getEmailAccounts();
    for (final ea in emails) {
      if (emp?.id != null && ea.employeeId == emp!.id) {
        empEmail = ea.email;
        break;
      }
      if (ea.employeeName.isNotEmpty && ea.employeeName.toLowerCase() == l.user.toLowerCase()) {
        empEmail = ea.email;
        break;
      }
    }

    final sigCtrl = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.transparent,
    );

    if (!context.mounted) return;

    await showFintechBottomSheet(
      context: context,
      title: 'Custody Slip Signature',
      subtitle: '${l.model} (#${l.laptopNumber})',
      child: StatefulBuilder(
        builder: (ctx, setS) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assigned to $empName',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sign Below to Acknowledge Laptop Custody:',
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
                      final sigBytes = await sigCtrl.toPngBytes();
                      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                      final specs = {
                        'Processor (CPU)': l.cpu,
                        'Graphics (GPU)': l.gpu,
                        'Memory (RAM)': l.ram,
                        'Storage': l.storage,
                      };
                      final file = await CustodyPdfService.generateCustodyPdf(
                        employeeName: empName,
                        employeePhone: empPhone,
                        employeeEmail: empEmail,
                        deviceType: 'Laptop',
                        deviceName: l.model,
                        deviceNumber: l.laptopNumber,
                        condition: l.condition,
                        serialNumber: l.laptopNumber,
                        handoverDate: today,
                        dueDate: 'Indefinite / Employment Duration',
                        signatureBytes: sigBytes,
                        extraSpecs: specs,
                      );
                      await CustodyPdfService.archiveGeneratedSlip(
                        tempPdfFile: file,
                        sourceType: 'laptop',
                        sourceId: l.id,
                        employeeName: empName,
                        employeePhone: empPhone,
                        employeeEmail: empEmail,
                        deviceType: 'Laptop',
                        deviceName: l.model,
                        deviceNumber: l.laptopNumber,
                        condition: l.condition,
                        serialNumber: l.laptopNumber,
                        handoverDate: today,
                        dueDate: 'Indefinite / Employment Duration',
                        signatureBytes: sigBytes,
                        extraSpecs: specs,
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      await CustodyPdfService.shareCustodyFile(file, empName, l.model);
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final sigBytes = await sigCtrl.toPngBytes();
                      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                      final specs = {
                        'Processor (CPU)': l.cpu,
                        'Graphics (GPU)': l.gpu,
                        'Memory (RAM)': l.ram,
                        'Storage': l.storage,
                      };
                      final file = await CustodyPdfService.generateCustodyPdf(
                        employeeName: empName,
                        employeePhone: empPhone,
                        employeeEmail: empEmail,
                        deviceType: 'Laptop',
                        deviceName: l.model,
                        deviceNumber: l.laptopNumber,
                        condition: l.condition,
                        serialNumber: l.laptopNumber,
                        handoverDate: today,
                        dueDate: 'Indefinite / Employment Duration',
                        signatureBytes: sigBytes,
                        extraSpecs: specs,
                      );
                      await CustodyPdfService.archiveGeneratedSlip(
                        tempPdfFile: file,
                        sourceType: 'laptop',
                        sourceId: l.id,
                        employeeName: empName,
                        employeePhone: empPhone,
                        employeeEmail: empEmail,
                        deviceType: 'Laptop',
                        deviceName: l.model,
                        deviceNumber: l.laptopNumber,
                        condition: l.condition,
                        serialNumber: l.laptopNumber,
                        handoverDate: today,
                        dueDate: 'Indefinite / Employment Duration',
                        signatureBytes: sigBytes,
                        extraSpecs: specs,
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      await CustodyPdfService.emailCustodyDirect(
                        file: file,
                        recipientEmail: empEmail,
                        employeeName: empName,
                        device: l.model,
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
    );
    sigCtrl.dispose();
  }
}
