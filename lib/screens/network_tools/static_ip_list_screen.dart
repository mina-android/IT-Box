// lib/screens/network_tools/static_ip_list_screen.dart
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'static_ip_form_screen.dart';

class StaticIpListScreen extends StatefulWidget {
  final int? initialItemId;
  const StaticIpListScreen({super.key, this.initialItemId});

  @override
  State<StaticIpListScreen> createState() => _StaticIpListScreenState();
}

class _StaticIpListScreenState extends State<StaticIpListScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _showSearch = false;
  bool _handledInitial = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _db.getStaticIps();
    if (mounted) {
      setState(() {
        _items = data;
        _loading = false;
      });
      if (!_handledInitial && widget.initialItemId != null) {
        final match = data.where((it) => it['id'] == widget.initialItemId).firstOrNull;
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

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => StaticIpFormScreen(item: item)),
    );
    if (res == true && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final q = _searchCtrl.text.toLowerCase().trim();

    final filtered = _items.where((i) {
      if (q.isEmpty) return true;
      final ip = (i['ip_address'] ?? '').toString().toLowerCase();
      final dev = (i['assigned_device'] ?? '').toString().toLowerCase();
      return ip.contains(q) || dev.contains(q);
    }).toList();

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Static IP Registry',
        subtitle: '${_items.length} registered IP assignments',
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
          color: Theme.of(context).colorScheme.primary,
          tooltip: 'Add Static IP',
        ),
      ),
      body: Column(
        children: [
          if (_showSearch)
            SearchBar2(
              controller: _searchCtrl,
              hint: 'Search IP or device...',
            ),
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.lan_outlined,
                        title: _items.isEmpty ? 'No Static IPs Logged' : 'No Matching Static IPs',
                        subtitle: _items.isEmpty
                            ? 'Tap + to register a static IP assignment.'
                            : 'Try searching for a different IP or device.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final item = filtered[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.lan_outlined, color: cs.primary),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    item['ip_address'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item['device_type'] ?? 'Device',
                                      style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.8)),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${item['assigned_device'] ?? ''}${item['notes'] != null && item['notes'].isNotEmpty ? ' • ${item['notes']}' : ''}',
                                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: () async {
                                  final ok = await showConfirmDialog(
                                    context,
                                    title: 'Delete Static IP',
                                    message: 'Remove ${item['ip_address']} from IPAM registry?',
                                    confirmText: 'Delete',
                                    confirmColor: Colors.red,
                                  );
                                  if (!ok || !mounted) {
                                    return;
                                  }
                                  await _db.deleteStaticIp(item['id'] as int);
                                  if (mounted) {
                                    _load();
                                  }
                                },
                              ),
                              onTap: () => _openForm(item),
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
