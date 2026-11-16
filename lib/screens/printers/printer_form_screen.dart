import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/printer.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';

class PrinterFormScreen extends StatefulWidget {
  final Printer? printer;
  const PrinterFormScreen({super.key, this.printer});
  @override
  State<PrinterFormScreen> createState() => _PrinterFormScreenState();
}

class _PrinterFormScreenState extends State<PrinterFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;
  late String _condition;

  late final _num =
      TextEditingController(text: widget.printer?.printerNumber ?? '');
  late final _model = TextEditingController(text: widget.printer?.model ?? '');
  late final _loc = TextEditingController(text: widget.printer?.location ?? '');

  @override
  void initState() {
    super.initState();
    _condition = widget.printer?.condition ?? 'Good';
  }

  @override
  void dispose() {
    for (final c in [_num, _model, _loc]) {
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
      final p = Printer(
        id: widget.printer?.id,
        printerNumber: _num.text.trim(),
        model: _model.text.trim(),
        condition: _condition,
        location: _loc.text.trim(),
      );
      if (widget.printer == null) {
        await _db.insertPrinter(p);
      } else {
        await _db.updatePrinter(p);
      }
      if (!mounted) {
        return;
      }
      showSnack(context, 'Printer saved successfully!');
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
    final isNew = widget.printer == null;

    return Scaffold(
      appBar: FintechAppBar(
        title: isNew ? 'Add Printer' : 'Edit Printer',
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
                      label: 'Printer Tag / Number *',
                      icon: Icons.tag_rounded,
                      required: true,
                    ),
                    _buildField(
                      controller: _model,
                      label: 'Printer Model *',
                      icon: Icons.print_rounded,
                      required: true,
                    ),
                    _buildField(
                      controller: _loc,
                      label: 'Physical Location (Floor / Office)',
                      icon: Icons.location_on_outlined,
                    ),
                  ],
                ),
                const SectionLabel('CONDITION'),
                FintechGroupedCard(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        style: ButtonStyle(
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        segments: const [
                          ButtonSegment<String>(
                            value: 'Good',
                            label: Text('Good',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          ButtonSegment<String>(
                            value: 'Fair',
                            label: Text('Fair',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          ButtonSegment<String>(
                            value: 'Poor',
                            label: Text('Poor',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                        selected: {_condition},
                        onSelectionChanged: (s) =>
                            setState(() => _condition = s.first),
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
                      isNew ? 'Save Printer' : 'Update Printer',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.printerColor,
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
