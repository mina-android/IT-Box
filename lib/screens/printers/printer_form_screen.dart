import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/printer.dart';
import '../../widgets/common_widgets.dart';

class PrinterFormScreen extends StatefulWidget {
  final Printer? printer;
  const PrinterFormScreen({super.key, this.printer});
  @override
  State<PrinterFormScreen> createState() => _State();
}

class _State extends State<PrinterFormScreen> {
  final _key = GlobalKey<FormState>(); final _db = DatabaseHelper();
  bool _saving = false; late String _condition;
  late final _num   = TextEditingController(text: widget.printer?.printerNumber ?? '');
  late final _model = TextEditingController(text: widget.printer?.model ?? '');
  late final _loc   = TextEditingController(text: widget.printer?.location ?? '');

  @override
  void initState() { super.initState(); _condition = widget.printer?.condition ?? 'Good'; }
  @override
  void dispose() { for (final c in [_num,_model,_loc]) {
      c.dispose();
    } super.dispose(); }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final p = Printer(id: widget.printer?.id, printerNumber: _num.text.trim(), model: _model.text.trim(), condition: _condition, location: _loc.text.trim());
      if (widget.printer == null) await _db.insertPrinter(p); else await _db.updatePrinter(p);
      if (!mounted) { return; }
      Navigator.pop(context, true);
    } catch (e) { if (!mounted) { return; }
      showSnack(context, 'Error: $e', error: true); }
    finally { if (mounted) { setState(() => _saving = false); } }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.printer==null?'Add Printer':'Edit Printer')),
      body: Form(key: _key, child: ListView(padding: const EdgeInsets.fromLTRB(16,8,16,40), children: [
        Padding(padding: const EdgeInsets.only(bottom:10), child: TextFormField(enableSuggestions: false, autocorrect: false, controller: _num,
          decoration: const InputDecoration(labelText:'Printer Number *',prefixIcon:Icon(Icons.tag),hintText:'e.g. RADA-PR-01'),
          validator: (v) => v==null||v.trim().isEmpty?'Required':null)),
        Padding(padding: const EdgeInsets.only(bottom:10), child: TextFormField(enableSuggestions: false, autocorrect: false, controller: _model,
          decoration: const InputDecoration(labelText:'Model *',prefixIcon:Icon(Icons.print_outlined),hintText:'e.g. HP LaserJet Pro'),
          validator: (v) => v==null||v.trim().isEmpty?'Required':null)),
        Padding(padding: const EdgeInsets.only(bottom:14), child: TextFormField(enableSuggestions: false, autocorrect: false, controller: _loc,
          decoration: const InputDecoration(labelText:'Location',prefixIcon:Icon(Icons.location_on_outlined),hintText:'Floor / Room'))),
        const SectionLabel('CONDITION'),
        SegmentedButton<String>(
          segments: ['Good','Fair','Poor'].map((c) => ButtonSegment<String>(value:c,label:Text(c))).toList(),
          selected: {_condition}, onSelectionChanged: (s) => setState(() => _condition=s.first)),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: _saving?null:_save,
          icon: _saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_outlined),
          label: Text(widget.printer==null?'Add Printer':'Update Printer'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488))),
      ])),
    );
  }
}
