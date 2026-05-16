import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/laptop.dart';
import '../../models/employee.dart';
import '../../widgets/common_widgets.dart';

class LaptopFormScreen extends StatefulWidget {
  final Laptop? laptop;
  const LaptopFormScreen({super.key, this.laptop});
  @override
  State<LaptopFormScreen> createState() => _State();
}

class _State extends State<LaptopFormScreen> {
  final _key = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  bool _saving = false, _showPass = false;
  late String _condition;
  List<Employee> _employees = [];
  Employee? _selEmp;

  late final _num     = TextEditingController(text: widget.laptop?.laptopNumber ?? '');
  late final _model   = TextEditingController(text: widget.laptop?.model ?? '');
  late final _cpu     = TextEditingController(text: widget.laptop?.cpu ?? '');
  late final _gpu     = TextEditingController(text: widget.laptop?.gpu ?? '');
  late final _ram     = TextEditingController(text: widget.laptop?.ram ?? '');
  late final _storage = TextEditingController(text: widget.laptop?.storage ?? '');
  late final _pass    = TextEditingController(text: widget.laptop?.password ?? '');

  @override
  void initState() {
    super.initState();
    _condition = widget.laptop?.condition ?? 'Good';
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final emps = await _db.getEmployees();
    if (!mounted) return;
    setState(() {
      _employees = emps;
      // Pre-select if editing and user matches an employee
      if (widget.laptop?.user.isNotEmpty == true) {
        try {
          _selEmp = emps.firstWhere((e) => e.name == widget.laptop!.user);
        } catch (_) { _selEmp = null; }
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_num, _model, _cpu, _gpu, _ram, _storage, _pass]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final l = Laptop(
        id: widget.laptop?.id,
        laptopNumber: _num.text.trim(),
        model: _model.text.trim(),
        cpu: _cpu.text.trim(),
        gpu: _gpu.text.trim(),
        ram: _ram.text.trim(),
        storage: _storage.text.trim(),
        condition: _condition,
        user: _selEmp?.name ?? '',
        password: _pass.text,
      );
      if (widget.laptop == null) { await _db.insertLaptop(l); } else { await _db.updateLaptop(l); }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Error: $e', error: true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Widget _f(TextEditingController c, String l, IconData i, {bool req=false, String? hint}) =>
    Padding(padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c, enableSuggestions: false, autocorrect: false,
        decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), hintText: hint),
        validator: req ? (v) => v==null||v.trim().isEmpty?'Required':null : null));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.laptop == null ? 'Add Laptop' : 'Edit Laptop')),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          const SectionLabel('IDENTIFICATION'),
          _f(_num, 'Laptop Number *', Icons.tag, req: true, hint: 'e.g. RADA-LT-01'),
          _f(_model, 'Model *', Icons.laptop_outlined, req: true, hint: 'e.g. Dell XPS 15'),
          const SectionLabel('SPECIFICATIONS'),
          _f(_cpu, 'CPU', Icons.memory_outlined, hint: 'e.g. Intel i7-13700H'),
          _f(_gpu, 'GPU', Icons.videogame_asset_outlined, hint: 'e.g. NVIDIA RTX 4060'),
          _f(_ram, 'RAM', Icons.storage_outlined, hint: 'e.g. 16GB DDR5'),
          _f(_storage, 'Storage', Icons.disc_full_outlined, hint: 'e.g. 512GB NVMe'),
          const SectionLabel('CONDITION'),
          SegmentedButton<String>(
            segments: ['Good','Fair','Poor'].map((c) => ButtonSegment<String>(value:c,label:Text(c))).toList(),
            selected: {_condition}, onSelectionChanged: (s) => setState(() => _condition=s.first)),
          const SectionLabel('ASSIGNMENT'),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Assigned User', prefixIcon: Icon(Icons.person_outline)),
            child: DropdownButton<Employee?>(
              value: _selEmp,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: Text('None',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
              items: [
                const DropdownMenuItem<Employee?>(value: null, child: Text('Unassigned')),
                ..._employees.map((e) => DropdownMenuItem<Employee?>(value: e, child: Text(e.name))),
              ],
              onChanged: (v) => setState(() => _selEmp = v),
            ),
          ),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              controller: _pass, obscureText: !_showPass,
              enableSuggestions: false, autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showPass = !_showPass))))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
            label: Text(widget.laptop == null ? 'Add Laptop' : 'Update Laptop')),
        ]),
      ),
    );
  }
}
