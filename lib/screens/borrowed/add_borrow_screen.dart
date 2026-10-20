import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/borrow_log.dart';
import '../../models/electronic.dart';
import '../../models/mifi.dart';
import '../../models/employee.dart';
import '../../services/notification_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';

class AddBorrowScreen extends StatefulWidget {
  final BorrowLog? logToEdit;
  const AddBorrowScreen({super.key, this.logToEdit});

  @override
  State<AddBorrowScreen> createState() => _AddBorrowScreenState();
}

class _AddBorrowScreenState extends State<AddBorrowScreen> {
  final _db = DatabaseHelper();
  bool _loading = true;
  bool _saving = false;

  String _deviceType = 'electronic'; // 'electronic' | 'mifi'

  List<Electronic> _availableEl = [];
  List<MiFi> _availableMi = [];
  List<Employee> _employees = [];

  Electronic? _selEl;
  MiFi? _selMi;
  Employee? _selEmp;
  DateTime _outDate = DateTime.now();
  DateTime? _dueDate;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final els = await _db.getElectronics();
    final mis = await _db.getMiFis();
    final emps = await _db.getEmployees();
    if (!mounted) {
      return;
    }

    setState(() {
      _employees = emps;

      if (widget.logToEdit != null) {
        _deviceType = widget.logToEdit!.deviceType;
        _reason.text = widget.logToEdit!.reason;
        _outDate = DateTime.tryParse(widget.logToEdit!.outDate) ?? DateTime.now();
        if (widget.logToEdit!.dueDate != null) {
          _dueDate = DateTime.tryParse(widget.logToEdit!.dueDate!);
        }
        if (widget.logToEdit!.reminderTime != null) {
          final parts = widget.logToEdit!.reminderTime!.split(':');
          if (parts.length == 2) {
            _reminderTime = TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 9,
              minute: int.tryParse(parts[1]) ?? 0,
            );
          }
        }

        try {
          _selEmp = _employees.firstWhere((e) => e.id == widget.logToEdit!.employeeId);
        } catch (_) {}
      }

      _availableEl = els.where((e) =>
          (e.status == 'Available' && !e.excludeFromBorrowing) ||
          (widget.logToEdit != null && widget.logToEdit!.deviceType == 'electronic' && widget.logToEdit!.deviceId == e.id)
      ).toList();

      _availableMi = mis.where((m) =>
          (m.status == 'Available' && !m.excludeFromBorrowing) ||
          (widget.logToEdit != null && widget.logToEdit!.deviceType == 'mifi' && widget.logToEdit!.deviceId == m.id)
      ).toList();

      if (widget.logToEdit != null) {
        if (_deviceType == 'electronic') {
          try {
            _selEl = _availableEl.firstWhere((e) => e.id == widget.logToEdit!.deviceId);
          } catch (_) {}
        } else {
          try {
            _selMi = _availableMi.firstWhere((e) => e.id == widget.logToEdit!.deviceId);
          } catch (_) {}
        }
      }

      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _outDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _outDate = picked);
    }
  }

  Future<void> _pickDueDate() async {
    final initial = _dueDate ?? _outDate.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _outDate,
      lastDate: DateTime.now().add(const Duration(days: 1000)),
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null && mounted) {
      setState(() => _reminderTime = picked);
    }
  }

  Future<void> _save() async {
    if (_selEmp == null) {
      showSnack(context, 'Please select an employee', error: true);
      return;
    }
    if (_deviceType == 'electronic' && _selEl == null) {
      showSnack(context, 'Please select a device', error: true);
      return;
    }
    if (_deviceType == 'mifi' && _selMi == null) {
      showSnack(context, 'Please select a MiFi', error: true);
      return;
    }
    if (_reason.text.trim().isEmpty) {
      showSnack(context, 'Please enter a reason', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final int deviceId;
      final String deviceName, deviceNumber;
      if (_deviceType == 'electronic') {
        deviceId = _selEl!.id!;
        deviceName = _selEl!.deviceName;
        deviceNumber = _selEl!.deviceNumber;
      } else {
        deviceId = _selMi!.id!;
        deviceName = _selMi!.model;
        deviceNumber = _selMi!.deviceNumber;
      }
      final old = widget.logToEdit;
      final log = BorrowLog(
        id: old?.id,
        deviceType: _deviceType,
        deviceId: deviceId,
        deviceName: deviceName,
        deviceNumber: deviceNumber,
        employeeId: _selEmp!.id!,
        employeeName: _selEmp!.name,
        reason: _reason.text.trim(),
        outDate: DateFormat('yyyy-MM-dd').format(_outDate),
        backDate: old?.backDate,
        dueDate: _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null,
        reminderTime: '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
        isReturned: old?.isReturned ?? false,
      );

      final int id;
      if (old != null) {
        id = old.id!;
        await _db.updateBorrowLog(id, log);
        await NotificationService().cancelReminder(id);
      } else {
        id = await _db.insertBorrowLog(log);
      }

      bool? reminderScheduled;
      if (_dueDate != null && !(old?.isReturned ?? false)) {
        reminderScheduled = await NotificationService().scheduleOverdueReminder(
          borrowId: id,
          deviceName: deviceName,
          employeeName: _selEmp!.name,
          dueDate: _dueDate!,
          reminderTime: _reminderTime,
        );
      }
      if (!mounted) {
        return;
      }
      if (reminderScheduled == false) {
        showSnack(
          context,
          widget.logToEdit != null
              ? 'Borrow entry updated (Reminder time already passed; no alert scheduled)'
              : 'Borrow entry saved (Reminder time already passed; no alert scheduled)',
        );
      } else {
        showSnack(context, widget.logToEdit != null ? 'Borrow entry updated' : 'Borrow entry saved');
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(context, 'Error: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openEmployeePicker() async {
    final theme = Theme.of(context);
    final searchCtrl = TextEditingController();
    List<Employee> filtered = List.from(_employees);

    final selected = await showModalBottomSheet<Employee>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Borrower (Employee)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search employee name or phone...',
                    prefixIcon: Icon(Icons.search_rounded),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onChanged: (q) {
                    final query = q.toLowerCase().trim();
                    setModalState(() {
                      filtered = _employees.where((e) {
                        return e.name.toLowerCase().contains(query) ||
                            e.phoneNumber.toLowerCase().contains(query);
                      }).toList();
                    });
                  },
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: filtered.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No matching employees found.',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final emp = filtered[i];
                            final isSel = _selEmp?.id == emp.id;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              leading: IconBox(
                                icon: Icons.badge_outlined,
                                color: isSel ? AppColors.borrowed : AppColors.employeeColor,
                                size: 36,
                              ),
                              title: Text(
                                emp.name,
                                style: TextStyle(
                                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              subtitle: emp.phoneNumber.isNotEmpty
                                  ? Text(emp.phoneNumber, style: const TextStyle(fontSize: 12))
                                  : null,
                              trailing: isSel
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.borrowed)
                                  : null,
                              onTap: () => Navigator.pop(ctx, emp),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (selected != null && mounted) {
      setState(() => _selEmp = selected);
    }
  }

  Future<void> _openDevicePicker() async {
    final theme = Theme.of(context);
    final searchCtrl = TextEditingController();

    if (_deviceType == 'electronic') {
      List<Electronic> filtered = List.from(_availableEl);
      final selected = await showModalBottomSheet<Electronic>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Electronic Device',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search device name or tag...',
                      prefixIcon: Icon(Icons.search_rounded),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (q) {
                      final query = q.toLowerCase().trim();
                      setModalState(() {
                        filtered = _availableEl.where((e) {
                          return e.deviceName.toLowerCase().contains(query) ||
                              e.deviceNumber.toLowerCase().contains(query) ||
                              e.details.toLowerCase().contains(query);
                        }).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                    ),
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No matching devices available.',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.4,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final dev = filtered[i];
                              final isSel = _selEl?.id == dev.id;
                              return InventoryGridCard(
                                selected: isSel,
                                leading: const IconBox(
                                  icon: Icons.devices_rounded,
                                  color: AppColors.electronicColor,
                                  size: 34,
                                ),
                                title: dev.deviceName,
                                subtitle: '# ${dev.deviceNumber}',
                                extra: dev.details.isNotEmpty ? dev.details : null,
                                onTap: () => Navigator.pop(ctx, dev),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      );
      if (selected != null && mounted) {
        setState(() => _selEl = selected);
      }
    } else {
      List<MiFi> filtered = List.from(_availableMi);
      final selected = await showModalBottomSheet<MiFi>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select MiFi Device',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search MiFi model, tag, or quota...',
                      prefixIcon: Icon(Icons.search_rounded),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (q) {
                      final query = q.toLowerCase().trim();
                      setModalState(() {
                        filtered = _availableMi.where((m) {
                          return m.model.toLowerCase().contains(query) ||
                              m.deviceNumber.toLowerCase().contains(query) ||
                              m.quota.toLowerCase().contains(query) ||
                              m.tag.toLowerCase().contains(query);
                        }).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                    ),
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No matching MiFi units available.',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.4,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final m = filtered[i];
                              final isSel = _selMi?.id == m.id;
                              return InventoryGridCard(
                                selected: isSel,
                                leading: const IconBox(
                                  icon: Icons.wifi_tethering_rounded,
                                  color: Color(0xFF0EA5E9),
                                  size: 34,
                                ),
                                title: m.model,
                                subtitle: '# ${m.deviceNumber}',
                                extra: m.tag.isNotEmpty ? m.tag : (m.quota.isNotEmpty ? m.quota : null),
                                onTap: () => Navigator.pop(ctx, m),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      );
      if (selected != null && mounted) {
        setState(() => _selMi = selected);
      }
    }
  }

  Widget _infoBox(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 4, bottom: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.logToEdit != null ? 'Edit Borrow Entry' : 'New Borrow Entry'),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
          ),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving || (_deviceType == 'electronic' && _availableEl.isEmpty) || (_deviceType == 'mifi' && _availableMi.isEmpty) ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: Text(widget.logToEdit != null ? 'Update Borrow' : 'Borrow Device', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.borrowed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                FintechGroupedCard(
                  title: 'Device Selection',
                  icon: Icons.devices_other_rounded,
                  children: [
                    if (widget.logToEdit?.isReturned == true)
                      _infoBox('This record has already been marked returned. Hardware device is locked.', theme.colorScheme.primary),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.logToEdit?.isReturned == true
                                  ? null
                                  : () => setState(() {
                                        _deviceType = 'electronic';
                                        _selEl = null;
                                        _selMi = null;
                                      }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _deviceType == 'electronic'
                                      ? (isDark ? AppColors.darkCard : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _deviceType == 'electronic'
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.devices_rounded,
                                        size: 16,
                                        color: _deviceType == 'electronic' ? AppColors.borrowed : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Electronic',
                                        style: TextStyle(
                                          fontWeight: _deviceType == 'electronic' ? FontWeight.w700 : FontWeight.w500,
                                          color: _deviceType == 'electronic' ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.logToEdit?.isReturned == true
                                  ? null
                                  : () => setState(() {
                                        _deviceType = 'mifi';
                                        _selEl = null;
                                        _selMi = null;
                                      }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _deviceType == 'mifi'
                                      ? (isDark ? AppColors.darkCard : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _deviceType == 'mifi'
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.wifi_tethering_rounded,
                                        size: 16,
                                        color: _deviceType == 'mifi' ? AppColors.borrowed : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'MiFi',
                                        style: TextStyle(
                                          fontWeight: _deviceType == 'mifi' ? FontWeight.w700 : FontWeight.w500,
                                          color: _deviceType == 'mifi' ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_deviceType == 'electronic') ...[
                      if (_availableEl.isEmpty && widget.logToEdit?.isReturned != true)
                        _infoBox('All electronic devices are currently borrowed.', AppColors.borrowed)
                      else
                        InkWell(
                          onTap: widget.logToEdit?.isReturned == true ? null : _openDevicePicker,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Electronic Device *',
                              prefixIcon: Icon(Icons.devices_rounded),
                              suffixIcon: Icon(Icons.grid_view_rounded, size: 20),
                            ),
                            child: Text(
                              _selEl != null
                                  ? '${_selEl!.deviceName} (${_selEl!.deviceNumber})'
                                  : 'Tap to browse available devices...',
                              style: TextStyle(
                                fontWeight: _selEl != null ? FontWeight.w700 : FontWeight.normal,
                                color: _selEl != null
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                    ] else ...[
                      if (_availableMi.isEmpty && widget.logToEdit?.isReturned != true)
                        _infoBox('All MiFi devices are currently borrowed.', AppColors.borrowed)
                      else
                        InkWell(
                          onTap: widget.logToEdit?.isReturned == true ? null : _openDevicePicker,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'MiFi Device *',
                              prefixIcon: Icon(Icons.wifi_tethering_rounded),
                              suffixIcon: Icon(Icons.grid_view_rounded, size: 20),
                            ),
                            child: Text(
                              _selMi != null
                                  ? '${_selMi!.model} (${_selMi!.deviceNumber})'
                                  : 'Tap to browse available MiFis...',
                              style: TextStyle(
                                fontWeight: _selMi != null ? FontWeight.w700 : FontWeight.normal,
                                color: _selMi != null
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                FintechGroupedCard(
                  title: 'Borrower Details',
                  icon: Icons.person_outline_rounded,
                  children: [
                    if (_employees.isEmpty)
                      _infoBox('No employees found. Please add employees first.', theme.colorScheme.error)
                    else
                      InkWell(
                        onTap: _openEmployeePicker,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Employee Borrower *',
                            prefixIcon: Icon(Icons.badge_outlined),
                            suffixIcon: Icon(Icons.search_rounded, size: 20),
                          ),
                          child: Text(
                            _selEmp != null
                                ? (_selEmp!.phoneNumber.isNotEmpty
                                    ? '${_selEmp!.name} (${_selEmp!.phoneNumber})'
                                    : _selEmp!.name)
                                : 'Tap to search employee directory...',
                            style: TextStyle(
                              fontWeight: _selEmp != null ? FontWeight.w700 : FontWeight.normal,
                              color: _selEmp != null
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _reason,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Reason for Borrowing *',
                        prefixIcon: Icon(Icons.description_outlined),
                        hintText: 'e.g. Client meeting or conference',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FintechGroupedCard(
                  title: 'Schedule & Alerts',
                  icon: Icons.calendar_today_rounded,
                  children: [
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.calendar_today_rounded),
                          labelText: 'Checkout Date',
                        ),
                        child: Text(
                          DateFormat('EEEE, dd MMM yyyy').format(_outDate),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickDueDate,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.event_available_rounded),
                          labelText: 'Due Date (Optional)',
                          suffixIcon: _dueDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () => setState(() => _dueDate = null),
                                )
                              : null,
                        ),
                        child: Text(
                          _dueDate != null
                              ? DateFormat('EEEE, dd MMM yyyy').format(_dueDate!)
                              : 'No due date set (Tap to specify)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _dueDate != null ? FontWeight.w600 : FontWeight.w400,
                            color: _dueDate != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                    if (_dueDate != null) ...[
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _pickReminderTime,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.alarm_rounded),
                            labelText: 'Reminder Alert Time',
                          ),
                          child: Text(
                            _reminderTime.format(context),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }
}
