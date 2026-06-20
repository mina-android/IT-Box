import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/employee.dart';
import '../../models/log_entry.dart';
import '../../widgets/common_widgets.dart';

class LogFormScreen extends StatefulWidget {
  final LogEntry? entry;
  const LogFormScreen({super.key, this.entry});
  @override
  State<LogFormScreen> createState() => _State();
}

class _State extends State<LogFormScreen> {
  final _key = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  bool _saving = false;
  DateTime _date = DateTime.now();

  List<Employee> _employees = [];
  int? _selectedEmployeeId;
  String _selectedEmployeeName = '';

  late final _problem  = TextEditingController(text: widget.entry?.problem ?? '');
  late final _solution = TextEditingController(text: widget.entry?.solution ?? '');

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
    if (!mounted) return;
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
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final entry = LogEntry(
        id: widget.entry?.id,
        date: DateFormat('yyyy-MM-dd').format(_date),
        employeeId: _selectedEmployeeId,
        employeeName: _selectedEmployeeName,
        problem: _problem.text.trim(),
        solution: _solution.text.trim(),
      );
      if (widget.entry == null) {
        await _db.insertLogEntry(entry);
      } else {
        await _db.updateLogEntry(entry);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entry != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Log' : 'Add Log')),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          const SectionLabel('DATE'),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.calendar_today_outlined),
                labelText: 'Date',
              ),
              child: Text(
                DateFormat('dd MMMM yyyy').format(_date),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SectionLabel('USER'),
          InputDecorator(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline),
              labelText: 'Employee',
            ),
            child: DropdownButton<int?>(
              value: _selectedEmployeeId,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: const Text('Select employee (optional)'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('— None —'),
                ),
                ..._employees.map((e) => DropdownMenuItem<int?>(
                  value: e.id,
                  child: Text(e.name),
                )),
              ],
              onChanged: (id) {
                setState(() {
                  _selectedEmployeeId = id;
                  _selectedEmployeeName = id == null
                    ? ''
                    : _employees.firstWhere((e) => e.id == id).name;
                });
              },
            ),
          ),
          const SectionLabel('LOG DETAILS'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              controller: _problem,
              enableSuggestions: false,
              autocorrect: false,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Problem *',
                prefixIcon: Icon(Icons.report_problem_outlined),
                alignLabelWithHint: true,
                hintText: 'Describe the issue...',
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              controller: _solution,
              enableSuggestions: false,
              autocorrect: false,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Solution',
                prefixIcon: Icon(Icons.check_circle_outline),
                alignLabelWithHint: true,
                hintText: 'How was it resolved?',
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined),
            label: Text(isEdit ? 'Update Log' : 'Add Log'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
          ),
        ]),
      ),
    );
  }
}
