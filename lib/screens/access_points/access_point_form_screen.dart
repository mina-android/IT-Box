import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/access_point.dart';
import '../../widgets/common_widgets.dart';

class AccessPointFormScreen extends StatefulWidget {
  final AccessPoint? ap;
  const AccessPointFormScreen({super.key, this.ap});
  @override
  State<AccessPointFormScreen> createState() => _AccessPointFormScreenState();
}

class _AccessPointFormScreenState extends State<AccessPointFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;

  late final _num =
      TextEditingController(text: widget.ap?.deviceNumber ?? '');
  late final _model = TextEditingController(text: widget.ap?.model ?? '');
  late final _port = TextEditingController(text: widget.ap?.portNumber ?? '');
  late final _loc = TextEditingController(text: widget.ap?.location ?? '');

  @override
  void dispose() {
    for (final c in [_num, _model, _port, _loc]) {
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
      final obj = AccessPoint(
        id: widget.ap?.id,
        deviceNumber: _num.text.trim(),
        model: _model.text.trim(),
        portNumber: _port.text.trim(),
        location: _loc.text.trim(),
      );
      if (widget.ap == null) {
        await _db.insertAccessPoint(obj);
      } else {
        await _db.updateAccessPoint(obj);
      }
      if (!mounted) {
        return;
      }
      showSnack(context, 'Access Point saved successfully!');
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppTextField(
        controller: controller,
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
    final isNew = widget.ap == null;

    return Scaffold(
      appBar: FintechAppBar(
        title: isNew ? 'Add Access Point' : 'Edit Access Point',
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
                      controller: _model,
                      label: 'AP Model *',
                      icon: Icons.cell_tower_rounded,
                      required: true,
                    ),
                  ],
                ),
                const SectionLabel('NETWORK PORT & LOCATION'),
                FintechGroupedCard(
                  children: [
                    _buildField(
                      controller: _port,
                      label: 'Patch Panel / Switch Port',
                      icon: Icons.settings_ethernet_rounded,
                    ),
                    _buildField(
                      controller: _loc,
                      label: 'Physical Location / Zone',
                      icon: Icons.location_on_outlined,
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
                      isNew ? 'Save Access Point' : 'Update Access Point',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0891B2),
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
