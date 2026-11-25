// lib/screens/accounts_passwords/accounts_passwords_screen.dart
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/account_password.dart';
import '../../widgets/common_widgets.dart';
import 'account_password_form_screen.dart';

class AccountsPasswordsScreen extends StatefulWidget {
  final int? initialItemId;
  const AccountsPasswordsScreen({super.key, this.initialItemId});

  @override
  State<AccountsPasswordsScreen> createState() => _AccountsPasswordsScreenState();
}

class _AccountsPasswordsScreenState extends State<AccountsPasswordsScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _showSearch = false;
  bool _handledInitial = false;
  List<AccountPassword> _accounts = [];
  final Set<int> _revealedPasswords = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadAccounts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    final items = await _db.getAccountPasswords();
    if (mounted) {
      setState(() {
        _accounts = items;
        _loading = false;
      });
      if (!_handledInitial && widget.initialItemId != null) {
        final match = items.where((a) => a.id == widget.initialItemId).firstOrNull;
        if (match != null) {
          _handledInitial = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _openForm(match);
            }
          });
        }
      }
    }
  }

  List<AccountPassword> get _filtered {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) return _accounts;
    return _accounts.where((a) {
      return a.platform.toLowerCase().contains(q) ||
          a.emailUsername.toLowerCase().contains(q);
    }).toList();
  }

  void _copyToClipboard(String text, String label) {
    copySensitiveToClipboard(context, text, label);
  }

  Future<void> _openForm([AccountPassword? existing]) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountPasswordFormScreen(account: existing),
      ),
    );
    if (res == true && mounted) {
      _loadAccounts();
    }
  }

  Future<void> _deleteAccount(AccountPassword acc) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Account Credentials',
      message: 'Are you sure you want to delete credentials for "${acc.platform}" (${acc.emailUsername})? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );
    if (ok && acc.id != null) {
      await _db.deleteAccountPassword(acc.id!);
      if (mounted) {
        _loadAccounts();
        showSnack(context, 'Account credentials removed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filtered = _filtered;

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Accounts & Passwords Vault',
        subtitle: '${_accounts.length} credentials stored securely offline',
        actions: [
          FintechCircleButton(
            icon: _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
            tooltip: 'Search',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                }
              });
            },
          ),
        ],
      ),
      floatingActionButton: SmoothExitFab(
        child: FintechFab(
          onPressed: () => _openForm(),
          tooltip: 'Add Account',
          icon: Icons.add_rounded,
        ),
      ),
      body: Column(
        children: [
          if (_showSearch)
            SearchBar2(
              controller: _searchCtrl,
              hint: 'Search platform, email, or username...',
            ),

          // Accounts List
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.vpn_key_off_outlined,
                        title: _searchCtrl.text.isEmpty ? 'No Accounts Stored Yet' : 'No Matching Accounts',
                        subtitle: _searchCtrl.text.isEmpty
                            ? 'Tap + to save platform logins and passwords'
                            : 'No accounts match "${_searchCtrl.text}"',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final acc = filtered[i];
                          final accId = acc.id ?? i;
                          final isRevealed = _revealedPasswords.contains(accId);

                          return SlideInAndFade(
                            index: i,
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: cs.outlineVariant.withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.key_rounded,
                                          color: cs.primary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              acc.platform,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              acc.emailUsername,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: cs.onSurface.withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 18),
                                        tooltip: 'Copy Email/Username',
                                        onPressed: () => _copyToClipboard(acc.emailUsername, 'Username/Email'),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, size: 20),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        onSelected: (val) {
                                          if (val == 'edit') {
                                            _openForm(acc);
                                          } else if (val == 'delete') {
                                            _deleteAccount(acc);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, size: 18),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Delete', style: TextStyle(color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),

                                  // Password bar
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Password: ',
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                        ),
                                        Expanded(
                                          child: Text(
                                            isRevealed ? acc.password : '••••••••••••',
                                            style: TextStyle(
                                              fontFamily: isRevealed ? 'monospace' : null,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              letterSpacing: isRevealed ? 0 : 2,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            size: 18,
                                          ),
                                          tooltip: isRevealed ? 'Hide Password' : 'Show Password',
                                          onPressed: () {
                                            setState(() {
                                              if (isRevealed) {
                                                _revealedPasswords.remove(accId);
                                              } else {
                                                _revealedPasswords.add(accId);
                                              }
                                            });
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 18),
                                          tooltip: 'Copy Password',
                                          onPressed: () => _copyToClipboard(acc.password, 'Password'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
