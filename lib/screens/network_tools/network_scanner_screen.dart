// lib/screens/network_tools/network_scanner_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/network_scanner_service.dart';
import '../../database/database_helper.dart';
import '../../models/laptop.dart';
import '../../models/printer.dart';
import '../../models/access_point.dart';
import '../../models/network_device.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class NetworkScannerScreen extends StatefulWidget {
  const NetworkScannerScreen({super.key});

  @override
  State<NetworkScannerScreen> createState() => _NetworkScannerScreenState();
}

class _ScanProgress {
  final int scanned;
  final int total;
  final String phase;
  const _ScanProgress({this.scanned = 0, this.total = 254, this.phase = ''});
}

class _NetworkScannerScreenState extends State<NetworkScannerScreen> {
  final NetworkScannerService _scanner = NetworkScannerService();
  final TextEditingController _searchCtrl = TextEditingController();

  String? _wifiIp;
  String? _gatewayIp;
  String _targetRange = '192.168.1.0/24';
  bool _isLoadingInfo = true;
  bool _isScanning = false;
  final ValueNotifier<_ScanProgress> _progressNotifier = ValueNotifier(const _ScanProgress());
  final Map<String, DiscoveredHost> _pendingHosts = {};
  Timer? _hostFlushTimer;
  String _filterQuery = '';
  String _typeFilter = 'All';

  ScanOptions _options = const ScanOptions();
  final List<DiscoveredHost> _hosts = [];
  StreamSubscription<DiscoveredHost>? _scanSub;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _filterQuery = _searchCtrl.text.trim());
    });
    _initNetworkInfo();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scanSub?.cancel();
    _hostFlushTimer?.cancel();
    _progressNotifier.dispose();
    _scanner.stopScan();
    super.dispose();
  }

  Future<void> _initNetworkInfo() async {
    setState(() {
      _isLoadingInfo = true;
    });
    _wifiIp = await _scanner.getWifiIp();
    _gatewayIp = await _scanner.getGatewayIp();

    if (_wifiIp != null && _wifiIp!.contains('.')) {
      final parts = _wifiIp!.split('.');
      if (parts.length == 4) {
        _targetRange = '${parts[0]}.${parts[1]}.${parts[2]}.0/24';
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingInfo = false;
      });
    }
  }

  void _showScanOptionsSheet() {
    var tempOptions = _options;
    final rangeCtrl = TextEditingController(text: _targetRange);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          final cs = theme.colorScheme;

          final fallbackSubnet = _wifiIp != null && _wifiIp!.contains('.')
              ? _wifiIp!.substring(0, _wifiIp!.lastIndexOf('.'))
              : '192.168.1';

          return Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Scanner Configuration',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const Text(
                    'Target Subnet Scope:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: rangeCtrl,
                    decoration: InputDecoration(
                      labelText: 'IP Range / CIDR',
                      hintText: 'e.g. $fallbackSubnet.0/24 or $fallbackSubnet.1-50',
                      prefixIcon: const Icon(Icons.lan_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.tune_rounded, size: 14),
                        label: Text('$fallbackSubnet.0/24 (Full Subnet)'),
                        onPressed: () {
                          setSheetState(() {
                            rangeCtrl.text = '$fallbackSubnet.0/24';
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.router_rounded, size: 14),
                        label: Text('$fallbackSubnet.1-30 (Gateway & Infra)'),
                        onPressed: () {
                          setSheetState(() {
                            rangeCtrl.text = '$fallbackSubnet.1-30';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Engine Tuning & Performance:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Concurrency Threads: ${tempOptions.concurrency}'),
                      Text('${tempOptions.concurrency} workers', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: tempOptions.concurrency.toDouble(),
                    min: 8,
                    max: 64,
                    divisions: 7,
                    label: '${tempOptions.concurrency}',
                    onChanged: (v) {
                      setSheetState(() {
                        tempOptions = tempOptions.copyWith(concurrency: v.toInt());
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Socket Timeout: ${tempOptions.socketTimeoutMs} ms'),
                      Text('${tempOptions.socketTimeoutMs} ms', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: tempOptions.socketTimeoutMs.toDouble(),
                    min: 150,
                    max: 800,
                    divisions: 13,
                    label: '${tempOptions.socketTimeoutMs} ms',
                    onChanged: (v) {
                      setSheetState(() {
                        tempOptions = tempOptions.copyWith(socketTimeoutMs: v.toInt());
                      });
                    },
                  ),
                  const Divider(height: 20),
                  const Text(
                    'Discovery & Identity Protocols:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('NetBIOS NBSTAT (UDP 137)'),
                    subtitle: const Text('Windows PC name, Workgroup/Domain, and logged-in user'),
                    value: tempOptions.enableNetbios,
                    onChanged: (v) => setSheetState(() => tempOptions = tempOptions.copyWith(enableNetbios: v)),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Apple Bonjour / mDNS (UDP 5353)'),
                    subtitle: const Text('iPhone, Mac, Android, and Network Printer friendly names'),
                    value: tempOptions.enableMdns,
                    onChanged: (v) => setSheetState(() => tempOptions = tempOptions.copyWith(enableMdns: v)),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('SSDP / UPnP (UDP 1900)'),
                    subtitle: const Text('Smart TVs, Routers, and XML device descriptors'),
                    value: tempOptions.enableSsdp,
                    onChanged: (v) => setSheetState(() => tempOptions = tempOptions.copyWith(enableSsdp: v)),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('ICMP Ping Echo Sweep'),
                    subtitle: const Text('Awakens dormant hosts and populates OS ARP cache'),
                    value: tempOptions.enableIcmpPing,
                    onChanged: (v) => setSheetState(() => tempOptions = tempOptions.copyWith(enableIcmpPing: v)),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('HTTP Web <title> Grabbing'),
                    subtitle: const Text('Extracts web GUI title and server banners on ports 80/443/8080'),
                    value: tempOptions.enableHttpTitle,
                    onChanged: (v) => setSheetState(() => tempOptions = tempOptions.copyWith(enableHttpTitle: v)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        setState(() {
                          _targetRange = rangeCtrl.text.trim().isNotEmpty ? rangeCtrl.text.trim() : _targetRange;
                          _options = tempOptions;
                        });
                        Navigator.pop(ctx);
                        _startScan();
                      },
                      child: const Text('Save & Start Scan'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _startScan() {
    if (_isScanning) {
      _scanSub?.cancel();
      _hostFlushTimer?.cancel();
      _scanner.stopScan();
      _flushPendingHosts();
      _progressNotifier.value = const _ScanProgress(phase: 'Scan Aborted');
      setState(() {
        _isScanning = false;
      });
      return;
    }

    final fallbackSubnet = _wifiIp != null && _wifiIp!.contains('.')
        ? _wifiIp!.substring(0, _wifiIp!.lastIndexOf('.'))
        : '192.168.1';

    final targetList = NetworkScannerService.parseTargetIps(_targetRange, fallbackSubnet: fallbackSubnet);

    _pendingHosts.clear();
    _hostFlushTimer?.cancel();
    _progressNotifier.value = _ScanProgress(scanned: 0, total: targetList.length, phase: 'Initializing discovery pipeline…');

    setState(() {
      _hosts.clear();
      _isScanning = true;
    });

    _scanSub = _scanner
        .sweepTargets(
      targetIps: targetList,
      localIp: _wifiIp,
      gatewayIp: _gatewayIp,
      options: _options,
      onProgress: (scanned, total, phase) {
        _progressNotifier.value = _ScanProgress(scanned: scanned, total: total, phase: phase);
      },
    )
        .listen(
      (host) {
        if (mounted) {
          _onHostDiscovered(host);
        }
      },
      onDone: () {
        if (mounted) {
          _flushPendingHosts();
          _hostFlushTimer?.cancel();
          _progressNotifier.value = _ScanProgress(
            scanned: _progressNotifier.value.total,
            total: _progressNotifier.value.total,
            phase: 'Scan Complete',
          );
          setState(() {
            _isScanning = false;
          });
        }
      },
    );
  }

  void _onHostDiscovered(DiscoveredHost host) {
    _pendingHosts[host.ip] = host;
    if (_hostFlushTimer == null || !_hostFlushTimer!.isActive) {
      _hostFlushTimer = Timer(const Duration(milliseconds: 140), _flushPendingHosts);
    }
  }

  void _flushPendingHosts() {
    if (!mounted || _pendingHosts.isEmpty) return;
    setState(() {
      for (final host in _pendingHosts.values) {
        final idx = _hosts.indexWhere((h) => h.ip == host.ip);
        if (idx >= 0) {
          _hosts[idx] = host;
        } else {
          _hosts.add(host);
        }
      }
      _pendingHosts.clear();
      _sortHosts();
    });
  }

  void _sortHosts() {
    _hosts.sort((a, b) {
      final aParts = a.ip.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final bParts = b.ip.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      for (int i = 0; i < 4; i++) {
        final aP = i < aParts.length ? aParts[i] : 0;
        final bP = i < bParts.length ? bParts[i] : 0;
        if (aP != bP) {
          return aP.compareTo(bP);
        }
      }
      return 0;
    });
  }

  List<DiscoveredHost> get _filteredHosts {
    return _hosts.where((h) {
      // Type filter
      if (_typeFilter != 'All') {
        switch (_typeFilter) {
          case 'Workstations':
            if (h.typeGuess != DeviceTypeGuess.workstation) return false;
            break;
          case 'Routers':
            if (h.typeGuess != DeviceTypeGuess.router) return false;
            break;
          case 'Printers':
            if (h.typeGuess != DeviceTypeGuess.printer) return false;
            break;
          case 'Mobiles':
            if (h.typeGuess != DeviceTypeGuess.mobile) return false;
            break;
          case 'Servers':
            if (h.typeGuess != DeviceTypeGuess.server) return false;
            break;
          case 'IoT':
            if (h.typeGuess != DeviceTypeGuess.iot && h.typeGuess != DeviceTypeGuess.smartTv) return false;
            break;
        }
      }

      // Search text filter
      if (_filterQuery.isEmpty) return true;
      final q = _filterQuery.toLowerCase();
      return h.ip.contains(q) ||
          h.displayName.toLowerCase().contains(q) ||
          (h.macAddress ?? '').toLowerCase().contains(q) ||
          (h.vendor ?? '').toLowerCase().contains(q) ||
          (h.netbiosGroup ?? '').toLowerCase().contains(q) ||
          (h.webTitle ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _exportResultsCsv() async {
    if (_hosts.isEmpty) {
      showSnack(context, 'No discovered hosts to export', error: true);
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln(
        'IP Address,Hostname / Device Name,MAC Address,Manufacturer,OS / Type Guess,Response Time (ms),Open Ports,Web Title,Workgroup,User,Discovery Protocol');
    for (final h in _hosts) {
      buffer.writeln(
        '"${h.ip}",'
        '"${h.displayName.replaceAll('"', '""')}",'
        '"${h.macAddress ?? ''}",'
        '"${h.vendor ?? ''}",'
        '"${h.osGuess}",'
        '${h.responseTimeMs},'
        '"${h.openPorts.join(', ')}",'
        '"${(h.webTitle ?? '').replaceAll('"', '""')}",'
        '"${h.netbiosGroup ?? ''}",'
        '"${h.netbiosUser ?? ''}",'
        '"${h.discoveryMethod}"',
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Network_Scan_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Network Scan Results (${_hosts.length} Hosts)',
      ),
    );
  }

  void _showHostDetailSheet(DiscoveredHost host) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HostDetailSheet(host: host),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayList = _filteredHosts;

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Network Scanner',
        subtitle: '$_targetRange • Precise multi-tier sweep',
      ),
      body: _isLoadingInfo
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Scope Summary Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: FintechHeroCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Scope: $_targetRange',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _isScanning ? Colors.amber.withValues(alpha: 0.25) : Colors.green.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _isScanning ? 'SCANNING' : 'IDLE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _isScanning ? Colors.amberAccent : Colors.lightGreenAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_hosts.length} Active Devices Discovered',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Local IP: ${_wifiIp ?? "Not detected"} • Gateway: ${_gatewayIp ?? "Unknown"}',
                          style: const TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ),

                // Live Progress Indicator
                if (_isScanning)
                  ValueListenableBuilder<_ScanProgress>(
                    valueListenable: _progressNotifier,
                    builder: (ctx, prog, _) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: prog.total > 0 ? prog.scanned / prog.total : 0.0,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    prog.phase.isNotEmpty ? prog.phase : 'Sweeping targets…',
                                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.65)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${prog.scanned} / ${prog.total}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                // Search & Action Toolbar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: SearchBar2(
                          controller: _searchCtrl,
                          hint: 'Search IP, MAC, hostname...',
                          noPadding: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FintechActionButton(
                        icon: Icons.tune_rounded,
                        tooltip: 'Configure Scanner',
                        onTap: _showScanOptionsSheet,
                      ),
                      if (_hosts.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        FintechActionButton(
                          icon: Icons.download_rounded,
                          tooltip: 'Export CSV',
                          onTap: _exportResultsCsv,
                        ),
                      ],
                      const SizedBox(width: 8),
                      FintechActionButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh Network Info',
                        onTap: _initNetworkInfo,
                      ),
                    ],
                  ),
                ),
                if (_hosts.isNotEmpty) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        _buildFilterChip('All', _hosts.length),
                        _buildFilterChip('Workstations', _hosts.where((h) => h.typeGuess == DeviceTypeGuess.workstation).length),
                        _buildFilterChip('Routers', _hosts.where((h) => h.typeGuess == DeviceTypeGuess.router).length),
                        _buildFilterChip('Printers', _hosts.where((h) => h.typeGuess == DeviceTypeGuess.printer).length),
                        _buildFilterChip('Mobiles', _hosts.where((h) => h.typeGuess == DeviceTypeGuess.mobile).length),
                        _buildFilterChip('Servers', _hosts.where((h) => h.typeGuess == DeviceTypeGuess.server).length),
                        _buildFilterChip('IoT', _hosts.where((h) => h.typeGuess == DeviceTypeGuess.iot || h.typeGuess == DeviceTypeGuess.smartTv).length),
                      ],
                    ),
                  ),
                ],

                // Device Cards List
                Expanded(
                  child: displayList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.radar_rounded, size: 64, color: cs.primary.withValues(alpha: 0.35)),
                              const SizedBox(height: 12),
                              Text(
                                _isScanning
                                    ? 'Scanning network scope for active hosts…'
                                    : (_hosts.isEmpty
                                        ? 'Tap "Scan Network" to sweep scope'
                                        : 'No devices match your filter criteria'),
                                style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: displayList.length,
                          itemBuilder: (context, i) {
                            final h = displayList[i];
                            return Card(
                              key: ValueKey(h.ip),
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: cs.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showHostDetailSheet(h),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Device Icon
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: cs.primaryContainer.withValues(alpha: 0.45),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(_getIconForHost(h), color: cs.primary, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    h.displayName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${h.responseTimeMs} ms',
                                                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.7)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  'IP: ',
                                                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
                                                ),
                                                Text(
                                                  h.ip,
                                                  style: credentialFont(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: cs.onSurface,
                                                  ),
                                                ),
                                                if (h.macAddress != null) ...[
                                                  Text(' • ', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4))),
                                                  Expanded(
                                                    child: Text(
                                                      h.macAddress!,
                                                      style: credentialFont(
                                                        fontSize: 11,
                                                        color: cs.onSurface.withValues(alpha: 0.8),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${h.osGuess}${h.vendor != null ? " • ${h.vendor}" : ""}',
                                              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55)),
                                            ),
                                            if (h.webTitle != null && h.webTitle!.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Title: "${h.webTitle}"',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: cs.primary),
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: cs.primary.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    h.discoveryMethod,
                                                    style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                if (h.netbiosGroup != null && h.netbiosGroup!.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.indigo.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'Group: ${h.netbiosGroup}',
                                                      style: const TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ...h.openPorts.map(
                                                  (p) => Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'Port $p',
                                                      style: const TextStyle(fontSize: 10),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Scan Action Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isScanning ? Colors.redAccent : cs.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _startScan,
                        icon: Icon(_isScanning ? Icons.stop_rounded : Icons.radar_rounded),
                        label: Text(
                          _isScanning ? 'Stop Scan' : 'Scan Network Scope',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _typeFilter == label;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text('$label ($count)'),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? cs.onPrimary : cs.onSurface,
        ),
        selectedColor: cs.primary,
        onSelected: (val) {
          setState(() {
            _typeFilter = label;
          });
        },
      ),
    );
  }

  IconData _getIconForHost(DiscoveredHost h) {
    switch (h.typeGuess) {
      case DeviceTypeGuess.printer:
        return Icons.print_rounded;
      case DeviceTypeGuess.workstation:
        return Icons.computer_rounded;
      case DeviceTypeGuess.server:
        return Icons.dns_rounded;
      case DeviceTypeGuess.router:
        return Icons.router_rounded;
      case DeviceTypeGuess.mobile:
        return Icons.smartphone_rounded;
      case DeviceTypeGuess.smartTv:
        return Icons.tv_rounded;
      case DeviceTypeGuess.iot:
        return Icons.memory_rounded;
      case DeviceTypeGuess.other:
        return Icons.devices_other_rounded;
    }
  }
}

// ── Host Detail Sheet ────────────────────────────────────────────────────────
class _HostDetailSheet extends StatefulWidget {
  final DiscoveredHost host;
  const _HostDetailSheet({required this.host});

  @override
  State<_HostDetailSheet> createState() => _HostDetailSheetState();
}

class _HostDetailSheetState extends State<_HostDetailSheet> {
  final NetworkScannerService _service = NetworkScannerService();
  bool _isPortScanning = false;
  List<int> _ports = [];
  int _scannedPorts = 0;

  @override
  void initState() {
    super.initState();
    _ports = List.from(widget.host.openPorts);
  }

  Future<void> _deepScanPorts() async {
    setState(() {
      _isPortScanning = true;
      _scannedPorts = 0;
    });

    final found = await _service.scanHostPorts(
      widget.host.ip,
      onProgress: (cur, tot) {
        if (mounted) {
          setState(() => _scannedPorts = cur);
        }
      },
    );

    if (mounted) {
      setState(() {
        _ports = found;
        _isPortScanning = false;
      });
    }
  }

  Future<void> _triggerWakeOnLan() async {
    if (widget.host.macAddress == null || widget.host.macAddress!.isEmpty) {
      showSnack(context, 'MAC address not available for Wake-on-LAN', error: true);
      return;
    }
    final ok = await NetworkScannerService.sendWakeOnLan(widget.host.macAddress!);
    if (!mounted) return;
    if (ok) {
      showSnack(context, 'Wake-on-LAN magic packet sent to ${widget.host.macAddress}');
    } else {
      showSnack(context, 'Failed to send Wake-on-LAN packet', error: true);
    }
  }

  Future<void> _openWebAdmin() async {
    final port = _ports.contains(443) ? 443 : (_ports.contains(8443) ? 8443 : (_ports.contains(8080) ? 8080 : 80));
    final scheme = (port == 443 || port == 8443) ? 'https' : 'http';
    final urlStr = (port == 80 || port == 443) ? '$scheme://${widget.host.ip}/' : '$scheme://${widget.host.ip}:$port/';
    final uri = Uri.parse(urlStr);
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        launched = false;
      }
    }
    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: urlStr));
      if (mounted) {
        showSnack(context, 'Could not launch browser directly. URL copied to clipboard: $urlStr');
      }
    }
  }

  void _showAddToInventoryDialog() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final h = widget.host;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add to itBox Inventory'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select target inventory category for ${h.displayName} (${h.ip}):'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.laptop_rounded),
              title: const Text('Laptop / PC'),
              subtitle: Text(h.vendor ?? 'Workstation'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              onTap: () async {
                Navigator.pop(dialogCtx);
                final db = DatabaseHelper();
                await db.insertLaptop(Laptop(
                  laptopNumber: 'PC-${h.ip.split('.').last}',
                  model: h.hostname.isNotEmpty ? '${h.vendor ?? "PC"} ${h.hostname}' : (h.vendor ?? 'Workstation'),
                  condition: 'Good',
                  user: h.netbiosUser ?? '',
                ));
                if (mounted) {
                  showSnack(context, 'Added ${h.displayName} to Laptops Inventory');
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.print_rounded),
              title: const Text('Network Printer'),
              subtitle: Text(h.vendor ?? 'Printer'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              onTap: () async {
                Navigator.pop(dialogCtx);
                final db = DatabaseHelper();
                await db.insertPrinter(Printer(
                  printerNumber: 'PRN-${h.ip.split('.').last}',
                  model: h.displayName,
                  condition: 'Good',
                  location: 'IP: ${h.ip}',
                ));
                if (mounted) {
                  showSnack(context, 'Added ${h.displayName} to Printers Inventory');
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.wifi_tethering_rounded),
              title: const Text('Access Point'),
              subtitle: Text(h.vendor ?? 'AP'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              onTap: () async {
                Navigator.pop(dialogCtx);
                final db = DatabaseHelper();
                await db.insertAccessPoint(AccessPoint(
                  deviceNumber: 'AP-${h.ip.split('.').last}',
                  model: h.displayName,
                  location: 'IP: ${h.ip}',
                ));
                if (mounted) {
                  showSnack(context, 'Added ${h.displayName} to Access Points');
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.router_rounded),
              title: const Text('Network Device / Router'),
              subtitle: Text(h.vendor ?? 'Network Device'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              onTap: () async {
                Navigator.pop(dialogCtx);
                final db = DatabaseHelper();
                await db.insertNetworkDevice(NetworkDevice(
                  deviceNumber: 'NET-${h.ip.split('.').last}',
                  model: h.displayName,
                  gateway: h.ip,
                  deviceLocation: 'MAC: ${h.macAddress ?? "N/A"}',
                ));
                if (mounted) {
                  showSnack(context, 'Added ${h.displayName} to Network Devices');
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final h = widget.host;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.displayName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Role / OS: ${h.osGuess}',
                        style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20),

            // Network Credentials Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  _buildDetailRow('IP Address', h.ip, canCopy: true),
                  if (h.macAddress != null) ...[
                    const Divider(height: 14),
                    _buildDetailRow('MAC Address', h.macAddress!, canCopy: true),
                  ],
                  if (h.vendor != null) ...[
                    const Divider(height: 14),
                    _buildDetailRow('Manufacturer', h.vendor!),
                  ],
                  if (h.netbiosGroup != null && h.netbiosGroup!.isNotEmpty) ...[
                    const Divider(height: 14),
                    _buildDetailRow('Workgroup / Domain', h.netbiosGroup!),
                  ],
                  if (h.netbiosUser != null && h.netbiosUser!.isNotEmpty) ...[
                    const Divider(height: 14),
                    _buildDetailRow('Logged-in User', h.netbiosUser!),
                  ],
                  if (h.webTitle != null && h.webTitle!.isNotEmpty) ...[
                    const Divider(height: 14),
                    _buildDetailRow('Web Title', h.webTitle!),
                  ],
                  const Divider(height: 14),
                  _buildDetailRow('Discovery Method', h.discoveryMethod),
                  const Divider(height: 14),
                  _buildDetailRow('Latency / Ping', '${h.responseTimeMs} ms'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Open Ports Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Open Services & Ports (${_ports.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (!_isPortScanning)
                  TextButton.icon(
                    onPressed: _deepScanPorts,
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: const Text('Deep Port Scan'),
                  ),
              ],
            ),
            if (_isPortScanning) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: _scannedPorts / NetworkScannerService.fullPortList.length),
              const SizedBox(height: 4),
              Text(
                'Scanning standard IT service ports… $_scannedPorts / ${NetworkScannerService.fullPortList.length}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
            const SizedBox(height: 8),
            if (_ports.isEmpty)
              Text('No standard TCP ports open.', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _ports.map((p) {
                  return Chip(
                    avatar: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                    label: Text('$p: ${_getPortName(p)}'),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),

            // Actions: Web Admin, Wake-on-LAN, Add to Static IP, Add to Inventory
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: const Text('Web Admin'),
                    onPressed: _openWebAdmin,
                  ),
                ),
                if (h.macAddress != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                      label: const Text('Wake-on-LAN'),
                      onPressed: _triggerWakeOnLan,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_link_rounded, size: 18),
                    label: const Text('Add to Static IP'),
                    onPressed: () async {
                      await DatabaseHelper().insertStaticIp({
                        'ip_address': h.ip,
                        'subnet_mask': '255.255.255.0',
                        'assigned_device': h.displayName,
                        'device_type': h.typeGuess.name.toUpperCase(),
                        'mac_address': h.macAddress ?? '',
                        'notes': 'Discovered via ${h.discoveryMethod}. OS: ${h.osGuess}',
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        showSnack(context, 'Added ${h.ip} to Static IPs');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.secondary,
                      foregroundColor: cs.onSecondary,
                    ),
                    icon: const Icon(Icons.inventory_2_rounded, size: 18),
                    label: const Text('Add to Inventory'),
                    onPressed: _showAddToInventoryDialog,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool canCopy = false}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: canCopy
                ? credentialFont(fontSize: 12, fontWeight: FontWeight.bold)
                : const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (canCopy)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Copy $label',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              showSnack(context, '$label copied to clipboard');
            },
          ),
      ],
    );
  }

  String _getPortName(int port) {
    switch (port) {
      case 21:
        return 'FTP';
      case 22:
        return 'SSH';
      case 23:
        return 'Telnet';
      case 25:
        return 'SMTP';
      case 53:
        return 'DNS';
      case 80:
        return 'HTTP';
      case 110:
        return 'POP3';
      case 135:
        return 'MS RPC';
      case 139:
        return 'NetBIOS';
      case 143:
        return 'IMAP';
      case 443:
        return 'HTTPS';
      case 445:
        return 'SMB';
      case 554:
        return 'RTSP';
      case 1433:
        return 'MSSQL';
      case 1900:
        return 'SSDP';
      case 3306:
        return 'MySQL';
      case 3389:
        return 'RDP';
      case 5000:
        return 'UPnP / Synology';
      case 5353:
        return 'mDNS';
      case 5355:
        return 'LLMNR';
      case 5432:
        return 'PostgreSQL';
      case 5900:
        return 'VNC';
      case 8000:
        return 'HTTP-Dev';
      case 8080:
        return 'HTTP-Alt';
      case 8443:
        return 'HTTPS-Alt';
      case 9100:
        return 'JetDirect (Printer)';
      default:
        return 'Custom';
    }
  }
}
