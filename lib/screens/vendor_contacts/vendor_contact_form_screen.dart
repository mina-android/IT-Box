// lib/screens/vendor_contacts/vendor_contact_form_screen.dart
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/vendor_contact.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../../widgets/common_widgets.dart';

class VendorContactFormScreen extends StatefulWidget {
  final VendorContact? contact;

  const VendorContactFormScreen({super.key, this.contact});

  @override
  State<VendorContactFormScreen> createState() => _VendorContactFormScreenState();
}

class _VendorContactFormScreenState extends State<VendorContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
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
  bool _saving = false;

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
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      AppHaptics.tap(context, HapticStrength.heavy);
      return;
    }

    setState(() => _saving = true);
    try {
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

      if (!mounted) {
        return;
      }
      AppHaptics.tap(context, HapticStrength.medium);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      showSnack(context, 'Failed to save contact: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.contact != null;

    return Scaffold(
      appBar: FintechAppBar(
        title: isEdit ? 'Edit Contact' : 'Add Vendor Contact',
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ShakeWidget(
          key: _shakeKey,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
              children: [
                const SectionLabel('VENDOR CLASSIFICATION'),
                FintechGroupedCard(
                  children: [
                    FintechDropdown<String>(
                      labelText: 'Contact Type',
                      prefixIcon: const Icon(Icons.category_rounded, size: 20),
                      value: _contactType,
                      items: _types
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _contactType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact Name *',
                        prefixIcon: Icon(Icons.person_rounded, size: 20),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _companyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Company / Organization',
                        prefixIcon: Icon(Icons.business_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _roleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Role / Designation',
                        prefixIcon: Icon(Icons.badge_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const SectionLabel('CONTACT & CONTRACT DETAILS'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number / Hotline',
                        prefixIcon: Icon(Icons.phone_rounded, size: 20),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Support Email',
                        prefixIcon: Icon(Icons.email_rounded, size: 20),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _accountNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Account / Contract / CID #',
                        prefixIcon: Icon(Icons.numbers_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _portalCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Support Portal URL',
                        prefixIcon: Icon(Icons.link_rounded, size: 20),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes & Escalation Procedures',
                        prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _saving ? 'Saving...' : (isEdit ? 'Update Contact' : 'Save Contact'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.vendorColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
