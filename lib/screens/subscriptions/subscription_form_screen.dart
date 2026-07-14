import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/subscription.dart';
import '../../widgets/common_widgets.dart';

class SubscriptionFormScreen extends StatefulWidget {
  final Subscription? subscription;
  const SubscriptionFormScreen({super.key, this.subscription});
  @override
  State<SubscriptionFormScreen> createState() => _SubscriptionFormScreenState();
}

class _SubscriptionFormScreenState extends State<SubscriptionFormScreen> {
  final _key = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  bool _saving = false;

  late final _service = TextEditingController(text: widget.subscription?.service ?? '');
  late final _price = TextEditingController(
      text: widget.subscription == null || widget.subscription!.price == 0
          ? ''
          : widget.subscription!.price.toString());
  late final _renewalDate = TextEditingController(text: widget.subscription?.renewalDate ?? '');
  late final _notes = TextEditingController(text: widget.subscription?.notes ?? '');
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
      _renewalDate.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
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
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Error saving subscription: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subscription == null ? 'Add Subscription' : 'Edit Subscription'),
      ),
      body: Form(
        key: _key,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _service,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Service Name *',
                  hintText: 'e.g. Google Workspace, GitHub, Zoom',
                  prefixIcon: Icon(Icons.subscriptions_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Billing Interval *',
                        prefixIcon: Icon(Icons.repeat_outlined),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _type,
                          isDense: true,
                          items: Subscription.types.map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _type = val);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _price,
                      enableSuggestions: false,
                      autocorrect: false,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Price (EGP) *',
                        prefixIcon: Icon(Icons.attach_money_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _renewalDate,
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  labelText: 'Renewal / Next Payment Date',
                  hintText: 'Select date',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixIcon: _renewalDate.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _renewalDate.clear(),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                enableSuggestions: false,
                autocorrect: false,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes / Account Details (Optional)',
                  hintText: 'e.g. 5 user seats, renewed annually via card ending 1234',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(widget.subscription == null ? 'Add Subscription' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
