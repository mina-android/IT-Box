import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/electronic.dart';
import '../../widgets/common_widgets.dart';

class ElectronicFormScreen extends StatefulWidget {
  final Electronic? electronic;
  const ElectronicFormScreen({super.key, this.electronic});
  @override
  State<ElectronicFormScreen> createState() => _State();
}

class _State extends State<ElectronicFormScreen> {
  final _key = GlobalKey<FormState>(); final _db = DatabaseHelper();
  bool _saving = false;
  late final _num     = TextEditingController(text: widget.electronic?.deviceNumber ?? '');
  late final _name    = TextEditingController(text: widget.electronic?.deviceName ?? '');
  late final _details = TextEditingController(text: widget.electronic?.details ?? '');

  @override
  void dispose() { for (final c in [_num,_name,_details]) {
      c.dispose();
    } super.dispose(); }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final e = Electronic(id: widget.electronic?.id, deviceNumber: _num.text.trim(), deviceName: _name.text.trim(), details: _details.text.trim(), status: widget.electronic?.status ?? 'Available');
      if (widget.electronic == null) await _db.insertElectronic(e); else await _db.updateElectronic(e);
      if (!mounted) { return; }
      Navigator.pop(context, true);
    } catch (e) { if (!mounted) { return; }
      showSnack(context, 'Error: $e', error: true); }
    finally { if (mounted) { setState(() => _saving = false); } }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.electronic==null?'Add Electronic':'Edit Electronic')),
      body: Form(key: _key, child: ListView(padding: const EdgeInsets.fromLTRB(16,8,16,40), children: [
        Padding(padding: const EdgeInsets.only(bottom:10), child: TextFormField(enableSuggestions: false, autocorrect: false, controller: _num,
          decoration: const InputDecoration(labelText:'Device Number *',prefixIcon:Icon(Icons.tag),hintText:'e.g. RADA-EL-01'),
          validator: (v) => v==null||v.trim().isEmpty?'Required':null)),
        Padding(padding: const EdgeInsets.only(bottom:10), child: TextFormField(enableSuggestions: false, autocorrect: false, controller: _name,
          decoration: const InputDecoration(labelText:'Device Name *',prefixIcon:Icon(Icons.devices_other_outlined),hintText:'e.g. Projector BenQ'),
          validator: (v) => v==null||v.trim().isEmpty?'Required':null)),
        Padding(padding: const EdgeInsets.only(bottom:10), child: TextFormField(enableSuggestions: false, autocorrect: false, controller: _details, maxLines: 4,
          decoration: const InputDecoration(labelText:'Details',prefixIcon:Icon(Icons.info_outline),alignLabelWithHint:true,hintText:'Model, specs, accessories...'))),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: _saving?null:_save,
          icon: _saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_outlined),
          label: Text(widget.electronic==null?'Add Electronic':'Update Electronic'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED))),
      ])),
    );
  }
}
