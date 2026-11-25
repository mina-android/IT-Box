// lib/screens/network_tools/switch_patch_port_form_screen.dart
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class SwitchPatchPortFormScreen extends StatefulWidget {
  final int switchDeviceId;
  final String? switchName;
  final int portNumber;
  final Map<String, dynamic>? existing;

  const SwitchPatchPortFormScreen({
    super.key,
    required this.switchDeviceId,
    this.switchName,
    required this.portNumber,
    this.existing,
  });

  @override
  State<SwitchPatchPortFormScreen> createState() => _SwitchPatchPortFormScreenState();
}

class _SwitchPatchPortFormScreenState extends State<SwitchPatchPortFormScreen> {
  final _db = DatabaseHelper();
  late String _status;
  late final TextEditingController _deviceCtrl;
  late final TextEditingController _roomCtrl;
  late final TextEditingController _vlanCtrl;
  bool _saving = false;

  static const _statuses = ['Active', 'Free', 'Faulty', 'Uplink'];

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    final rawStatus = ex?['status']?.toString() ?? 'Free';
    _status = _statuses.contains(rawStatus) ? rawStatus : 'Free';
    _deviceCtrl = TextEditingController(text: ex?['connected_device']?.toString() ?? '');
    _roomCtrl = TextEditingController(text: ex?['destination_room']?.toString() ?? '');
    _vlanCtrl = TextEditingController(text: ex?['vlan']?.toString() ?? '1');
  }

  @override
  void dispose() {
    _deviceCtrl.dispose();
    _roomCtrl.dispose();
    _vlanCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = {
        'switch_device_id': widget.switchDeviceId,
        'port_number': widget.portNumber,
        'connected_device': _deviceCtrl.text.trim(),
        'destination_room': _roomCtrl.text.trim(),
        'vlan': _vlanCtrl.text.trim(),
        'status': _status,
      };
      if (widget.existing != null && widget.existing!['id'] != null) {
        await _db.updateSwitchPatchPort(payload, widget.existing!['id'] as int);
      } else {
        await _db.insertSwitchPatchPort(payload);
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FintechAppBar(
        title: 'Port #${widget.portNumber}',
        subtitle: widget.switchName != null
            ? '${widget.switchName} • Configure port'
            : 'Configure switch / patch panel port',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          FintechDropdown<String>(
            value: _status,
            labelText: 'Port Status',
            prefixIcon: const Icon(Icons.settings_input_hdmi_rounded),
            items: _statuses
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _status = v);
              }
            },
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _deviceCtrl,
            decoration: const InputDecoration(
              labelText: 'Connected Device / Endpoint',
              prefixIcon: Icon(Icons.devices_rounded),
            ),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _roomCtrl,
            decoration: const InputDecoration(
              labelText: 'Room / Wall Jack #',
              prefixIcon: Icon(Icons.meeting_room_outlined),
            ),
            style: credentialFont(),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _vlanCtrl,
            decoration: const InputDecoration(
              labelText: 'VLAN ID',
              prefixIcon: Icon(Icons.lan_outlined),
            ),
            style: credentialFont(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving...' : 'Save Port Configuration'),
            ),
          ),
        ],
      ),
    );
  }
}
