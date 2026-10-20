// lib/screens/others/other_device_form_screen.dart
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/other_device.dart';
import '../../utils/haptics.dart';
import '../../widgets/common_widgets.dart';

class OtherDeviceFormScreen extends StatefulWidget {
  final OtherDevice? device;
  const OtherDeviceFormScreen({super.key, this.device});

  @override
  State<OtherDeviceFormScreen> createState() => _OtherDeviceFormScreenState();
}

class _OtherDeviceFormScreenState extends State<OtherDeviceFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;

  late final TextEditingController _typeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _typeCtrl = TextEditingController(text: widget.device?.deviceType ?? '');
    _nameCtrl = TextEditingController(text: widget.device?.deviceName ?? '');
    _modelCtrl = TextEditingController(text: widget.device?.model ?? '');
    _notesCtrl = TextEditingController(text: widget.device?.notes ?? '');
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _nameCtrl.dispose();
    _modelCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      AppHaptics.tap(context, HapticStrength.heavy);
      return;
    }
    setState(() => _saving = true);
    AppHaptics.tap(context, HapticStrength.medium);

    try {
      final item = OtherDevice(
        id: widget.device?.id,
        deviceType: _typeCtrl.text.trim(),
        deviceName: _nameCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        createdAt: widget.device?.createdAt ?? DateTime.now().toIso8601String(),
      );

      if (widget.device == null) {
        final id = await _db.insertOtherDevice(item);
        await _db.logAuditActivity(
          'CREATE',
          'OtherDevice',
          entityId: id,
          description: 'Added ${item.deviceType}: ${item.deviceName}',
        );
      } else {
        await _db.updateOtherDevice(item);
        await _db.logAuditActivity(
          'UPDATE',
          'OtherDevice',
          entityId: item.id,
          description: 'Updated ${item.deviceType}: ${item.deviceName}',
        );
      }

      if (!mounted) return;
      showSnack(
        context,
        widget.device == null ? 'Device added to inventory' : 'Device updated successfully',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Error saving device: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.device != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: FintechAppBar(
        title: isEdit ? 'Edit Hardware' : 'Add New Hardware',
        subtitle: isEdit ? 'Update specifications and details' : 'Register misc hardware into inventory',
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ShakeWidget(
          key: _shakeKey,
          child: Form(
            key: _key,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
              children: [
                const SectionLabel('DEVICE SPECIFICATIONS'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _typeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Device Type *',
                        prefixIcon: Icon(Icons.category_outlined, size: 20),
                        hintText: 'e.g. Projector, NAS, UPS, Scanner, TV',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Device type is required' : null,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Device Name *',
                        prefixIcon: Icon(Icons.devices_other_rounded, size: 20),
                        hintText: 'e.g. Conference Room Projector',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Device name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _modelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        prefixIcon: Icon(Icons.precision_manufacturing_outlined, size: 20),
                        hintText: 'e.g. Epson EB-L200F',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionLabel('ADDITIONAL DETAILS & NOTES'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        prefixIcon: Icon(Icons.notes_rounded, size: 20),
                        hintText: 'Serial number, physical location, warranty, IP, or credentials...',
                      ),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    isEdit ? 'Save Changes' : 'Add to Inventory',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
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
