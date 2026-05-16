import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/bill.dart';
import '../../widgets/common_widgets.dart';

class BillFormScreen extends StatefulWidget {
  final Bill? bill;
  const BillFormScreen({super.key, this.bill});
  @override
  State<BillFormScreen> createState() => _State();
}

class _State extends State<BillFormScreen> {
  final _key = GlobalKey<FormState>();
  final _db  = DatabaseHelper();
  bool _saving = false;
  late String _category;

  late final _person = TextEditingController(text: widget.bill?.person ?? '');
  late final _number = TextEditingController(text: widget.bill?.number ?? '');
  late final _price  = TextEditingController(
      text: widget.bill != null ? widget.bill!.price.toStringAsFixed(2) : '');
  late final _notes  = TextEditingController(text: widget.bill?.notes ?? '');

  @override
  void initState() {
    super.initState();
    _category = widget.bill?.category ?? Bill.categories.first;
  }

  @override
  void dispose() {
    for (final c in [_person, _number, _price, _notes]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final b = Bill(
        id:       widget.bill?.id,
        person:   _person.text.trim(),
        number:   _number.text.trim(),
        category: _category,
        price:    double.tryParse(_price.text.trim()) ?? 0.0,
        notes:    _notes.text.trim(),
      );
      if (widget.bill == null) { await _db.insertBill(b); } else { await _db.updateBill(b); }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Error: $e', error: true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.bill != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Bill' : 'Add Bill')),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          // Category
          const SectionLabel('CATEGORY'),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category_outlined)),
            child: DropdownButton<String>(
              value: _category,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: Bill.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) { if (v != null) setState(() => _category = v); },
            ),
          ),

          // Details
          const SectionLabel('DETAILS'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              controller: _person,
              enableSuggestions: false, autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Person (optional)',
                prefixIcon: Icon(Icons.person_outline),
                hintText: 'Name of person'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              controller: _number,
              enableSuggestions: false, autocorrect: false,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Number *',
                prefixIcon: Icon(Icons.tag_outlined),
                hintText: 'Phone / account number'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              controller: _price,
              enableSuggestions: false, autocorrect: false,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price (EGP) *',
                prefixIcon: Icon(Icons.attach_money_outlined),
                hintText: '0.00'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                return null;
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              controller: _notes,
              enableSuggestions: false, autocorrect: false,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined),
            label: Text(isEdit ? 'Update Bill' : 'Add Bill'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED)),
          ),
        ]),
      ),
    );
  }
}
