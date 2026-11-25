import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/employee.dart';
import '../../models/log_entry.dart';
import '../../widgets/common_widgets.dart';

const _logColor = Color(0xFF6366F1);

class LogFormScreen extends StatefulWidget {
  final LogEntry? entry;
  const LogFormScreen({super.key, this.entry});

  @override
  State<LogFormScreen> createState() => _LogFormScreenState();
}

class _LogFormScreenState extends State<LogFormScreen> {
  final _key = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _db = DatabaseHelper();
  bool _saving = false;
  DateTime _date = DateTime.now();

  List<Employee> _employees = [];
  int? _selectedEmployeeId;
  String _selectedEmployeeName = '';

  late final _problem = TextEditingController(text: widget.entry?.problem ?? '');
  late final _solution = TextEditingController(text: widget.entry?.solution ?? '');
  late String _selectedState = widget.entry?.state ?? 'Open';
  late String _selectedPriority = widget.entry?.priority ?? 'Low';

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _date = DateTime.tryParse(widget.entry!.date) ?? DateTime.now();
      _selectedEmployeeId = widget.entry!.employeeId;
      _selectedEmployeeName = widget.entry!.employeeName;
    }
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final list = await _db.getEmployees();
    if (!mounted) {
      return;
    }
    setState(() => _employees = list);
  }

  @override
  void dispose() {
    _problem.dispose();
    _solution.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _openEmployeePicker() async {
    final picked = await showFintechEmployeePicker(
      context: context,
      employees: _employees,
      selectedEmployeeId: _selectedEmployeeId,
      title: 'Select Requester (Employee)',
      allowNone: true,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (picked.cleared || picked.employee == null) {
        _selectedEmployeeId = null;
        _selectedEmployeeName = '';
      } else {
        _selectedEmployeeId = picked.employee!.id;
        _selectedEmployeeName = picked.employee!.name;
      }
    });
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    setState(() => _saving = true);
    try {
      final entry = LogEntry(
        id: widget.entry?.id,
        date: DateFormat('yyyy-MM-dd').format(_date),
        employeeId: _selectedEmployeeId,
        employeeName: _selectedEmployeeName,
        problem: _problem.text.trim(),
        solution: _solution.text.trim(),
        state: _selectedState,
        priority: _selectedPriority,
      );
      if (widget.entry == null) {
        await _db.insertLogEntry(entry);
      } else {
        await _db.updateLogEntry(entry);
      }
      if (!mounted) {
        return;
      }
      showSnack(context, widget.entry == null ? 'Ticket logged' : 'Ticket updated');
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entry != null;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: FintechAppBar(
        title: isEdit ? 'Edit Ticket' : 'New Support Ticket',
      ),
      body: ShakeWidget(
        key: _shakeKey,
        child: Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          key: _key,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              FintechGroupedCard(
                title: 'Ticket Status & Priority',
                icon: Icons.tune_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FintechDropdown<String>(
                          prefixIcon: const Icon(Icons.sync_rounded),
                          labelText: 'Status',
                          value: _selectedState,
                          items: const [
                            DropdownMenuItem(value: 'Open', child: Text('Open', style: TextStyle(fontWeight: FontWeight.w600))),
                            DropdownMenuItem(value: 'Closed', child: Text('Closed', style: TextStyle(fontWeight: FontWeight.w600))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedState = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FintechDropdown<String>(
                          prefixIcon: const Icon(Icons.priority_high_rounded),
                          labelText: 'Priority',
                          value: _selectedPriority,
                          items: const [
                            DropdownMenuItem(value: 'Low', child: Text('Low', style: TextStyle(fontWeight: FontWeight.w600))),
                            DropdownMenuItem(value: 'Medium', child: Text('Medium', style: TextStyle(fontWeight: FontWeight.w600))),
                            DropdownMenuItem(value: 'High', child: Text('High', style: TextStyle(fontWeight: FontWeight.w600))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedPriority = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FintechGroupedCard(
                title: 'Requester & Date',
                icon: Icons.person_outline_rounded,
                children: [
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                        labelText: 'Ticket Date',
                      ),
                      child: Text(
                        DateFormat('EEEE, dd MMM yyyy').format(_date),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _openEmployeePicker,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.badge_outlined),
                        labelText: 'Employee Requester',
                        suffixIcon: _selectedEmployeeId != null
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                tooltip: 'Clear Requester',
                                onPressed: () {
                                  setState(() {
                                    _selectedEmployeeId = null;
                                    _selectedEmployeeName = '';
                                  });
                                },
                              )
                            : const Icon(Icons.search_rounded, size: 20),
                      ),
                      child: Text(
                        _selectedEmployeeId != null && _selectedEmployeeName.isNotEmpty
                            ? _selectedEmployeeName
                            : 'None (General IT issue)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedEmployeeId != null ? FontWeight.w600 : FontWeight.normal,
                          color: _selectedEmployeeId != null
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FintechGroupedCard(
                title: 'Problem & Resolution',
                icon: Icons.description_outlined,
                children: [
                  AppTextField(
                    controller: _problem,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Issue Description *',
                      prefixIcon: Icon(Icons.report_problem_outlined),
                      hintText: 'Describe the technical problem or support inquiry…',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Problem description is required' : null,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _solution,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Resolution / Notes',
                      prefixIcon: Icon(Icons.check_circle_outline),
                      hintText: 'Describe steps taken to resolve the ticket…',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  isEdit ? 'Save Ticket Changes' : 'Submit Support Ticket',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _logColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
