import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/borrow_log.dart';
import '../../models/electronic.dart';
import '../../models/mifi.dart';
import '../../models/employee.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';

class AddBorrowScreen extends StatefulWidget {
  const AddBorrowScreen({super.key});
  @override
  State<AddBorrowScreen> createState() => _State();
}

class _State extends State<AddBorrowScreen> {
  final _db = DatabaseHelper();
  bool _loading = true, _saving = false;

  String _deviceType = 'electronic'; // 'electronic' | 'mifi'

  List<Electronic> _availableEl = [];
  List<MiFi>       _availableMi = [];
  List<Employee>   _employees   = [];

  Electronic? _selEl;
  MiFi?       _selMi;
  Employee?   _selEmp;
  DateTime    _outDate = DateTime.now();
  final _reason = TextEditingController();

  @override
  void initState() { super.initState(); _loadData(); }
  @override
  void dispose() { _reason.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    final els  = await _db.getElectronics();
    final mis  = await _db.getMiFis();
    final emps = await _db.getEmployees();
    if (!mounted) return;
    setState(() {
      _availableEl = els.where((e) => e.status == 'Available').toList();
      _availableMi = mis.where((m) => m.status == 'Available').toList();
      _employees   = emps;
      _loading     = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _outDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null && mounted) setState(() => _outDate = picked);
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
        deviceId     = _selEl!.id!;
        deviceName   = _selEl!.deviceName;
        deviceNumber = _selEl!.deviceNumber;
      } else {
        deviceId     = _selMi!.id!;
        deviceName   = _selMi!.model;
        deviceNumber = _selMi!.deviceNumber;
      }
      final log = BorrowLog(
        deviceType:   _deviceType,
        deviceId:     deviceId,
        deviceName:   deviceName,
        deviceNumber: deviceNumber,
        employeeId:   _selEmp!.id!,
        employeeName: _selEmp!.name,
        reason:       _reason.text.trim(),
        outDate:      DateFormat('yyyy-MM-dd').format(_outDate),
      );
      await _db.insertBorrowLog(log);
      if (!mounted) return;
      showSnack(context, 'Borrow entry saved');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Use InputDecorator + DropdownButton instead of DropdownButtonFormField
  // to avoid the deprecated FormField.value warning.
  Widget _dropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        hint: Text('Select…', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
        items: items.map((item) => DropdownMenuItem<T>(
          value: item,
          child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _infoBox(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 4, bottom: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Row(children: [
      Icon(Icons.info_outline, color: color, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13))),
    ]));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New Borrow Entry')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              const SectionLabel('DEVICE TYPE'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'electronic',
                    icon: Icon(Icons.devices_other_outlined),
                    label: Text('Electronic'),
                  ),
                  ButtonSegment(
                    value: 'mifi',
                    icon: Icon(Icons.wifi_tethering_outlined),
                    label: Text('MiFi'),
                  ),
                ],
                selected: {_deviceType},
                onSelectionChanged: (s) => setState(() {
                  _deviceType = s.first;
                  _selEl = null;
                  _selMi = null;
                }),
              ),

              const SectionLabel('SELECT DEVICE'),
              if (_deviceType == 'electronic') ...[
                if (_availableEl.isEmpty)
                  _infoBox('All electronic devices are currently borrowed.', AppColors.borrowed)
                else
                  _dropdown<Electronic>(
                    label: 'Electronic Device',
                    icon: Icons.devices_other_outlined,
                    value: _selEl,
                    items: _availableEl,
                    itemLabel: (e) => '${e.deviceName} (${e.deviceNumber})',
                    onChanged: (v) => setState(() => _selEl = v),
                  ),
              ] else ...[
                if (_availableMi.isEmpty)
                  _infoBox('All MiFi devices are currently borrowed.', AppColors.borrowed)
                else
                  _dropdown<MiFi>(
                    label: 'MiFi Device',
                    icon: Icons.wifi_tethering_outlined,
                    value: _selMi,
                    items: _availableMi,
                    itemLabel: (m) => '${m.model} (${m.deviceNumber})',
                    onChanged: (v) => setState(() => _selMi = v),
                  ),
              ],

              const SectionLabel('EMPLOYEE'),
              if (_employees.isEmpty)
                _infoBox('No employees found. Please add employees first.',
                    theme.colorScheme.error)
              else
                _dropdown<Employee>(
                  label: 'Select Employee',
                  icon: Icons.person_outline,
                  value: _selEmp,
                  items: _employees,
                  itemLabel: (e) => e.name,
                  onChanged: (v) => setState(() => _selEmp = v),
                ),

              const SectionLabel('REASON'),
              TextFormField(
        enableSuggestions: false,
        autocorrect: false,
                controller: _reason,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for borrowing *',
                  prefixIcon: Icon(Icons.info_outline),
                  alignLabelWithHint: true,
                  hintText: 'Why is this device being borrowed?'),
              ),

              const SectionLabel('OUT DATE'),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    labelText: 'Out Date'),
                  child: Text(
                    DateFormat('dd MMMM yyyy').format(_outDate),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ),
              ),

              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
                label: const Text('Save Borrow Entry'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.borrowed),
              ),
            ],
          ),
    );
  }
}
