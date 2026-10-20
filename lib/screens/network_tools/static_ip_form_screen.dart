// lib/screens/network_tools/static_ip_form_screen.dart
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../../widgets/common_widgets.dart';

class StaticIpFormScreen extends StatefulWidget {
  final Map<String, dynamic>? item;
  const StaticIpFormScreen({super.key, this.item});

  @override
  State<StaticIpFormScreen> createState() => _StaticIpFormScreenState();
}

class _StaticIpFormScreenState extends State<StaticIpFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;

  late final TextEditingController _ipCtrl;
  late final TextEditingController _subnetCtrl;
  late final TextEditingController _deviceCtrl;
  late final TextEditingController _macCtrl;
  late final TextEditingController _notesCtrl;
  String _selectedType = 'Server';

  static const List<String> _deviceTypes = [
    'Server',
    'Router',
    'Switch',
    'Access Point',
    'Printer',
    'Workstation',
    'NAS / Storage',
    'CCTV / Security',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.item;
    _ipCtrl = TextEditingController(text: d?['ip_address'] ?? '');
    _subnetCtrl = TextEditingController(text: d?['subnet_mask'] ?? '255.255.255.0');
    _deviceCtrl = TextEditingController(text: d?['assigned_device'] ?? '');
    _macCtrl = TextEditingController(text: d?['mac_address'] ?? '');
    _notesCtrl = TextEditingController(text: d?['notes'] ?? '');

    final existingType = (d?['device_type'] ?? 'Server').toString();
    _selectedType = _deviceTypes.contains(existingType) ? existingType : 'Other';
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _subnetCtrl.dispose();
    _deviceCtrl.dispose();
    _macCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      AppHaptics.tap(context, HapticStrength.heavy);
      return;
    }
    setState(() => _saving = true);
    AppHaptics.tap(context, HapticStrength.medium);

    try {
      final map = {
        'ip_address': _ipCtrl.text.trim(),
        'subnet_mask': _subnetCtrl.text.trim().isNotEmpty ? _subnetCtrl.text.trim() : '255.255.255.0',
        'assigned_device': _deviceCtrl.text.trim(),
        'device_type': _selectedType,
        'mac_address': _macCtrl.text.trim().toUpperCase(),
        'notes': _notesCtrl.text.trim(),
      };

      if (widget.item == null) {
        final id = await _db.insertStaticIp(map);
        await _db.logAuditActivity(
          'CREATE',
          'StaticIP',
          entityId: id,
          description: 'Registered static IP ${_ipCtrl.text.trim()} for ${_deviceCtrl.text.trim()}',
        );
      } else {
        final id = widget.item!['id'] as int;
        await _db.updateStaticIp(map, id);
        await _db.logAuditActivity(
          'UPDATE',
          'StaticIP',
          entityId: id,
          description: 'Updated static IP ${_ipCtrl.text.trim()} (${_deviceCtrl.text.trim()})',
        );
      }

      if (!mounted) return;
      showSnack(context, 'Static IP assignment saved successfully');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Error saving static IP: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: FintechAppBar(
        title: isEdit ? 'Edit Static IP' : 'Assign Static IP',
        subtitle: isEdit ? 'Update host assignment details' : 'Record static IPv4 address allocation',
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ShakeWidget(
          key: _shakeKey,
          child: Form(
            key: _key,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
              children: [
                const SectionLabel('IP & NETWORK CONFIGURATION'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _ipCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: credentialFont(fontSize: 15, color: cs.onSurface),
                      decoration: const InputDecoration(
                        labelText: 'IP Address *',
                        prefixIcon: Icon(Icons.lan_outlined, size: 20),
                        hintText: 'e.g. 192.168.1.100',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'IP Address is required';
                        final parts = v.trim().split('.');
                        if (parts.length != 4 || parts.any((p) => int.tryParse(p) == null || int.parse(p) < 0 || int.parse(p) > 255)) {
                          return 'Enter a valid IPv4 address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _subnetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: credentialFont(fontSize: 15, color: cs.onSurface),
                      decoration: const InputDecoration(
                        labelText: 'Subnet Mask',
                        prefixIcon: Icon(Icons.grid_3x3_rounded, size: 20),
                        hintText: '255.255.255.0',
                      ),
                    ),
                    const SizedBox(height: 14),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Device Type',
                        prefixIcon: Icon(Icons.category_outlined, size: 20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedType,
                          isExpanded: true,
                          isDense: true,
                          items: _deviceTypes.map((t) {
                            return DropdownMenuItem(value: t, child: Text(t));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedType = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionLabel('HOST & HARDWARE IDENTITY'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _deviceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Device / Host Name *',
                        prefixIcon: Icon(Icons.computer_rounded, size: 20),
                        hintText: 'e.g. Core Switch HP-2920, NAS-Backup-01',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Assigned device name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _macCtrl,
                      style: credentialFont(fontSize: 15, color: cs.onSurface),
                      decoration: const InputDecoration(
                        labelText: 'Hardware MAC Address',
                        prefixIcon: Icon(Icons.fingerprint_rounded, size: 20),
                        hintText: '00:1A:2B:3C:4D:5E',
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Location Info',
                        prefixIcon: Icon(Icons.notes_rounded, size: 20),
                        hintText: 'e.g. Server Room Rack 2U / IDF-1',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    isEdit ? 'Save Changes' : 'Save Static IP Assignment',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
