// lib/screens/wifi_networks/wifi_networks_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/database_helper.dart';
import '../../models/wifi_network.dart';
import '../../utils/haptics.dart';
import '../../widgets/common_widgets.dart';
import 'wifi_network_form_screen.dart';

class WifiNetworksScreen extends StatefulWidget {
  const WifiNetworksScreen({super.key});

  @override
  State<WifiNetworksScreen> createState() => _WifiNetworksScreenState();
}

class _WifiNetworksScreenState extends State<WifiNetworksScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  List<WifiNetwork> _allNetworks = [];
  final Set<String> _revealedPasswords = {};
  final Set<String> _revealedAdminPasswords = {};
  int _routerCount = 0;
  int _mifiCount = 0;
  int _standaloneCount = 0;

  String _netKey(WifiNetwork n) => '${n.originType}_${n.id}_${n.networkName}';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadNetworks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _loadNetworks() async {
    setState(() => _loading = true);
    final routers = await _db.getNetworkDevices();
    final mifis = await _db.getMiFis();
    final standalones = await _db.getWifiNetworks();

    final List<WifiNetwork> combined = [];

    // 1. Add router networks
    for (final r in routers) {
      if (r.wifiName.isNotEmpty) {
        combined.add(WifiNetwork(
          id: r.id,
          networkName: r.wifiName,
          password: r.wifiPassword,
          phoneNumber: r.phoneNumber,
          locationDevice: r.deviceLocation.isNotEmpty ? r.deviceLocation : 'Router #${r.deviceNumber} (${r.model})',
          adminUsername: 'admin',
          adminPassword: r.adminPassword,
          notes: 'Router Hardware (IP: ${r.gateway.isNotEmpty ? r.gateway : '192.168.1.1'})',
          isLinkedDevice: true,
          originType: 'Router',
        ));
      }
    }

    // 2. Add MiFi networks
    for (final m in mifis) {
      if (m.wifiName.isNotEmpty) {
        combined.add(WifiNetwork(
          id: m.id,
          networkName: m.wifiName,
          password: m.wifiPassword,
          phoneNumber: m.phoneNumber,
          locationDevice: 'MiFi #${m.deviceNumber} (${m.model})',
          adminUsername: 'admin',
          adminPassword: m.adminPassword,
          notes: 'Provider: ${m.serviceProvider.isNotEmpty ? m.serviceProvider : 'Cellular'} • Quota: ${m.quota.isNotEmpty ? m.quota : 'Unlimited'}',
          isLinkedDevice: true,
          originType: 'MiFi',
        ));
      }
    }

    // 3. Add standalone networks
    for (final s in standalones) {
      combined.add(s.copyWith(
        isLinkedDevice: false,
        originType: 'Standalone',
      ));
    }

    combined.sort((a, b) => a.networkName.toLowerCase().compareTo(b.networkName.toLowerCase()));

    if (mounted) {
      setState(() {
        _allNetworks = combined;
        _standaloneCount = combined.where((n) => !n.isLinkedDevice).length;
        _routerCount = combined.where((n) => n.originType == 'Router').length;
        _mifiCount = combined.where((n) => n.originType == 'MiFi').length;
        _loading = false;
      });
    }
  }

  List<WifiNetwork> get _filtered {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) return _allNetworks;
    return _allNetworks.where((n) {
      return n.networkName.toLowerCase().contains(q) ||
          n.locationDevice.toLowerCase().contains(q) ||
          n.phoneNumber.toLowerCase().contains(q) ||
          n.notes.toLowerCase().contains(q);
    }).toList();
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    AppHaptics.tap(context, HapticStrength.light);
    showSnack(context, '$label copied to clipboard');
  }

  Future<void> _openForm([WifiNetwork? existing]) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WifiNetworkFormScreen(network: existing),
      ),
    );
    if (res == true && mounted) {
      _loadNetworks();
    }
  }

  Future<void> _deleteStandaloneNetwork(WifiNetwork net) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Wi-Fi Network',
      message: 'Are you sure you want to delete "${net.networkName}"? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );
    if (ok && net.id != null) {
      await _db.deleteWifiNetwork(net.id!);
      if (mounted) {
        _loadNetworks();
        showSnack(context, 'Wi-Fi network removed');
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
        title: 'Wi-Fi Networks Registry',
        subtitle: '${_allNetworks.length} total networks across infrastructure',
      ),
      floatingActionButton: FintechFab(
        onPressed: () => _openForm(),
        tooltip: 'Add Network',
        icon: Icons.add_rounded,
      ),
      body: Column(
        children: [
          // Search & Filter Header
          SearchBar2(
            controller: _searchCtrl,
            hint: 'Search SSID, device, location or notes...',
          ),

          // Overview Telemetry Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _badge('Total: ${_allNetworks.length}', cs.primaryContainer, cs.onPrimaryContainer),
                const SizedBox(width: 6),
                _badge('Routers: $_routerCount', Colors.blue.withValues(alpha: 0.15), Colors.blue),
                const SizedBox(width: 6),
                _badge('MiFis: $_mifiCount', Colors.purple.withValues(alpha: 0.15), Colors.purple),
                const SizedBox(width: 6),
                _badge('Custom: $_standaloneCount', Colors.teal.withValues(alpha: 0.15), Colors.teal),
              ],
            ),
          ),

          // Network List
          Expanded(
            child: _loading
                ? const ShimmerListLoader()
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off_rounded, size: 64, color: cs.outlineVariant),
                            const SizedBox(height: 12),
                            Text(
                              _searchCtrl.text.isEmpty ? 'No Wi-Fi networks found' : 'No networks match "${_searchCtrl.text}"',
                              style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap "+ Add Network" to register standalone Wi-Fi credentials',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final net = filtered[i];
                          final key = _netKey(net);
                          final isRevealed = _revealedPasswords.contains(key);
                          final isAdminRevealed = _revealedAdminPasswords.contains(key);

                          return SlideInAndFade(
                            key: ValueKey(key),
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
                                  // Top row: SSID + Origin tag + Actions
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: _originColor(net.originType).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          _originIcon(net.originType),
                                          color: _originColor(net.originType),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              net.networkName,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                            ),
                                            if (net.locationDevice.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                net.locationDevice,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: cs.onSurface.withValues(alpha: 0.65),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _originColor(net.originType).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _originColor(net.originType).withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Text(
                                          net.originType.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: _originColor(net.originType),
                                          ),
                                        ),
                                      ),
                                      if (!net.isLinkedDevice) ...[
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert_rounded, size: 20),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          onSelected: (val) {
                                            if (val == 'edit') {
                                              _openForm(net);
                                            } else if (val == 'delete') {
                                              _deleteStandaloneNetwork(net);
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
                                    ],
                                  ),
                                  const Divider(height: 20),

                                  // Credentials Row
                                  if (net.password.isNotEmpty) ...[
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
                                              isRevealed ? net.password : '••••••••••••',
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
                                                  _revealedPasswords.remove(key);
                                                } else {
                                                  _revealedPasswords.add(key);
                                                }
                                              });
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 18),
                                            tooltip: 'Copy Password',
                                            onPressed: () => _copyToClipboard(net.password, 'Wi-Fi Password'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],

                                  // Phone Number Row (if present)
                                  if (net.phoneNumber.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.sim_card_outlined, size: 15, color: Colors.blueGrey),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Line / SIM: ${net.phoneNumber}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                          const Spacer(),
                                          InkWell(
                                            onTap: () => _copyToClipboard(net.phoneNumber, 'Phone Number'),
                                            borderRadius: BorderRadius.circular(6),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              child: Text(
                                                'Copy',
                                                style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Admin Gateway Credentials (if present)
                                  if (net.adminPassword.isNotEmpty || net.adminUsername.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.admin_panel_settings_outlined, size: 15, color: Colors.amber),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Admin: ${net.adminUsername.isNotEmpty ? net.adminUsername : "admin"} / ${isAdminRevealed ? net.adminPassword : "••••"}',
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                          ),
                                          const Spacer(),
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                if (isAdminRevealed) {
                                                  _revealedAdminPasswords.remove(key);
                                                } else {
                                                  _revealedAdminPasswords.add(key);
                                                }
                                              });
                                            },
                                            child: Icon(
                                              isAdminRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                              size: 15,
                                              color: Colors.amber,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () => _copyToClipboard(net.adminPassword, 'Admin Password'),
                                            child: const Icon(Icons.copy_rounded, size: 15, color: Colors.amber),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Notes
                                  if (net.notes.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        net.notes,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: cs.onSurface.withValues(alpha: 0.55),
                                        ),
                                      ),
                                    ),
                                  ],
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

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Color _originColor(String type) {
    switch (type) {
      case 'Router':
        return Colors.blue;
      case 'MiFi':
        return Colors.purple;
      default:
        return const Color(0xFF00897B);
    }
  }

  IconData _originIcon(String type) {
    switch (type) {
      case 'Router':
        return Icons.router_outlined;
      case 'MiFi':
        return Icons.wifi_tethering_outlined;
      default:
        return Icons.wifi_rounded;
    }
  }
}
