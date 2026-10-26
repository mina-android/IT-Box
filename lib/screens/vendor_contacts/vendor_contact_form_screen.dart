// lib/screens/vendor_contacts/vendor_contact_form_screen.dart
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/vendor_contact.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/haptics.dart';

class VendorContactFormScreen extends StatefulWidget {
  final VendorContact? contact;

  const VendorContactFormScreen({super.key, this.contact});

  @override
  State<VendorContactFormScreen> createState() => _VendorContactFormScreenState();
}

class _VendorContactFormScreenState extends State<VendorContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();

  late String _contactType;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _roleCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _portalCtrl;
  late final TextEditingController _accountNumberCtrl;
  late final TextEditingController _notesCtrl;

  static const List<String> _types = [
    'ISP',
    'Vendor',
    'Hardware',
    'Domain/Registrar',
    'Cloud/SaaS',
    'Internal',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _contactType = c?.contactType ?? 'Vendor';
    if (!_types.contains(_contactType)) {
      _contactType = 'Vendor';
    }
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _companyCtrl = TextEditingController(text: c?.company ?? '');
    _roleCtrl = TextEditingController(text: c?.role ?? '');
    _phoneCtrl = TextEditingController(text: c?.phoneNumber ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _portalCtrl = TextEditingController(text: c?.portalUrl ?? '');
    _accountNumberCtrl = TextEditingController(text: c?.accountNumber ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _roleCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _portalCtrl.dispose();
    _accountNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final contact = VendorContact(
      id: widget.contact?.id,
      contactType: _contactType,
      name: _nameCtrl.text.trim(),
      company: _companyCtrl.text.trim(),
      role: _roleCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      portalUrl: _portalCtrl.text.trim(),
      accountNumber: _accountNumberCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
    );

    if (widget.contact == null) {
      await _db.insertVendorContact(contact);
    } else {
      await _db.updateVendorContact(contact);
    }

    if (mounted) {
      AppHaptics.tap(context, HapticStrength.light);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.contact != null;

    return Scaffold(
      appBar: FintechAppBar(
        title: isEdit ? 'Edit Contact' : 'Add Vendor Contact',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _contactType,
              decoration: const InputDecoration(
                labelText: 'Contact Type',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: _types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _contactType = val);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Contact Name *',
                prefixIcon: Icon(Icons.person_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _companyCtrl,
              decoration: const InputDecoration(
                labelText: 'Company / Organization',
                prefixIcon: Icon(Icons.business_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _roleCtrl,
              decoration: const InputDecoration(
                labelText: 'Role / Designation',
                prefixIcon: Icon(Icons.badge_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone Number / Hotline',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Support Email',
                prefixIcon: Icon(Icons.email_rounded),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'Account / Contract / CID #',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portalCtrl,
              decoration: const InputDecoration(
                labelText: 'Support Portal URL',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes & Escalation Procedures',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(isEdit ? 'Update Contact' : 'Save Contact'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
