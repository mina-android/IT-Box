import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/expense.dart';
import '../../widgets/common_widgets.dart';

class ExpenseFormScreen extends StatefulWidget {
  final Expense? expense;
  const ExpenseFormScreen({super.key, this.expense});
  @override
  State<ExpenseFormScreen> createState() => _State();
}

class _State extends State<ExpenseFormScreen> {
  final _key = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  bool _saving = false;
  DateTime _date = DateTime.now();

  late final _item    = TextEditingController(text: widget.expense?.item ?? '');
  late final _price   = TextEditingController(text: widget.expense != null ? widget.expense!.price.toStringAsFixed(2) : '');
  late final _details = TextEditingController(text: widget.expense?.details ?? '');

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _date = DateTime.tryParse(widget.expense!.date) ?? DateTime.now();
    }
  }

  @override
  void dispose() { for (final c in [_item, _price, _details]) {
      c.dispose();
    } super.dispose(); }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final price = double.tryParse(_price.text.trim()) ?? 0.0;
      final e = Expense(
        id: widget.expense?.id,
        date: DateFormat('yyyy-MM-dd').format(_date),
        item: _item.text.trim(),
        price: price,
        details: _details.text.trim(),
      );
      if (widget.expense == null) await _db.insertExpense(e); else await _db.updateExpense(e);
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.expense != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Expense' : 'Add Expense')),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          const SectionLabel('DATE'),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_today_outlined), labelText: 'Date'),
              child: Text(DateFormat('dd MMMM yyyy').format(_date),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          ),
          const SectionLabel('EXPENSE DETAILS'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
        enableSuggestions: false,
        autocorrect: false,
              controller: _item,
              decoration: const InputDecoration(labelText: 'Item / Description *', prefixIcon: Icon(Icons.shopping_bag_outlined), hintText: 'What was purchased?'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
        enableSuggestions: false,
        autocorrect: false,
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price *', prefixIcon: Icon(Icons.attach_money_outlined), hintText: '0.00'),
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
        enableSuggestions: false,
        autocorrect: false,
              controller: _details,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Details', prefixIcon: Icon(Icons.notes_outlined), alignLabelWithHint: true, hintText: 'Additional notes...'),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
            label: Text(isEdit ? 'Update Expense' : 'Add Expense'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          ),
        ]),
      ),
    );
  }
}
