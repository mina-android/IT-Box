// lib/screens/employees/employee_360_screen.dart
import 'package:flutter/material.dart';
import '../../models/employee.dart';
import '../../models/laptop.dart';
import '../../models/borrow_log.dart';
import '../../models/email_account.dart';
import '../../models/log_entry.dart';
import '../../models/custody_document.dart';
import '../../models/vault_document.dart';
import '../../database/database_helper.dart';
import '../../services/custody_pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../documents_vault/document_viewer_screen.dart';

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
  List<CustodyDocument> _custodyDocs = [];
  List<VaultDocument> _vaultDocs = [];

  @override
  void initState() {
    super.initState();
    _loadDossier();
  }

  Future<void> _loadDossier() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _db.getLaptops(),
      _db.getBorrowLogs(),
      _db.getEmailAccounts(),
      _db.getLogEntries(),
      _db.getCustodyDocuments(),
      _db.getVaultDocuments(),
    ]);

    final allLaptops = results[0] as List<Laptop>;
    final allBorrows = results[1] as List<BorrowLog>;
    final allEmails = results[2] as List<EmailAccount>;
    final allTickets = results[3] as List<LogEntry>;
    final allCustody = results[4] as List<CustodyDocument>;
    final allVault = results[5] as List<VaultDocument>;

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
    _custodyDocs = allCustody
        .where((c) => c.employeeName.toLowerCase() == empName)
        .toList();
    _vaultDocs = allVault
        .where((v) => v.linkedEmployeeName.toLowerCase() == empName)
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

    showFintechBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          final allDone = checklist.values.every((v) => v);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
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
                              showSnack(context, 'Offboarding clearance verified and archived.');
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

    showFintechBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          final allDone = checklist.values.every((v) => v);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
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
                              showSnack(context, 'Employee onboarding recorded in Audit Trail.');
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
      appBar: FintechAppBar(
        title: '${widget.employee.name} — 360° Profile',
        actions: [
          FintechCircleButton(
            icon: Icons.person_add_alt_1_rounded,
            iconColor: AppColors.good,
            tooltip: 'Onboard Employee',
            onPressed: _startOnboardingChecklist,
          ),
          FintechCircleButton(
            icon: Icons.exit_to_app_rounded,
            iconColor: Colors.redAccent,
            tooltip: 'Offboarding Exit Checklist',
            onPressed: _startOffboardingChecklist,
          ),
        ],
      ),
      body: _loading
          ? const ShimmerListLoader()
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
                        Text(
                          'EMPLOYEE DOSSIER',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.employee.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Phone: ${widget.employee.phoneNumber.isNotEmpty ? widget.employee.phoneNumber : "No phone registered"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
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
                              title: Text(e.email, style: credentialFont(fontSize: 13.5)),
                              subtitle: const Text('Password: ••••••••'),
                            )).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Custody Documents
                  FintechGroupedCard(
                    title: 'Custody Documents (${_custodyDocs.length})',
                    children: _custodyDocs.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(8), child: Text('No custody documents recorded.'))]
                        : _custodyDocs.map((c) => ListTile(
                              leading: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF6366F1)),
                              title: Text(c.documentNumber, style: credentialFont(fontSize: 13.5)),
                              subtitle: Text('${c.handoverDate} • ${c.items.map((i) => i.deviceName).join(', ')}'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () async {
                                final nav = Navigator.of(context);
                                final file = await CustodyPdfService.ensureCustodyPdfFile(c);
                                if (!mounted) {
                                  return;
                                }
                                nav.push(
                                  MaterialPageRoute(
                                    builder: (_) => DocumentViewerScreen(
                                      title: '${c.documentNumber} • ${c.employeeName}',
                                      filePath: file.path,
                                      isPdf: true,
                                    ),
                                  ),
                                );
                              },
                            )).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Vault Documents
                  FintechGroupedCard(
                    title: 'Vault Documents (${_vaultDocs.length})',
                    children: _vaultDocs.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(8), child: Text('No vault documents linked.'))]
                        : _vaultDocs.map((v) => ListTile(
                              leading: Icon(
                                v.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                                color: VaultDocument.colorForCategory(v.category),
                              ),
                              title: Text(v.title),
                              subtitle: Text('${v.category} • ${v.formattedSize}'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DocumentViewerScreen(
                                      title: v.title,
                                      filePath: v.filePath,
                                      isPdf: v.isPdf,
                                    ),
                                  ),
                                );
                              },
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
