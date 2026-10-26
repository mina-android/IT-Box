import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/database_helper.dart';
import '../../models/email_account.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import '../../theme/app_theme.dart';
import 'email_form_screen.dart';

const _emailColor = Color(0xFF0EA5E9);

class EmailsScreen extends StatefulWidget {
  const EmailsScreen({super.key});

  @override
  State<EmailsScreen> createState() => _EmailsScreenState();
}

class _EmailsScreenState extends State<EmailsScreen> {
  Timer? _debounce;
  final _db = DatabaseHelper();
  final _search = TextEditingController();
  List<EmailAccount> _all = [];
  List<EmailAccount> _filtered = [];
  bool _loading = true;
  final Set<int> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbChanged);
    _load();
    _search.addListener(() {
      if (_debounce?.isActive ?? false) {
        _debounce!.cancel();
      }
      _debounce = Timer(const Duration(milliseconds: 300), _filter);
    });
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChanged);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onDbChanged() {
    if (mounted) {
      _load(showLoader: false);
    }
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader && _all.isEmpty) {
      setState(() => _loading = true);
    }
    _all = await _db.getEmailAccounts();
    _filter();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _search.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_all)
          : _all.where((e) =>
              e.email.toLowerCase().contains(q) ||
              e.employeeName.toLowerCase().contains(q)
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
      title: 'Delete Emails',
      message: 'Delete ${_selectedIds.length} email account(s)?',
    );
    if (!ok || !mounted) {
      return;
    }
    for (final id in _selectedIds) {
      await _db.deleteEmailAccount(id);
    }
    setState(() => _selectedIds.clear());
    _load();
  }

  Future<void> _openForm([EmailAccount? acc]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EmailFormScreen(account: acc)),
    );
    if (ok == true && mounted) {
      _load();
    }
  }

  Future<void> _delete(EmailAccount acc) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Email Account',
      message: 'Delete credentials for "${acc.email}"?',
    );
    if (!ok || !mounted) {
      return;
    }
    await _db.deleteEmailAccount(acc.id!);
    if (!mounted) {
      return;
    }
    showSnack(context, 'Email account deleted');
    _load();
  }

  void _showDetail(EmailAccount acc) {
    bool showPass = false;
    showFintechBottomSheet(
      context: context,
      title: 'Email Credentials',
      subtitle: acc.email,
      child: StatefulBuilder(
        builder: (ctx, setS) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FintechGroupedCard(
              title: 'Account Information',
              icon: Icons.alternate_email_rounded,
              children: [
                DetailRow(
                  label: 'Email Address',
                  value: acc.email,
                  icon: Icons.email_outlined,
                  textStyle: credentialFont(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                  isCopyable: true,
                ),
                DetailRow(
                  label: 'Assigned User',
                  value: acc.employeeName.isNotEmpty ? acc.employeeName : 'Unassigned',
                  icon: Icons.person_outline,
                  isCopyable: acc.employeeName.isNotEmpty,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        showPass ? acc.password : '••••••••••••',
                        style: credentialFont(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                        onPressed: () => setS(() => showPass = !showPass),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.copy_rounded, size: 18, color: _emailColor),
                        tooltip: 'Copy Password',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: acc.password));
                          showSnack(ctx, 'Password copied');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _delete(acc);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openForm(acc);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _emailColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: FintechAppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: 'Corporate Emails',
        subtitle: '${_all.length} registered mail accounts',
        actions: [
          if (_isSelectionMode)
            FintechCircleButton(
              icon: Icons.select_all_rounded,
              tooltip: 'Select All',
              onPressed: () {
                setState(() {
                  if (_selectedIds.length == _filtered.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(_filtered.map((e) => e.id!));
                  }
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          SearchBar2(controller: _search, hintText: 'Search email address or employee…'),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.mail_outline_rounded,
                        title: _search.text.isEmpty ? 'No Email Accounts' : 'No Results Found',
                        subtitle: _search.text.isEmpty
                            ? 'Store corporate email accounts and security credentials safely offline.'
                            : 'Try searching with different terms.',
                        onRefresh: _load,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                            final acc = _filtered[i];
                            final isSelected = _selectedIds.contains(acc.id);
                            return SlideInAndFade(
                              index: i,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _emailColor.withValues(alpha: 0.08)
                                      : (isDark ? AppColors.darkCard : Colors.white),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected
                                        ? _emailColor
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
                                      _toggleSelection(acc.id!);
                                    } else {
                                      _showDetail(acc);
                                    }
                                  },
                                  onLongPress: () => _toggleSelection(acc.id!),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        if (_isSelectionMode)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 12),
                                            child: Icon(
                                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                              color: isSelected ? _emailColor : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                            ),
                                          )
                                        else
                                          const IconBox(
                                            icon: Icons.alternate_email_rounded,
                                            color: _emailColor,
                                            size: 42,
                                          ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                acc.email,
                                                style: credentialFont(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14.5,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.person_outline,
                                                    size: 13,
                                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      acc.employeeName.isNotEmpty ? acc.employeeName : 'Unassigned',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!_isSelectionMode) ...[
                                          IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 18),
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                            tooltip: 'Copy Email',
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: acc.email));
                                              showSnack(context, 'Email copied');
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.key_rounded, size: 18, color: _emailColor),
                                            tooltip: 'Copy Password',
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: acc.password));
                                              showSnack(context, 'Password copied');
                                            },
                                          ),
                                        ],
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
          : Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FintechFab(
                onPressed: () => _openForm(),
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF0284C7),
                tooltip: 'Add Account',
              ),
            ),
      bottomNavigationBar: _isSelectionMode
          ? SelectionBottomBar(
              selectedCount: _selectedIds.length,
              onClose: () => setState(() => _selectedIds.clear()),
              onDelete: _bulkDelete,
            )
          : null,
    );
  }
}
