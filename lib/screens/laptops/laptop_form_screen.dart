import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/laptop.dart';
import '../../models/employee.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/haptics.dart';

class LaptopFormScreen extends StatefulWidget {
  final Laptop? laptop;
  const LaptopFormScreen({super.key, this.laptop});
  @override
  State<LaptopFormScreen> createState() => _LaptopFormScreenState();
}

class _LaptopFormScreenState extends State<LaptopFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;
  bool _showPass = false;
  late String _condition;
  List<Employee> _employees = [];
  Employee? _selEmp;

  late final _num =
      TextEditingController(text: widget.laptop?.laptopNumber ?? '');
  late final _model = TextEditingController(text: widget.laptop?.model ?? '');
  late final _cpu = TextEditingController(text: widget.laptop?.cpu ?? '');
  late final _gpu = TextEditingController(text: widget.laptop?.gpu ?? '');
  late final _ram = TextEditingController(text: widget.laptop?.ram ?? '');
  late final _storage =
      TextEditingController(text: widget.laptop?.storage ?? '');
  late final _pass =
      TextEditingController(text: widget.laptop?.password ?? '');

  @override
  void initState() {
    super.initState();
    _condition = widget.laptop?.condition ?? 'Good';
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final emps = await _db.getEmployees();
    if (!mounted) {
      return;
    }
    setState(() {
      _employees = emps;
      if (widget.laptop?.user.isNotEmpty == true) {
        try {
          _selEmp = emps.firstWhere((e) => e.name == widget.laptop!.user);
        } catch (_) {
          _selEmp = null;
        }
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_num, _model, _cpu, _gpu, _ram, _storage, _pass]) {
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
      final allLaptops = await _db.getLaptops();
      final duplicate = allLaptops.any((lap) =>
          lap.id != widget.laptop?.id &&
          lap.laptopNumber.trim().toLowerCase() == tag.toLowerCase());
      if (duplicate) {
        if (!mounted) {
          return;
        }
        _shakeKey.currentState?.shake();
        AppHaptics.tap(context, HapticStrength.heavy);
        showSnack(context, 'Laptop tag "$tag" already exists. Please choose a unique identifier.', error: true);
        setState(() => _saving = false);
        return;
      }

      final l = Laptop(
        id: widget.laptop?.id,
        laptopNumber: tag,
        model: _model.text.trim(),
        cpu: _cpu.text.trim(),
        gpu: _gpu.text.trim(),
        ram: _ram.text.trim(),
        storage: _storage.text.trim(),
        condition: _condition,
        user: _selEmp?.name ?? '',
        password: _pass.text,
        notes: widget.laptop?.notes ?? '',
        createdAt: widget.laptop?.createdAt,
      );
      if (widget.laptop == null) {
        await _db.insertLaptop(l);
      } else {
        await _db.updateLaptop(l);
      }
      if (!mounted) {
        return;
      }
      showSnack(context, 'Laptop saved successfully!');
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
    final isNew = widget.laptop == null;

    return Scaffold(
      appBar: FintechAppBar(
        title: isNew ? 'Add Laptop' : 'Edit Laptop',
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
                      label: 'Laptop Tag / Number *',
                      icon: Icons.tag_rounded,
                      required: true,
                    ),
                    _buildField(
                      controller: _model,
                      label: 'Model & Manufacturer *',
                      icon: Icons.laptop_mac_rounded,
                      required: true,
                    ),
                  ],
                ),

                const SectionLabel('SPECIFICATIONS'),
                FintechGroupedCard(
                  children: [
                    _buildField(
                      controller: _cpu,
                      label: 'Processor (CPU)',
                      icon: Icons.memory_rounded,
                    ),
                    _buildField(
                      controller: _gpu,
                      label: 'Graphics (GPU)',
                      icon: Icons.videogame_asset_outlined,
                    ),
                    _buildField(
                      controller: _ram,
                      label: 'Memory (RAM)',
                      icon: Icons.storage_rounded,
                    ),
                    _buildField(
                      controller: _storage,
                      label: 'Storage Drive',
                      icon: Icons.disc_full_outlined,
                    ),
                  ],
                ),

                const SectionLabel('HARDWARE CONDITION'),
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

                const SectionLabel('USER ASSIGNMENT & ACCESS'),
                FintechGroupedCard(
                  children: [
                    InkWell(
                      onTap: () async {
                        final picked = await showFintechEmployeePicker(
                          context: context,
                          employees: _employees,
                          selectedEmployeeId: _selEmp?.id,
                          title: 'Assign Employee',
                          allowNone: true,
                        );
                        if (picked == null || !mounted) {
                          return;
                        }
                        setState(() {
                          _selEmp = picked.cleared ? null : picked.employee;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Assigned Employee',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                          suffixIcon: Icon(Icons.search_rounded, size: 20),
                        ),
                        child: Text(
                          _selEmp != null
                              ? (_selEmp!.phoneNumber.isNotEmpty
                                  ? '${_selEmp!.name} (${_selEmp!.phoneNumber})'
                                  : _selEmp!.name)
                              : 'Unassigned — Tap to search',
                          style: TextStyle(
                            fontWeight:
                                _selEmp != null ? FontWeight.w700 : FontWeight.normal,
                            color: _selEmp != null
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _pass,
                      obscureText: !_showPass,
                      decoration: InputDecoration(
                        labelText: 'Admin / Login Password',
                        prefixIcon:
                            const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 19,
                          ),
                          onPressed: () =>
                              setState(() => _showPass = !_showPass),
                        ),
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
                      isNew ? 'Save Laptop' : 'Update Laptop',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
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
