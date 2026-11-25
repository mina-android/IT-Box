import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/electronic.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';

class ElectronicFormScreen extends StatefulWidget {
  final Electronic? electronic;
  const ElectronicFormScreen({super.key, this.electronic});
  @override
  State<ElectronicFormScreen> createState() => _ElectronicFormScreenState();
}

class _ElectronicFormScreenState extends State<ElectronicFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;

  late final _num =
      TextEditingController(text: widget.electronic?.deviceNumber ?? '');
  late final _name =
      TextEditingController(text: widget.electronic?.deviceName ?? '');
  late final _details =
      TextEditingController(text: widget.electronic?.details ?? '');
  late bool _excludeBorrowing =
      widget.electronic?.excludeFromBorrowing ?? false;

  @override
  void dispose() {
    for (final c in [_num, _name, _details]) {
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
      final tag = _num.text.trim();
      final existing = await _db.getElectronics();
      if (existing.any((e) => e.id != widget.electronic?.id && e.deviceNumber.trim().toLowerCase() == tag.toLowerCase())) {
        if (!mounted) {
          return;
        }
        _shakeKey.currentState?.shake();
        showSnack(context, 'Electronic "$tag" already exists.', error: true);
        setState(() => _saving = false);
        return;
      }

      final e = Electronic(
        id: widget.electronic?.id,
        deviceNumber: tag,
        deviceName: _name.text.trim(),
        details: _details.text.trim(),
        status: widget.electronic?.status ?? 'Available',
        excludeFromBorrowing: _excludeBorrowing,
        notes: widget.electronic?.notes ?? '',
      );
      if (widget.electronic == null) {
        await _db.insertElectronic(e);
      } else {
        await _db.updateElectronic(e);
      }
      if (!mounted) {
        return;
      }
      showSnack(context, 'Device saved successfully!');
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppTextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
        ),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.electronic == null;

    return Scaffold(
      appBar: FintechAppBar(
        title: isNew ? 'Add Electronic Device' : 'Edit Electronic Device',
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
                const SectionLabel('DEVICE IDENTITY'),
                FintechGroupedCard(
                  children: [
                    _buildField(
                      controller: _num,
                      label: 'Device Tag / Number *',
                      icon: Icons.tag_rounded,
                      required: true,
                    ),
                    _buildField(
                      controller: _name,
                      label: 'Device Name & Model *',
                      icon: Icons.devices_other_rounded,
                      required: true,
                    ),
                    _buildField(
                      controller: _details,
                      label: 'Specifications / Notes',
                      icon: Icons.info_outline_rounded,
                      maxLines: 3,
                    ),
                  ],
                ),
                const SectionLabel('BORROWING POLICY'),
                FintechGroupedCard(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Exclude from borrowing list',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Prevent employees from checking out this device',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _excludeBorrowing,
                      onChanged: (v) => setState(() => _excludeBorrowing = v),
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
                      isNew ? 'Save Electronic' : 'Update Electronic',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.electronicColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
