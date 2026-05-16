import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/employee.dart';
import '../../widgets/common_widgets.dart';

class EmployeeFormScreen extends StatefulWidget {
  final Employee? employee;
  const EmployeeFormScreen({super.key, this.employee});
  @override
  State<EmployeeFormScreen> createState() => _State();
}

class _State extends State<EmployeeFormScreen> {
  final _key = GlobalKey<FormState>(); final _db = DatabaseHelper();
  bool _saving = false;
  late final _name  = TextEditingController(text: widget.employee?.name ?? '');
  late final _phone = TextEditingController(text: widget.employee?.phoneNumber ?? '');

  @override
  void dispose() { for (final c in [_name,_phone]) {
      c.dispose();
    } super.dispose(); }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final e = Employee(id: widget.employee?.id, name: _name.text.trim(), phoneNumber: _phone.text.trim());
      if (widget.employee == null) await _db.insertEmployee(e); else await _db.updateEmployee(e);
      if (!mounted) { return; }
      Navigator.pop(context, true);
    } catch (e) { if (!mounted) { return; }
      showSnack(context, 'Error: $e', error: true); }
    finally { if (mounted) { setState(() => _saving = false); } }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.employee==null?'Add Employee':'Edit Employee')),
      body: Form(key: _key, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextFormField(enableSuggestions: false, autocorrect: false, controller: _name, textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText:'Full Name *',prefixIcon:Icon(Icons.person_outline),hintText:'First and last name'),
          validator: (v) => v==null||v.trim().isEmpty?'Name is required':null),
        const SizedBox(height: 12),
        TextFormField(enableSuggestions: false, autocorrect: false, controller: _phone, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText:'Phone Number',prefixIcon:Icon(Icons.phone_outlined),hintText:'+962 79 ...')),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(onPressed: _saving?null:_save,
            icon: _saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_outlined),
            label: Text(widget.employee==null?'Add Employee':'Update Employee'))),
      ]))),
    );
  }
}
