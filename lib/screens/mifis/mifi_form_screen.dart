import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/mifi.dart';
import '../../widgets/common_widgets.dart';

class MiFiFormScreen extends StatefulWidget {
  final MiFi? mifi;
  const MiFiFormScreen({super.key, this.mifi});
  @override
  State<MiFiFormScreen> createState() => _State();
}

class _State extends State<MiFiFormScreen> {
  final _key = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  bool _saving = false, _showWifi = false, _showAdmin = false;

  late final _num      = TextEditingController(text: widget.mifi?.deviceNumber ?? '');
  late final _model    = TextEditingController(text: widget.mifi?.model ?? '');
  late final _phone    = TextEditingController(text: widget.mifi?.phoneNumber ?? '');
  late final _wifi     = TextEditingController(text: widget.mifi?.wifiName ?? '');
  late final _wifiPass = TextEditingController(text: widget.mifi?.wifiPassword ?? '');
  late final _quota    = TextEditingController(text: widget.mifi?.quota ?? '');
  late final _provider = TextEditingController(text: widget.mifi?.serviceProvider ?? '');
  late final _gateway  = TextEditingController(text: widget.mifi?.gateway ?? '');
  late final _adminPass= TextEditingController(text: widget.mifi?.adminPassword ?? '');

  @override
  void dispose() {
    for (final c in [_num, _model, _phone, _wifi, _wifiPass, _quota, _provider, _gateway, _adminPass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final m = MiFi(
        id: widget.mifi?.id,
        deviceNumber: _num.text.trim(),
        model: _model.text.trim(),
        phoneNumber: _phone.text.trim(),
        wifiName: _wifi.text.trim(),
        wifiPassword: _wifiPass.text,
        quota: _quota.text.trim(),
        serviceProvider: _provider.text.trim(),
        gateway: _gateway.text.trim(),
        adminPassword: _adminPass.text,
      );
      if (widget.mifi == null) await _db.insertMiFi(m); else await _db.updateMiFi(m);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Error: $e', error: true);
    } finally {
      if (mounted) { setState(() => _saving = false);
    }
    }
  }

  Widget _f(TextEditingController c, String l, IconData i, {bool req=false, TextInputType? kb, String? hint}) =>
    Padding(padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(enableSuggestions: false, autocorrect: false, controller: c, keyboardType: kb,
        decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), hintText: hint),
        validator: req ? (v) => v==null||v.trim().isEmpty ? 'Required' : null : null));

  Widget _pf(TextEditingController c, String l, IconData i, bool show, VoidCallback t) =>
    Padding(padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(enableSuggestions: false, autocorrect: false, controller: c, obscureText: !show,
        decoration: InputDecoration(labelText: l, prefixIcon: Icon(i),
          suffixIcon: IconButton(icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: t))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.mifi == null ? 'Add MiFi' : 'Edit MiFi')),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          const SectionLabel('IDENTIFICATION'),
          _f(_num, 'Device Number *', Icons.tag, req: true, hint: 'e.g. RADA-MF-01'),
          _f(_model, 'Model *', Icons.router_outlined, req: true, hint: 'e.g. Huawei E5577'),
          _f(_phone, 'Phone Number', Icons.sim_card_outlined, kb: TextInputType.phone, hint: '+962 79 ...'),
          _f(_provider, 'Service Provider', Icons.cell_tower_outlined, hint: 'e.g. Zain Jordan'),
          _f(_quota, 'Quota', Icons.data_usage_outlined, hint: 'e.g. 50GB or Unlimited'),
          const SectionLabel('NETWORK CREDENTIALS'),
          _f(_wifi, 'WiFi Name (SSID)', Icons.wifi_outlined, hint: 'WiFi broadcast name'),
          _pf(_wifiPass, 'WiFi Password', Icons.lock_outlined, _showWifi, () => setState(() => _showWifi = !_showWifi)),
          _f(_gateway, 'Gateway IP', Icons.router, hint: 'e.g. 192.168.8.1'),
          _pf(_adminPass, 'Admin Password', Icons.admin_panel_settings_outlined, _showAdmin, () => setState(() => _showAdmin = !_showAdmin)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
            label: Text(widget.mifi == null ? 'Add MiFi' : 'Update MiFi'),
          ),
        ]),
      ),
    );
  }
}
