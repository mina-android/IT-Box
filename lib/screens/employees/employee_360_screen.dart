// lib/screens/employees/employee_360_screen.dart
import 'package:flutter/material.dart';
import '../../models/employee.dart';
import '../../models/laptop.dart';
import '../../models/borrow_log.dart';
import '../../models/email_account.dart';
import '../../models/log_entry.dart';
import '../../database/database_helper.dart';
import '../../widgets/common_widgets.dart';

class Employee360Screen extends StatefulWidget {
  final Employee employee;
  const Employee360Screen({super.key, required this.employee});

  @override
  State<Employee360Screen> createState() => _Employee360ScreenState();
}

class _Employee360ScreenState extends State<Employee360Screen> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _loading = true;

  List<Laptop> _laptops = [];
  List<BorrowLog> _borrows = [];
  List<EmailAccount> _emails = [];
  List<LogEntry> _tickets = [];

  @override
  void initState() {
    super.initState();
    _loadDossier();
  }

  Future<void> _loadDossier() async {
    setState(() => _loading = true);
    final allLaptops = await _db.getLaptops();
    final allBorrows = await _db.getBorrowLogs();
    final allEmails = await _db.getEmailAccounts();
    final allTickets = await _db.getLogEntries();

    final empName = widget.employee.name.toLowerCase();

    _laptops = allLaptops.where((l) => l.user.toLowerCase() == empName).toList();
    _borrows = allBorrows
        .where((b) => !b.isReturned && (b.employeeId == widget.employee.id || b.employeeName.toLowerCase() == empName))
        .toList();
    _emails = allEmails
        .where((e) => e.employeeId == widget.employee.id || e.employeeName.toLowerCase() == empName)
        .toList();
    _tickets = allTickets
        .where((t) => t.employeeId == widget.employee.id || t.employeeName.toLowerCase() == empName)
        .toList();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _startOffboardingChecklist() {
    final checklist = <String, bool>{};

    for (final l in _laptops) {
      checklist['Recover Laptop (${l.model} #${l.laptopNumber})'] = false;
    }
    for (final b in _borrows) {
      checklist['Return Borrowed Gear (${b.deviceName} #${b.deviceNumber})'] = false;
    }
    for (final e in _emails) {
      checklist['Revoke / Reset Email (${e.email})'] = false;
    }
    checklist['Revoke Building Keycards / Physical Badges'] = false;
    checklist['Sign Exit Clearance & Handover Form'] = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final allDone = checklist.values.every((v) => v);
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Offboarding: ${widget.employee.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Complete all recovery tasks to finalize exit clearance.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Divider(height: 20),
                ...checklist.keys.map((task) {
                  return CheckboxListTile(
                    title: Text(task, style: const TextStyle(fontSize: 13.5)),
                    value: checklist[task],
                    onChanged: (v) {
                      setSheetState(() => checklist[task] = v ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: allDone ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: allDone
                        ? () async {
                            await _db.logAuditActivity(
                              'OFFBOARD',
                              'Employee',
                              entityId: widget.employee.id,
                              description: 'Completed full offboarding checklist for ${widget.employee.name}',
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Offboarding clearance verified and archived.')),
                              );
                            }
                          }
                        : null,
                    child: Text(allDone ? 'Finalize Offboarding Clearance' : 'Complete All Tasks Above'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _startOnboardingChecklist() {
    final checklist = <String, bool>{
      'Issue Workstation / Computing Hardware': _laptops.isNotEmpty,
      'Setup Corporate Email Account': _emails.isNotEmpty,
      'Grant Wi-Fi & Internal Network Credentials': false,
      'Issue Physical Building Keycard / Badge': false,
      'Sign IT Equipment & Security Policy': false,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final allDone = checklist.values.every((v) => v);
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Onboard: ${widget.employee.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Verify onboarding prerequisites to record employee entry in audit trail.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Divider(height: 20),
                ...checklist.keys.map((task) {
                  return CheckboxListTile(
                    title: Text(task, style: const TextStyle(fontSize: 13.5)),
                    value: checklist[task],
                    onChanged: (v) {
                      setSheetState(() => checklist[task] = v ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: allDone ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: allDone
                        ? () async {
                            await _db.logAuditActivity(
                              'ONBOARD',
                              'Employee',
                              entityId: widget.employee.id,
                              description: 'Completed full onboarding verification for ${widget.employee.name}',
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Employee onboarding recorded in Audit Trail.')),
                              );
                            }
                          }
                        : null,
                    child: Text(allDone ? 'Log & Finalize Onboarding' : 'Complete All Checklist Items'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.employee.name} — 360° Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.greenAccent),
            tooltip: 'Onboard Employee',
            onPressed: _startOnboardingChecklist,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
            tooltip: 'Offboarding Exit Checklist',
            onPressed: _startOffboardingChecklist,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  FintechHeroCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('EMPLOYEE DOSSIER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                        const SizedBox(height: 6),
                        Text(widget.employee.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          'Phone: ${widget.employee.phoneNumber.isNotEmpty ? widget.employee.phoneNumber : "No phone registered"}',
                          style: const TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Assigned Laptops
                  FintechGroupedCard(
                    title: 'Assigned Laptops (${_laptops.length})',
                    children: _laptops.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(8), child: Text('No laptop currently assigned.'))]
                        : _laptops.map((l) => ListTile(
                              leading: const Icon(Icons.laptop_chromebook_rounded),
                              title: Text('${l.model} (#${l.laptopNumber})'),
                              subtitle: Text('${l.cpu} • ${l.ram} • ${l.storage}'),
                            )).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Active Borrows
                  FintechGroupedCard(
                    title: 'Active Borrows (${_borrows.length})',
                    children: _borrows.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(8), child: Text('No active gear borrows.'))]
                        : _borrows.map((b) => ListTile(
                              leading: const Icon(Icons.wifi_tethering_rounded, color: Colors.amber),
                              title: Text('${b.deviceName} (#${b.deviceNumber})'),
                              subtitle: Text('Due: ${b.dueDate ?? "Not specified"} • Out: ${b.outDate}'),
                            )).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Corporate Email Accounts
                  FintechGroupedCard(
                    title: 'Corporate Email Accounts (${_emails.length})',
                    children: _emails.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(8), child: Text('No email accounts assigned.'))]
                        : _emails.map((e) => ListTile(
                              leading: const Icon(Icons.alternate_email_rounded),
                              title: Text(e.email),
                              subtitle: const Text('Password: ••••••••'),
                            )).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Trouble Tickets History
                  FintechGroupedCard(
                    title: 'Reported Support Logs (${_tickets.length})',
                    children: _tickets.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(8), child: Text('No support logs filed.'))]
                        : _tickets.map((t) => ListTile(
                              leading: Icon(
                                t.state == 'Open' ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                                color: t.state == 'Open' ? Colors.redAccent : Colors.green,
                              ),
                              title: Text(t.problem),
                              subtitle: Text('${t.date} • Priority: ${t.priority} • Status: ${t.state}'),
                            )).toList(),
                  ),
                ],
              ),
            ),
    );
  }
}
