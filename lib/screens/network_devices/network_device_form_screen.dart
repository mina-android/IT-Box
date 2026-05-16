import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/network_device.dart';
import '../../widgets/common_widgets.dart';

class NetworkDeviceFormScreen extends StatefulWidget {
  final NetworkDevice? device;
  const NetworkDeviceFormScreen({super.key, this.device});
  @override
  State<NetworkDeviceFormScreen> createState() => _State();
}

class _State extends State<NetworkDeviceFormScreen> {
  final _key = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  bool _saving = false, _showWifiPass = false, _showAdminPass = false;

  late final _num      = TextEditingController(text: widget.device?.deviceNumber ?? '');
  late final _model    = TextEditingController(text: widget.device?.model ?? '');
  late final _phone    = TextEditingController(text: widget.device?.phoneNumber ?? '');
  late final _loc      = TextEditingController(text: widget.device?.deviceLocation ?? '');
  late final _provider = TextEditingController(text: widget.device?.serviceProvider ?? '');
  late final _wifi     = TextEditingController(text: widget.device?.wifiName ?? '');
  late final _wifiPass = TextEditingController(text: widget.device?.wifiPassword ?? '');
  late final _gateway  = TextEditingController(text: widget.device?.gateway ?? '');
  late final _adminPass= TextEditingController(text: widget.device?.adminPassword ?? '');

  @override
  void dispose() {
    for (final c in [_num, _model, _phone, _loc, _provider, _wifi, _wifiPass, _gateway, _adminPass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final d = NetworkDevice(
        id: widget.device?.id,
        deviceNumber: _num.text.trim(),
        model: _model.text.trim(),
        phoneNumber: _phone.text.trim(),
        deviceLocation: _loc.text.trim(),
        serviceProvider: _provider.text.trim(),
        wifiName: _wifi.text.trim(),
        wifiPassword: _wifiPass.text,
        gateway: _gateway.text.trim(),
        adminPassword: _adminPass.text,
        status: widget.device?.status ?? 'Available',
      );
      if (widget.device == null) {
        await _db.insertNetworkDevice(d);
      } else {
        await _db.updateNetworkDevice(d);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool req = false, TextInputType? type, String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
        enableSuggestions: false,
        autocorrect: false,
          controller: ctrl, keyboardType: type,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), hintText: hint),
          validator: req ? (v) => v == null || v.trim().isEmpty ? 'Required' : null : null,
        ),
      );

  Widget _passField(TextEditingController ctrl, String label, IconData icon,
      bool show, VoidCallback toggle) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
        enableSuggestions: false,
        autocorrect: false,
          controller: ctrl,
          obscureText: !show,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            suffixIcon: IconButton(
              icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: toggle,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.device != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Network Device' : 'Add Network Device')),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            const SectionLabel('IDENTIFICATION'),
            _field(_num, 'Device Number *', Icons.tag, req: true, hint: 'e.g. RADA-ND-01'),
            _field(_model, 'Model *', Icons.router_outlined, req: true, hint: 'e.g. Cisco RV340'),
            _field(_phone, 'Phone Number', Icons.phone_outlined, type: TextInputType.phone, hint: '+962 79 ...'),
            _field(_loc, 'Device Location', Icons.location_on_outlined, hint: 'Floor / Room'),
            _field(_provider, 'Service Provider', Icons.cell_tower_outlined, hint: 'e.g. Zain Jordan'),
            const SectionLabel('NETWORK CREDENTIALS'),
            _field(_wifi, 'WiFi Name (SSID)', Icons.wifi_outlined, hint: 'WiFi network name'),
            _passField(_wifiPass, 'WiFi Password', Icons.lock_outlined, _showWifiPass,
                () => setState(() => _showWifiPass = !_showWifiPass)),
            _field(_gateway, 'Gateway IP', Icons.router, hint: 'e.g. 192.168.1.1'),
            _passField(_adminPass, 'Admin Password', Icons.admin_panel_settings_outlined, _showAdminPass,
                () => setState(() => _showAdminPass = !_showAdminPass)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
              label: Text(isEdit ? 'Update Device' : 'Add Device'),
            ),
          ],
        ),
      ),
    );
  }
}
