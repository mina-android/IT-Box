import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/expense.dart';
import '../../services/currency_service.dart';
import '../../widgets/common_widgets.dart';

const Color _expenseColor = Color(0xFF10B981);

class ExpenseFormScreen extends StatefulWidget {
  final Expense? expense;
  const ExpenseFormScreen({super.key, this.expense});
  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;
  DateTime _date = DateTime.now();

  late final _item = TextEditingController(text: widget.expense?.item ?? '');
  late final _price = TextEditingController(
      text: widget.expense != null
          ? widget.expense!.price.toStringAsFixed(2)
          : '');
  late final _details =
      TextEditingController(text: widget.expense?.details ?? '');

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _date = DateTime.tryParse(widget.expense!.date) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    for (final c in [_item, _price, _details]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
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
      if (widget.expense == null) {
        await _db.insertExpense(e);
      } else {
        await _db.updateExpense(e);
      }
      if (!mounted) {
        return;
      }
      showSnack(context, 'Expense saved successfully!');
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
    final isEdit = widget.expense != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: FintechAppBar(
        title: isEdit ? 'Edit Expense' : 'Add Expense',
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
                const SectionLabel('TRANSACTION AMOUNT & DATE'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount (Price) *',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              CurrencyService().currency,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: _expenseColor,
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
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transaction Date',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('EEEE, d MMMM yyyy').format(_date),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Icon(
                              Icons.edit_calendar_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SectionLabel('EXPENSE DESCRIPTION'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _item,
                      decoration: const InputDecoration(
                        labelText: 'Item / Category *',
                        prefixIcon:
                            Icon(Icons.shopping_bag_outlined, size: 20),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _details,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Additional Details',
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
                      isEdit ? 'Update Expense' : 'Record Expense',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _expenseColor,
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
