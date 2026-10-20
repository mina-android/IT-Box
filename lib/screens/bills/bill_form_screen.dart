import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/bill.dart';
import '../../widgets/common_widgets.dart';

const Color _billColor = Color(0xFF8B5CF6);

class BillFormScreen extends StatefulWidget {
  final Bill? bill;
  const BillFormScreen({super.key, this.bill});
  @override
  State<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends State<BillFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;
  late String _category;

  late final _person =
      TextEditingController(text: widget.bill?.person ?? '');
  late final _number =
      TextEditingController(text: widget.bill?.number ?? '');
  late final _price = TextEditingController(
      text: widget.bill != null
          ? widget.bill!.price.toStringAsFixed(2)
          : '');
  late final _notes = TextEditingController(text: widget.bill?.notes ?? '');

  @override
  void initState() {
    super.initState();
    _category = widget.bill?.category ?? Bill.categories.first;
  }

  @override
  void dispose() {
    for (final c in [_person, _number, _price, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    setState(() => _saving = true);
    try {
      final b = Bill(
        id: widget.bill?.id,
        person: _person.text.trim(),
        number: _number.text.trim(),
        category: _category,
        price: double.tryParse(_price.text.trim()) ?? 0.0,
        notes: _notes.text.trim(),
      );
      if (widget.bill == null) {
        await _db.insertBill(b);
      } else {
        await _db.updateBill(b);
      }
      if (!mounted) {
        return;
      }
      showSnack(context, 'Bill saved successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(context, 'Error: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.bill != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Bill' : 'Add Bill',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ShakeWidget(
          key: _shakeKey,
          child: Form(
            key: _key,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                const SectionLabel('BILL CATEGORY'),
                FintechGroupedCard(
                  children: [
                    FintechDropdown<String>(
                      labelText: 'Bill Type / Line',
                      prefixIcon: const Icon(Icons.category_rounded, size: 20),
                      value: _category,
                      items: Bill.categories
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _category = v);
                        }
                      },
                    ),
                  ],
                ),

                const SectionLabel('ACCOUNT & COST'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Recurring Amount (Price) *',
                        prefixIcon: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              'EGP',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: _billColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(v.trim()) == null) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _number,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone / Line / Account Number *',
                        prefixIcon: Icon(Icons.tag_rounded, size: 20),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _person,
                      decoration: const InputDecoration(
                        labelText: 'Responsible Person / Contact (Optional)',
                        prefixIcon:
                            Icon(Icons.person_outline_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Billing Notes & Provider Info',
                        prefixIcon: Icon(Icons.notes_rounded, size: 20),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(
                      isEdit ? 'Update Bill' : 'Save Bill',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _billColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
