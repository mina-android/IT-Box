// lib/screens/network_tools/diagnostics/network_diagnostics_screen.dart
import 'package:flutter/material.dart';
import '../../../services/network_diagnostics_service.dart';
import '../../../services/topology_pdf_service.dart';
import '../../../widgets/common_widgets.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/haptics.dart';

enum DiagnosticTab {
  dns,
  portCheck,
  speed,
}

class NetworkDiagnosticsScreen extends StatefulWidget {
  const NetworkDiagnosticsScreen({super.key});

  @override
  State<NetworkDiagnosticsScreen> createState() => _NetworkDiagnosticsScreenState();
}

class _NetworkDiagnosticsScreenState extends State<NetworkDiagnosticsScreen> {
  final _service = NetworkDiagnosticsService();
  final _topologyService = TopologyPdfService();

  DiagnosticTab _activeTab = DiagnosticTab.dns;

  // DNS inputs & state
  final _dnsHostCtrl = TextEditingController(text: 'google.com');
  DnsLookupResult? _dnsResult;
  bool _dnsLoading = false;

  // Port Check inputs & state
  final _portHostCtrl = TextEditingController(text: '192.168.1.1');
  final _portCtrl = TextEditingController(text: '80');
  PortCheckResult? _portResult;
  bool _portLoading = false;

  // Speed Estimate inputs & state
  final _speedUrlCtrl = TextEditingController(text: 'http://192.168.1.1/');
  SpeedEstimateResult? _speedResult;
  bool _speedLoading = false;

  @override
  void dispose() {
    _dnsHostCtrl.dispose();
    _portHostCtrl.dispose();
    _portCtrl.dispose();
    _speedUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _runDns() async {
    final host = _dnsHostCtrl.text.trim();
    if (host.isEmpty) return;
    setState(() => _dnsLoading = true);
    AppHaptics.tap(context, HapticStrength.light);

    final res = await _service.resolveDns(host);
    if (!mounted) return;
    setState(() {
      _dnsResult = res;
      _dnsLoading = false;
    });
  }

  Future<void> _runPortCheck() async {
    final host = _portHostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 80;
    if (host.isEmpty) return;
    setState(() => _portLoading = true);
    AppHaptics.tap(context, HapticStrength.light);

    final res = await _service.checkPort(host, port);
    if (!mounted) return;
    setState(() {
      _portResult = res;
      _portLoading = false;
    });
  }

  Future<void> _runSpeed() async {
    final url = _speedUrlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _speedLoading = true);
    AppHaptics.tap(context, HapticStrength.light);

    final res = await _service.estimateSpeed(url);
    if (!mounted) return;
    setState(() {
      _speedResult = res;
      _speedLoading = false;
    });
  }

  Future<void> _exportTopology() async {
    try {
      final file = await _topologyService.exportTopologyPdf();
      if (!mounted) return;
      showSnack(context, 'Topology PDF map saved: ${file.path}');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Failed to generate topology PDF: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Network Diagnostics Suite',
        actions: [
          FintechCircleButton(
            icon: Icons.alt_route_rounded,
            tooltip: 'Export Topology PDF Map',
            onPressed: _exportTopology,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<DiagnosticTab>(
            segments: const [
              ButtonSegment(
                value: DiagnosticTab.dns,
                label: Text('DNS Lookup'),
                icon: Icon(Icons.dns_rounded),
              ),
              ButtonSegment(
                value: DiagnosticTab.portCheck,
                label: Text('Port Probe'),
                icon: Icon(Icons.lan_rounded),
              ),
              ButtonSegment(
                value: DiagnosticTab.speed,
                label: Text('Throughput'),
                icon: Icon(Icons.speed_rounded),
              ),
            ],
            selected: {_activeTab},
            onSelectionChanged: (val) {
              AppHaptics.tap(context, HapticStrength.selection);
              setState(() => _activeTab = val.first);
            },
          ),
          const SizedBox(height: 20),
          if (_activeTab == DiagnosticTab.dns) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HOSTNAME / FQDN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dnsHostCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. gateway.local, google.com',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _dnsLoading ? null : _runDns,
                        icon: _dnsLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search_rounded),
                        label: const Text('Resolve'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_dnsResult != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Query Results for "${_dnsResult!.hostname}"', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_dnsResult!.elapsedMs} ms', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Divider(height: 24),
                    if (_dnsResult!.error != null)
                      Text('Error: ${_dnsResult!.error}', style: TextStyle(color: cs.error))
                    else if (_dnsResult!.addresses.isEmpty)
                      const Text('No DNS records returned.')
                    else
                      ..._dnsResult!.addresses.map((a) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.green),
                                const SizedBox(width: 8),
                                Text(a, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ],
          ] else if (_activeTab == DiagnosticTab.portCheck) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TARGET HOST & PORT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _portHostCtrl,
                          decoration: InputDecoration(
                            labelText: 'Host / IP',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _portCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Port',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _portLoading ? null : _runPortCheck,
                      icon: _portLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.bolt_rounded),
                      label: const Text('Probe Port'),
                    ),
                  ),
                ],
              ),
            ),
            if (_portResult != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_portResult!.host}:${_portResult!.port}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_portResult!.isOpen ? Colors.green : Colors.red).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _portResult!.isOpen ? 'OPEN' : 'CLOSED / FILTERED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _portResult!.isOpen ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Response Latency: ${_portResult!.latencyMs} ms', style: const TextStyle(fontSize: 12)),
                    if (_portResult!.banner != null) ...[
                      const SizedBox(height: 8),
                      Text('Service Banner: ${_portResult!.banner}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    ],
                  ],
                ),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HTTP THROUGHPUT ENDPOINT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _speedUrlCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. http://192.168.1.1/ or test asset',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _speedLoading ? null : _runSpeed,
                      icon: _speedLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.speed_rounded),
                      label: const Text('Test Link Speed'),
                    ),
                  ),
                ],
              ),
            ),
            if (_speedResult != null) ...[
              const SizedBox(height: 16),
              FintechHeroCard(
                accentColor: cs.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ESTIMATED LINK SPEED', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      '${_speedResult!.downloadMbps.toStringAsFixed(2)} Mbps',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text('Transfer Latency: ${_speedResult!.latencyMs} ms', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    if (_speedResult!.error != null) ...[
                      const SizedBox(height: 6),
                      Text('Note: ${_speedResult!.error}', style: const TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
