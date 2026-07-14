import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/access_point.dart';
import '../../widgets/common_widgets.dart';

class AccessPointFormScreen extends StatefulWidget {
  final AccessPoint? ap;
  const AccessPointFormScreen({super.key, this.ap});
  @override
  State<AccessPointFormScreen> createState() => _State();
}

class _State extends State<AccessPointFormScreen> {
  final _key = GlobalKey<FormState>(); final _db = DatabaseHelper();
  bool _saving = false;
  late final _num  = TextEditingController(text: widget.ap?.deviceNumber ?? '');
  late final _model = TextEditingController(text: widget.ap?.model ?? '');
  late final _port = TextEditingController(text: widget.ap?.portNumber ?? '');
  late final _loc  = TextEditingController(text: widget.ap?.location ?? '');

  @override
  void dispose() { for (final c in [_num, _model, _port, _loc]) {
      c.dispose();
    } super.dispose(); }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final obj = AccessPoint(id: widget.ap?.id, deviceNumber: _num.text.trim(), model: _model.text.trim(), portNumber: _port.text.trim(), location: _loc.text.trim());
      if (widget.ap == null) {
        await _db.insertAccessPoint(obj);
      } else {
        await _db.updateAccessPoint(obj);
      }
      if (!mounted) { return; }
      Navigator.pop(context, true);
    } catch (e) { if (!mounted) { return; }
      showSnack(context, 'Error: $e', error: true); }
    finally { if (mounted) { setState(() => _saving = false); } }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.ap == null ? 'Add Access Point' : 'Edit Access Point')),
      body: Form(key: _key, child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        Padding(padding: const EdgeInsets.only(bottom: 10), child: TextFormField(enableSuggestions: false, autocorrect: false, controller: _num,
          decoration: const InputDecoration(labelText: 'Device Number *', prefixIcon: Icon(Icons.tag), hintText: 'e.g. AP-01'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null)),
        Padding(padding: const EdgeInsets.only(bottom: 10), child: TextFormField(enableSuggestions: false, autocorrect: false, controller: _model,
          decoration: const InputDecoration(labelText: 'Model *', prefixIcon: Icon(Icons.memory_outlined), hintText: 'e.g. UniFi U6 Pro'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null)),
        Padding(padding: const EdgeInsets.only(bottom: 10), child: TextFormField(enableSuggestions: false, autocorrect: false, controller: _port,
          decoration: const InputDecoration(labelText: 'Port Number', prefixIcon: Icon(Icons.settings_ethernet_outlined), hintText: 'e.g. Port 24'))),
        Padding(padding: const EdgeInsets.only(bottom: 14), child: TextFormField(enableSuggestions: false, autocorrect: false, controller: _loc,
          decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on_outlined), hintText: 'Floor / Room'))),
        const SizedBox(height: 10),
        ElevatedButton.icon(onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
          label: Text(widget.ap == null ? 'Add Access Point' : 'Save Changes'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0891B2))),
      ])),
    );
  }
}
