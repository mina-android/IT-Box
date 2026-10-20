import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/subscription.dart';
import '../../widgets/common_widgets.dart';

const Color _subColor = Color(0xFFF43F5E);

class SubscriptionFormScreen extends StatefulWidget {
  final Subscription? subscription;
  const SubscriptionFormScreen({super.key, this.subscription});
  @override
  State<SubscriptionFormScreen> createState() =>
      _SubscriptionFormScreenState();
}

class _SubscriptionFormScreenState extends State<SubscriptionFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;

  late final _service =
      TextEditingController(text: widget.subscription?.service ?? '');
  late final _price = TextEditingController(
      text: widget.subscription == null || widget.subscription!.price == 0
          ? ''
          : widget.subscription!.price.toString());
  late final _renewalDate =
      TextEditingController(text: widget.subscription?.renewalDate ?? '');
  late final _notes =
      TextEditingController(text: widget.subscription?.notes ?? '');
  late String _type = widget.subscription?.type ?? 'Monthly';

  @override
  void dispose() {
    _service.dispose();
    _price.dispose();
    _renewalDate.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _renewalDate.text.isNotEmpty
        ? (DateTime.tryParse(_renewalDate.text) ?? now)
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _renewalDate.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    setState(() => _saving = true);
    try {
      final sub = Subscription(
        id: widget.subscription?.id,
        service: _service.text.trim(),
        type: _type,
        price: double.tryParse(_price.text.trim()) ?? 0.0,
        renewalDate: _renewalDate.text.trim(),
        notes: _notes.text.trim(),
      );
      if (widget.subscription == null) {
        await _db.insertSubscription(sub);
      } else {
        await _db.updateSubscription(sub);
      }
      if (!mounted) {
        return;
      }
      showSnack(context, 'Subscription saved successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(context, 'Error saving subscription: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.subscription != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Subscription' : 'Add Subscription',
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
                const SectionLabel('SUBSCRIPTION SERVICE'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _service,
                      decoration: const InputDecoration(
                        labelText: 'Service / Tool Name *',
                        prefixIcon:
                            Icon(Icons.subscriptions_outlined, size: 20),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),

                const SectionLabel('BILLING CYCLE & COST'),
                FintechGroupedCard(
                  children: [
                    FintechDropdown<String>(
                      labelText: 'Billing Interval *',
                      prefixIcon: const Icon(Icons.repeat_rounded, size: 20),
                      value: _type,
                      items: Subscription.types
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _type = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Recurring Cost *',
                        prefixIcon: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              'EGP',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: _subColor,
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
                  ],
                ),

                const SectionLabel('RENEWAL & NOTES'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _renewalDate,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: InputDecoration(
                        labelText: 'Next Renewal / Expiry Date',
                        prefixIcon: const Icon(Icons.calendar_today_rounded,
                            size: 20),
                        suffixIcon: _renewalDate.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 18),
                                onPressed: () =>
                                    setState(() => _renewalDate.clear()),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Account Details (Optional)',
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
                      isEdit ? 'Update Subscription' : 'Add Subscription',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _subColor,
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
