import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/expense.dart';
import '../../services/currency_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../../widgets/common_widgets.dart';

class DeviceMaintenanceFormScreen extends StatefulWidget {
  final String deviceType;
  final int deviceId;
  final String deviceName;
  final String deviceNumber;

  const DeviceMaintenanceFormScreen({
    super.key,
    required this.deviceType,
    required this.deviceId,
    required this.deviceName,
    required this.deviceNumber,
  });

  @override
  State<DeviceMaintenanceFormScreen> createState() =>
      _DeviceMaintenanceFormScreenState();
}

class _DeviceMaintenanceFormScreenState
    extends State<DeviceMaintenanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();

  String _serviceType = 'Repair';
  bool _isPlanned = false;
  DateTime _selectedDate = DateTime.now();
  bool _addToExpenses = true;
  bool _saving = false;

  final _costCtrl = TextEditingController(text: '0.0');
  final _detailsCtrl = TextEditingController();
  final _technicianCtrl = TextEditingController(text: 'Internal IT');

  @override
  void dispose() {
    _costCtrl.dispose();
    _detailsCtrl.dispose();
    _technicianCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      AppHaptics.tap(context, HapticStrength.heavy);
      return;
    }

    setState(() => _saving = true);
    try {
      final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final details = _detailsCtrl.text.trim();
      final technician = _technicianCtrl.text.trim().isEmpty
          ? 'Internal IT'
          : _technicianCtrl.text.trim();

      await _db.insertMaintenanceLog({
        'device_type': widget.deviceType,
        'device_id': widget.deviceId,
        'date': dateStr,
        'service_type': _serviceType,
        'cost': cost,
        'details': details,
        'performed_by': technician,
        'is_planned': _isPlanned ? 1 : 0,
        'planned_date': _isPlanned ? dateStr : '',
      });

      if (!_isPlanned && _addToExpenses && cost > 0) {
        await _db.insertExpense(
          Expense(
            date: dateStr,
            item: '$_serviceType: ${widget.deviceName} (#${widget.deviceNumber})',
            price: cost,
            details: details,
          ),
        );
      }

      await _db.logAuditActivity(
        'MAINTENANCE',
        widget.deviceType,
        entityId: widget.deviceId,
        description:
            '${_isPlanned ? 'Scheduled ' : ''}$_serviceType on ${widget.deviceName} (#${widget.deviceNumber})',
      );

      if (!mounted) {
        return;
      }
      AppHaptics.tap(context, HapticStrength.medium);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      showSnack(context, 'Failed to save maintenance record: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final currencyCode = CurrencyService().currency;

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Log Maintenance / Repair',
        subtitle: '${widget.deviceName} (#${widget.deviceNumber})',
      ),
      body: Form(
        key: _formKey,
        child: ShakeWidget(
          key: _shakeKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              const SectionLabel('SERVICE DETAILS'),
              FintechGroupedCard(
                title: 'Maintenance Classification',
                icon: Icons.build_circle_outlined,
                children: [
                  FintechDropdown<String>(
                    labelText: 'Service Type *',
                    prefixIcon: const Icon(Icons.category_outlined),
                    value: _serviceType,
                    items: const [
                      DropdownMenuItem(value: 'Repair', child: Text('Hardware Repair')),
                      DropdownMenuItem(value: 'Upgrade', child: Text('Component Upgrade (RAM/SSD)')),
                      DropdownMenuItem(value: 'Maintenance', child: Text('Cleaning / Repaste / Service')),
                      DropdownMenuItem(value: 'Inspection', child: Text('Inspection / Testing')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _serviceType = v);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: IconBox(
                      icon: _isPlanned ? Icons.event_available_rounded : Icons.check_circle_outline_rounded,
                      color: _isPlanned ? Colors.amber.shade700 : AppColors.available,
                      size: 36,
                    ),
                    title: const Text(
                      'Scheduled / Planned Maintenance',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text(
                      _isPlanned
                          ? 'Appears on Maintenance Calendar as upcoming'
                          : 'Completed service intervention',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    value: _isPlanned,
                    onChanged: (v) {
                      setState(() {
                        _isPlanned = v;
                        if (_isPlanned) {
                          _addToExpenses = false;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: _isPlanned ? 'Planned Date *' : 'Service Date *',
                        prefixIcon: const Icon(Icons.calendar_today_rounded),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateStr,
                            style: credentialFont(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            Icons.edit_calendar_rounded,
                            size: 18,
                            color: cs.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionLabel('WORK & COST'),
              FintechGroupedCard(
                title: 'Intervention & Billing',
                icon: Icons.receipt_long_outlined,
                children: [
                  AppTextField(
                    controller: _detailsCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Work Details *',
                      hintText: 'e.g. Replaced thermal paste, cooling fan & SSD upgrade',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Work details are required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _technicianCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Performed By / Vendor',
                      hintText: 'Internal IT / Dell Support',
                      prefixIcon: Icon(Icons.engineering_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Cost ($currencyCode)',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Text(
                          currencyCode,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (!_isPlanned) ...[
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: IconBox(
                        icon: Icons.account_balance_wallet_outlined,
                        color: cs.primary,
                        size: 36,
                      ),
                      title: const Text(
                        'Add cost to Department Expenses',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      subtitle: Text(
                        'Automatically logs an expense entry when cost > 0',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                      value: _addToExpenses,
                      onChanged: (v) => setState(() => _addToExpenses = v),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  _saving ? 'Saving...' : 'Save Maintenance Record',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
