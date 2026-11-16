// lib/screens/network_tools/switch_patch_chassis_form_screen.dart
import 'package:flutter/material.dart';
import '../../utils/haptics.dart';
import '../../widgets/common_widgets.dart';
import 'switch_patch_matrix_screen.dart';

class SwitchPatchChassisFormScreen extends StatefulWidget {
  final PatchPanelChassis? chassis;
  const SwitchPatchChassisFormScreen({super.key, this.chassis});

  @override
  State<SwitchPatchChassisFormScreen> createState() => _SwitchPatchChassisFormScreenState();
}

class _SwitchPatchChassisFormScreenState extends State<SwitchPatchChassisFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;
  String _selectedType = 'Switch';
  int _selectedPorts = 24;

  @override
  void initState() {
    super.initState();
    final c = widget.chassis;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _locationCtrl = TextEditingController(text: c?.location ?? '');
    _selectedType = c?.type ?? 'Switch';
    _selectedPorts = c?.totalPorts ?? 24;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_key.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      AppHaptics.tap(context, HapticStrength.heavy);
      return;
    }
    AppHaptics.tap(context, HapticStrength.medium);

    final name = _nameCtrl.text.trim();
    final location = _locationCtrl.text.trim();

    if (widget.chassis == null) {
      final newId = DateTime.now().microsecondsSinceEpoch % 1000000000;
      final newChassis = PatchPanelChassis(
        id: newId,
        name: name,
        type: _selectedType,
        totalPorts: _selectedPorts,
        location: location,
      );
      Navigator.pop(context, newChassis);
    } else {
      final toEdit = widget.chassis!;
      toEdit.name = name;
      toEdit.type = _selectedType;
      toEdit.totalPorts = _selectedPorts;
      toEdit.location = location;
      Navigator.pop(context, toEdit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.chassis != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: FintechAppBar(
        title: isEdit ? 'Edit Chassis' : 'Add Switch / Patch Panel',
        subtitle: isEdit ? 'Update hardware chassis configuration' : 'Configure rack bay or switch ports',
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
                const SectionLabel('CHASSIS HARDWARE SPECIFICATION'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit / Chassis Name *',
                        hintText: 'e.g. Cisco SG350-28 / Rack A Patch Bay',
                        prefixIcon: Icon(Icons.settings_input_hdmi_rounded, size: 20),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Unit name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    FintechDropdown<String>(
                      labelText: 'Chassis Type',
                      prefixIcon: const Icon(Icons.category_rounded, size: 20),
                      value: _selectedType,
                      items: const [
                        DropdownMenuItem(value: 'Switch', child: Text('Network Switch')),
                        DropdownMenuItem(value: 'Patch Panel', child: Text('Patch Panel')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedType = v);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    FintechDropdown<int>(
                      labelText: 'Total Available Ports',
                      prefixIcon: const Icon(Icons.grid_view_rounded, size: 20),
                      value: _selectedPorts,
                      items: const [
                        DropdownMenuItem(value: 8, child: Text('8 Ports (Compact Desktop)')),
                        DropdownMenuItem(value: 12, child: Text('12 Ports (Half Rack)')),
                        DropdownMenuItem(value: 16, child: Text('16 Ports (Wall Mount / Small Rack)')),
                        DropdownMenuItem(value: 24, child: Text('24 Ports (Standard 1U Enterprise)')),
                        DropdownMenuItem(value: 48, child: Text('48 Ports (High-Density 2U Enterprise)')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedPorts = v);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionLabel('RACK & LOCATION DETAILS'),
                FintechGroupedCard(
                  children: [
                    AppTextField(
                      controller: _locationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Location / Rack Info',
                        hintText: 'e.g. Server Room IDF-02 / Rack 3U',
                        prefixIcon: Icon(Icons.pin_drop_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    isEdit ? 'Save Changes' : 'Create Unit',
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
