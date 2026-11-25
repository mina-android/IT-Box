// lib/screens/vendor_contacts/vendor_contacts_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../database/database_helper.dart';
import '../../models/vendor_contact.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/selection_bottom_bar.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import 'vendor_contact_form_screen.dart';

class VendorContactsScreen extends StatefulWidget {
  final int? initialItemId;
  const VendorContactsScreen({super.key, this.initialItemId});

  @override
  State<VendorContactsScreen> createState() => _VendorContactsScreenState();
}

class _VendorContactsScreenState extends State<VendorContactsScreen> {
  final _db = DatabaseHelper();
  late final Listenable _tablesListenable;
  final _searchCtrl = TextEditingController();

  List<VendorContact> _all = [];
  List<VendorContact> _filtered = [];
  String _selectedType = 'All';
  bool _loading = true;
  bool _showSearch = false;
  bool _handledInitial = false;
  final Set<int> _selectedIds = <int>{};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  static const List<String> _filterTypes = [
    'All',
    'ISP',
    'Vendor',
    'Hardware',
    'Domain/Registrar',
    'Cloud/SaaS',
    'Internal',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tablesListenable = _db.tables(['vendor_contacts']);
    _tablesListenable.addListener(_onTablesChanged);
    _searchCtrl.addListener(_applyFilters);
    _load();
  }

  @override
  void dispose() {
    _tablesListenable.removeListener(_onTablesChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onTablesChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final list = await _db.getVendorContacts();
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
      _applyFilters();
    });
    if (!_handledInitial && widget.initialItemId != null) {
      final match = list.where((c) => c.id == widget.initialItemId).firstOrNull;
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

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((c) {
        final matchesType = _selectedType == 'All' || c.contactType == _selectedType;
        if (!matchesType) return false;
        if (query.isEmpty) return true;
        return c.name.toLowerCase().contains(query) ||
            c.company.toLowerCase().contains(query) ||
            c.role.toLowerCase().contains(query) ||
            c.accountNumber.toLowerCase().contains(query) ||
            c.phoneNumber.toLowerCase().contains(query) ||
            c.email.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _toggleSelection(int id) {
    AppHaptics.tap(context, HapticStrength.selection);
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Contacts',
      message: 'Are you sure you want to delete $count contact(s)?',
    );
    if (!confirmed || !mounted) return;

    for (final id in _selectedIds) {
      await _db.deleteVendorContact(id);
    }
    if (!mounted) return;
    setState(() => _selectedIds.clear());
    showSnack(context, '$count contact(s) deleted');
    _load();
  }

  Future<void> _openForm([VendorContact? contact]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VendorContactFormScreen(contact: contact),
      ),
    );
    if (result == true && mounted) {
      _load();
    }
  }

  Future<void> _launchUrlStr(String urlStr) async {
    var formatted = urlStr.trim();
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'https://$formatted';
    }
    final uri = Uri.tryParse(formatted);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Vendor & Runbook Contacts',
        subtitle: '${_all.length} saved support contacts',
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
      floatingActionButton: _isSelectionMode
          ? null
          : SmoothExitFab(
              child: FintechFab(
                onPressed: () => _openForm(),
                color: AppColors.vendorColor,
                tooltip: 'Add Contact',
                icon: Icons.person_add_rounded,
              ),
            ),
      bottomNavigationBar: _isSelectionMode
          ? SelectionBottomBar(
              selectedCount: _selectedIds.length,
              totalCount: _filtered.length,
              onSelectAll: () {
                setState(() {
                  _selectedIds.addAll(_filtered.where((c) => c.id != null).map((c) => c.id!));
                });
              },
              onDeselectAll: () => setState(() => _selectedIds.clear()),
              onClose: () => setState(() => _selectedIds.clear()),
              onDelete: _bulkDelete,
            )
          : null,
      body: Column(
        children: [
          if (_showSearch)
            SearchBar2(
              hint: 'Search vendor, ISP, company, CID…',
              controller: _searchCtrl,
            ),
          FintechFilterBar(
            children: _filterTypes.map((type) {
              return FintechFilterPill(
                label: type,
                selected: _selectedType == type,
                color: AppColors.vendorColor,
                onTap: () {
                  setState(() {
                    _selectedType = type;
                    _applyFilters();
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.contact_phone_outlined,
                        title: _all.isEmpty ? 'No Runbook Contacts' : 'No Matching Contacts',
                        subtitle: _all.isEmpty
                            ? 'Tap + to add ISP, hardware, or software vendor contacts.'
                            : 'No contacts match your current search or filter.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final c = _filtered[i];
                          final isSelected = _selectedIds.contains(c.id);

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(c.id!);
                              } else {
                                _openForm(c);
                              }
                            },
                            onLongPress: () {
                              _toggleSelection(c.id!);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.vendorColor.withValues(alpha: 0.12)
                                    : AppColors.cardSurface(context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.vendorColor
                                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_isSelectionMode)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12, top: 2),
                                      child: Checkbox(
                                        value: isSelected,
                                        onChanged: (_) => _toggleSelection(c.id!),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 44,
                                      height: 44,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.vendorColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.business_rounded,
                                        color: AppColors.vendorColor,
                                        size: 22,
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                c.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.vendorColor
                                                    .withValues(alpha: isDark ? 0.2 : 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                c.contactType,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.vendorColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (c.company.isNotEmpty || c.role.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            [c.company, c.role]
                                                .where((s) => s.isNotEmpty)
                                                .join(' • '),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: cs.onSurface.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                        if (c.slaTier.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'SLA: ${c.slaTier}',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (c.accountNumber.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'CID / Acc: ${c.accountNumber}',
                                            style: credentialFont(
                                              fontSize: 12,
                                              color: cs.onSurface.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            if (c.phoneNumber.isNotEmpty)
                                              FintechFilterPill(
                                                icon: Icons.phone_rounded,
                                                label: c.phoneNumber,
                                                color: AppColors.vendorColor,
                                                onTap: () => launchUrl(Uri(scheme: 'tel', path: c.phoneNumber)),
                                              ),
                                            if (c.email.isNotEmpty)
                                              FintechFilterPill(
                                                icon: Icons.email_rounded,
                                                label: c.email,
                                                color: AppColors.vendorColor,
                                                onTap: () => launchUrl(Uri(scheme: 'mailto', path: c.email)),
                                              ),
                                            if (c.portalUrl.isNotEmpty)
                                              FintechFilterPill(
                                                icon: Icons.open_in_new_rounded,
                                                label: 'Portal',
                                                color: AppColors.vendorColor,
                                                onTap: () => _launchUrlStr(c.portalUrl),
                                              ),
                                          ],
                                        ),
                                        if (c.notes.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            c.notes,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: cs.onSurface.withValues(alpha: 0.55),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
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
