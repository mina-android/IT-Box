import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/database_helper.dart';
import '../../models/employee.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import '../../theme/app_theme.dart';
import 'employee_form_screen.dart';
import 'employee_360_screen.dart';

class EmployeesScreen extends StatefulWidget {
  final int? initialItemId;
  const EmployeesScreen({super.key, this.initialItemId});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  Timer? _debounce;
  final _db = DatabaseHelper();
  StreamSubscription<List<Employee>>? _sub;
  final _search = TextEditingController();
  List<Employee> _all = [];
  List<Employee> _filtered = [];
  bool _loading = true;
  bool _showSearch = false;
  bool _handledInitial = false;
  final Set<int> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _sub = _db.watchEmployees().listen((list) {
      if (mounted) {
        setState(() {
          _all = list;
          _filter();
          _loading = false;
        });
        if (!_handledInitial && widget.initialItemId != null) {
          final match = list.where((e) => e.id == widget.initialItemId).firstOrNull;
          if (match != null) {
            _handledInitial = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showEmployeeDetails(match);
              }
            });
          }
        }
      }
    });
    _search.addListener(() {
      if (_debounce?.isActive ?? false) {
        _debounce!.cancel();
      }
      _debounce = Timer(const Duration(milliseconds: 300), _filter);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader && _all.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      _all = await _db.getEmployees();
      _filter();
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to load employees: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _filter() {
    final q = _search.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_all)
          : _all.where((e) =>
              e.name.toLowerCase().contains(q) ||
              e.phoneNumber.toLowerCase().contains(q)
            ).toList();
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDelete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Employees',
      message: 'Are you sure you want to delete ${_selectedIds.length} employee(s)?',
    );
    if (!ok || !mounted) {
      return;
    }
    int deleted = 0;
    int skippedDeps = 0;
    for (final id in _selectedIds) {
      final counts = await _db.getEmployeeDependentCounts(id);
      if ((counts['active_borrows'] ?? 0) > 0 ||
          (counts['laptops'] ?? 0) > 0 ||
          (counts['emails'] ?? 0) > 0) {
        skippedDeps++;
        continue;
      }
      try {
        await _db.deleteEmployee(id);
        deleted++;
      } catch (_) {
        skippedDeps++;
      }
    }
    setState(() => _selectedIds.clear());
    if (!mounted) {
      return;
    }
    if (skippedDeps > 0) {
      showSnack(
        context,
        '$deleted employee(s) deleted. $skippedDeps skipped due to active borrows, assigned laptops, or linked emails.',
        error: deleted == 0,
      );
    } else {
      showSnack(context, '$deleted employee(s) deleted');
    }
    _load();
  }

  Future<void> _openForm([Employee? e]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EmployeeFormScreen(employee: e)),
    );
    if (ok == true && mounted) {
      _load();
    }
  }

  Future<void> _delete(Employee e) async {
    final counts = await _db.getEmployeeDependentCounts(e.id!);
    if (!mounted) {
      return;
    }
    final activeBorrows = counts['active_borrows'] ?? 0;
    final laptops = counts['laptops'] ?? 0;
    final emails = counts['emails'] ?? 0;
    final tickets = counts['tickets'] ?? 0;

    if (activeBorrows > 0 || laptops > 0 || emails > 0) {
      final blockers = <String>[
        if (activeBorrows > 0) '$activeBorrows active borrow(s)',
        if (laptops > 0) '$laptops assigned laptop(s)',
        if (emails > 0) '$emails linked email(s)',
      ];
      showSnack(
        context,
        'Cannot delete "${e.name}" while linked to ${blockers.join(', ')}. Unassign them first.',
        error: true,
      );
      return;
    }

    String confirmMessage = 'Delete "${e.name}" from your employee directory?';
    if (tickets > 0) {
      confirmMessage = 'Delete "${e.name}"?\n\nWarning: Associated with $tickets ticket(s).';
    }

    final ok = await showConfirmDialog(
      context,
      title: 'Delete Employee',
      message: confirmMessage,
    );
    if (!ok || !mounted) {
      return;
    }
    try {
      await _db.deleteEmployee(e.id!);
      if (!mounted) {
        return;
      }
      showSnack(context, 'Employee deleted');
      _load();
    } catch (err) {
      if (!mounted) return;
      showSnack(context, 'Error deleting employee: $err', error: true);
    }
  }

  String _initials(String n) => n.trim().split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0])
      .take(2)
      .join()
      .toUpperCase();

  void _showEmployeeDetails(Employee emp) {
    showFintechBottomSheet(
      context: context,
      title: 'Employee Profile',
      subtitle: emp.name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              _initials(emp.name),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            emp.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FintechGroupedCard(
            title: 'Contact Information',
            icon: Icons.contact_phone_outlined,
            children: [
              DetailRow(
                label: 'Full Name',
                value: emp.name,
                icon: Icons.person_outline,
                isCopyable: true,
              ),
              DetailRow(
                label: 'Phone Number',
                value: emp.phoneNumber.isNotEmpty ? emp.phoneNumber : 'Not provided',
                icon: Icons.phone_outlined,
                isCopyable: emp.phoneNumber.isNotEmpty,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (emp.phoneNumber.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: emp.phoneNumber));
                      showSnack(context, 'Phone number copied');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy Phone'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openForm(emp);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => Employee360Screen(employee: emp)),
                );
              },
              icon: const Icon(Icons.person_search_rounded, size: 18),
              label: const Text('View 360° Dossier & Exit Checklist'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Employees Directory',
        subtitle: '${_all.length} registered personnel',
        actions: [
          FintechCircleButton(
            icon: _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
            tooltip: 'Search',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _search.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            SearchBar2(controller: _search, hintText: 'Search by employee name or phone…'),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline_rounded,
                        title: _search.text.isEmpty ? 'No Employees Found' : 'No Matching Employees',
                        subtitle: _search.text.isEmpty
                            ? 'Create staff profiles to assign borrowed devices & equipment.'
                            : 'Try adjusting your search criteria.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                            final e = _filtered[i];
                            final isSelected = _selectedIds.contains(e.id);
                            return SlideInAndFade(
                              index: i,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.08)
                                      : AppColors.cardSurface(context),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () {
                                    if (_isSelectionMode) {
                                      _toggleSelection(e.id!);
                                    } else {
                                      _showEmployeeDetails(e);
                                    }
                                  },
                                  onLongPress: () => _toggleSelection(e.id!),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        if (_isSelectionMode)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 12),
                                            child: Icon(
                                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                              color: isSelected ? AppColors.primary : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                            ),
                                          )
                                        else
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                            child: Text(
                                              _initials(e.name),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                e.name,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                              ),
                                              const SizedBox(height: 4),
                                              if (e.phoneNumber.isNotEmpty)
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.phone_outlined,
                                                      size: 13,
                                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      e.phoneNumber,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              else
                                                Text(
                                                  'No phone recorded',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (!_isSelectionMode)
                                          PopupMenuButton<String>(
                                            icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            onSelected: (val) {
                                              if (val == 'view') {
                                                _showEmployeeDetails(e);
                                              } else if (val == 'edit') {
                                                _openForm(e);
                                              } else if (val == 'delete') {
                                                _delete(e);
                                              }
                                            },
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(
                                                value: 'view',
                                                child: Row(children: [Icon(Icons.visibility_outlined, size: 18), SizedBox(width: 10), Text('View Details')]),
                                              ),
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 10), Text('Edit')]),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 10), Text('Delete', style: TextStyle(color: Colors.red))]),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : SmoothExitFab(
              child: FintechFab(
                onPressed: () => _openForm(),
                color: Theme.of(context).colorScheme.primary,
                tooltip: 'Add Employee',
              ),
            ),
      bottomNavigationBar: _isSelectionMode
          ? SelectionBottomBar(
              selectedCount: _selectedIds.length,
              totalCount: _filtered.length,
              onSelectAll: () {
                setState(() {
                  _selectedIds.addAll(_filtered.where((e) => e.id != null).map((e) => e.id!));
                });
              },
              onDeselectAll: () => setState(() => _selectedIds.clear()),
              onClose: () => setState(() => _selectedIds.clear()),
              onDelete: _bulkDelete,
            )
          : null,
    );
  }
}
