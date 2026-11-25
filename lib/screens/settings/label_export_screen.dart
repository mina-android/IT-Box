import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/database_helper.dart';
import '../../models/access_point.dart';
import '../../models/electronic.dart';
import '../../models/laptop.dart';
import '../../models/mifi.dart';
import '../../models/network_device.dart';
import '../../models/printer.dart';
import '../../models/wifi_network.dart';
import '../../services/label_service.dart';
import '../../services/wifi_pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class LabelExportScreen extends StatefulWidget {
  const LabelExportScreen({super.key});
  @override
  State<LabelExportScreen> createState() => _LabelExportScreenState();
}

class _LabelExportScreenState extends State<LabelExportScreen> {
  final _db = DatabaseHelper();
  final Set<String> _selectedCategories = {'laptops'};
  bool _loading = false;
  String _exportFormat = 'labels'; // 'labels' or 'qr'
  Map<String, List<String>> _labels = {};
  Map<String, List<Map<String, String>>> _qrItems = {};
  bool _dataLoaded = false;
  int _activeTab = 0; // 0: Category Inventory, 1: Custom Queue, 2: Wi-Fi Cards
  final List<String> _customQueue = [];
  List<WifiNetworkInfo> _allWifiNets = [];
  final Set<WifiNetworkInfo> _selectedWifiNets = {};

  final _categories = const [
    {'key': 'laptops',       'label': 'Laptops',          'icon': Icons.laptop_outlined},
    {'key': 'network',       'label': 'Routers',          'icon': Icons.router_outlined},
    {'key': 'mifis',         'label': 'MiFis',            'icon': Icons.wifi_tethering_outlined},
    {'key': 'access_points', 'label': 'APs',              'icon': Icons.cell_tower_outlined},
    {'key': 'printers',      'label': 'Printers',         'icon': Icons.print_outlined},
    {'key': 'electronics',   'label': 'Electronics',      'icon': Icons.devices_other_outlined},
    {'key': 'switches',      'label': 'Switches & Patch', 'icon': Icons.settings_input_hdmi_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _db.getLaptops(),
        _db.getNetworkDevices(),
        _db.getMiFis(),
        _db.getAccessPoints(),
        _db.getPrinters(),
        _db.getElectronics(),
        _db.getWifiNetworks(),
      ]);
      final laptops     = results[0] as List<Laptop>;
      final nets        = results[1] as List<NetworkDevice>;
      final mifis       = results[2] as List<MiFi>;
      final aps         = results[3] as List<AccessPoint>;
      final printers    = results[4] as List<Printer>;
      final electronics = results[5] as List<Electronic>;
      final standalones = results[6] as List<WifiNetwork>;

      // Load switch and patch panel chassis from org-scoped SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final rawChassisJson = prefs.getString(DatabaseHelper.scopedSwitchChassisKey()) ??
          prefs.getString('custom_switch_patch_chassis_v1');
      List<Map<String, dynamic>> chassisItems = [];
      if (rawChassisJson != null && rawChassisJson.isNotEmpty) {
        try {
          final List decoded = jsonDecode(rawChassisJson);
          chassisItems = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {}
      }
      if (chassisItems.isEmpty) {
        chassisItems = [
          {'id': 1, 'name': 'Core Distribution Switch', 'type': 'Switch', 'totalPorts': 24, 'location': 'Server Room Rack 1'},
          {'id': 2, 'name': 'Main Office Patch Panel', 'type': 'Patch Panel', 'totalPorts': 24, 'location': 'Floor 2 Comm Closet'},
        ];
      }

      final wifiList = <WifiNetworkInfo>[];
      final seenSsids = <String>{};

      void addWifi(String ssid, String pass, String location) {
        final trimmed = ssid.trim();
        if (trimmed.isNotEmpty && !seenSsids.contains(trimmed.toLowerCase())) {
          seenSsids.add(trimmed.toLowerCase());
          wifiList.add(WifiNetworkInfo(
            ssid: trimmed,
            password: pass,
            locationOrTag: location,
          ));
        }
      }

      for (final r in nets) {
        if (r.wifiName.isNotEmpty) {
          addWifi(
            r.wifiName,
            r.wifiPassword,
            r.deviceLocation.isNotEmpty ? r.deviceLocation : r.model,
          );
        }
      }
      for (final m in mifis) {
        if (m.wifiName.isNotEmpty) {
          addWifi(
            m.wifiName,
            m.wifiPassword,
            'MiFi #${m.deviceNumber}',
          );
        }
      }
      for (final s in standalones) {
        if (s.networkName.isNotEmpty) {
          addWifi(
            s.networkName,
            s.password,
            s.locationDevice.isNotEmpty ? s.locationDevice : 'Standalone Network',
          );
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _labels = {
          'laptops':       laptops.map<String>((l) => l.laptopNumber).toList(),
          'network':       nets.map<String>((d) => d.phoneNumber.isNotEmpty
              ? '${d.deviceNumber}\n${d.phoneNumber}' : d.deviceNumber).toList(),
          'mifis':         mifis.map<String>((m) => m.phoneNumber.isNotEmpty
              ? '${m.deviceNumber}\n${m.phoneNumber}' : m.deviceNumber).toList(),
          'access_points': aps.map<String>((a) => a.portNumber.isNotEmpty
              ? '${a.deviceNumber}\n${a.portNumber}' : a.deviceNumber).toList(),
          'printers':      printers.map<String>((p) => p.printerNumber).toList(),
          'electronics':   electronics.map<String>((e) => e.deviceNumber).toList(),
          'switches':      chassisItems.map<String>((c) => c['name'].toString()).toList(),
        };
        _qrItems = {
          'laptops': laptops.map<Map<String, String>>((l) => {
            'code': l.laptopNumber,
            'title': l.model,
            'subtitle': l.user.isNotEmpty ? 'User: ${l.user}' : 'In Stock',
          }).toList(),
          'network': nets.map<Map<String, String>>((d) => {
            'code': d.deviceNumber,
            'title': d.model,
            'subtitle': d.deviceLocation,
          }).toList(),
          'mifis': mifis.map<Map<String, String>>((m) => {
            'code': m.deviceNumber,
            'title': m.model,
            'subtitle': dPhone(m.phoneNumber),
          }).toList(),
          'access_points': aps.map<Map<String, String>>((a) => {
            'code': a.deviceNumber,
            'title': a.model,
            'subtitle': a.location,
          }).toList(),
          'printers': printers.map<Map<String, String>>((p) => {
            'code': p.printerNumber,
            'title': p.model,
            'subtitle': p.location,
          }).toList(),
          'electronics': electronics.map<Map<String, String>>((e) => {
            'code': e.deviceNumber,
            'title': e.deviceName,
            'subtitle': e.details,
          }).toList(),
          'switches': chassisItems.map<Map<String, String>>((c) => {
            'code': '${c['type'].toString().toUpperCase()}-${c['id']}',
            'title': c['name'].toString(),
            'subtitle': '',
          }).toList(),
        };
        _allWifiNets = wifiList;
        _selectedWifiNets.clear();
        _selectedWifiNets.addAll(wifiList);
        _dataLoaded = true;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _dataLoaded = true);
      showSnack(context, 'Failed to load asset labels: $e', error: true);
    }
  }

  static String dPhone(String p) => p.isNotEmpty ? 'Phone: $p' : '';

  List<String> get _currentLabels {
    if (_activeTab == 1) {
      return _customQueue;
    }
    final list = <String>[];
    for (final cat in _categories) {
      final key = cat['key'] as String;
      if (_selectedCategories.contains(key)) {
        list.addAll(_labels[key] ?? []);
      }
    }
    return list;
  }

  List<Map<String, String>> get _currentQrItems {
    if (_activeTab == 1) {
      return _customQueue.map((item) {
        final lines = item.split('\n');
        return {
          'code': lines[0],
          'title': lines.length > 1 ? lines[1] : 'Custom Item',
          'subtitle': '',
        };
      }).toList();
    }
    final list = <Map<String, String>>[];
    for (final cat in _categories) {
      final key = cat['key'] as String;
      if (_selectedCategories.contains(key)) {
        list.addAll(_qrItems[key] ?? []);
      }
    }
    return list;
  }

  Future<void> _addCustomItemDialog() async {
    final titleCtrl = TextEditingController();
    final subCtrl = TextEditingController();

    final added = await showFintechBottomSheet<bool>(
      context: context,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Label to Queue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            FintechGroupedCard(
              children: [
                AppTextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Label Text / Tag / Asset ID *',
                    hintText: 'e.g. LAP-042 or SERVER-RACK-1',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: subCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sub-line (Optional)',
                    hintText: 'e.g. Phone number or Department',
                    prefixIcon: Icon(Icons.short_text_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Add to Queue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );

    if (added == true && mounted) {
      final text = subCtrl.text.trim().isNotEmpty
          ? '${titleCtrl.text.trim()}\n${subCtrl.text.trim()}'
          : titleCtrl.text.trim();
      setState(() => _customQueue.add(text));
    }
  }

  Future<void> _export() async {
    final labels = _currentLabels;
    if (labels.isEmpty) {
      showSnack(context, _activeTab == 1 ? 'Custom queue is empty' : 'No devices in this category', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final title = _activeTab == 1
          ? 'Custom Asset Labels'
          : (_selectedCategories.length == 1
              ? '${_categories.firstWhere((c) => c['key'] == _selectedCategories.first)['label']} Labels'
              : _selectedCategories.length == _categories.length
                  ? 'All Devices Labels'
                  : 'Mixed Devices Labels');
      
      await LabelService.printLabels(
        labels: labels,
        title: title,
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportQr() async {
    final qrItems = _currentQrItems;
    if (qrItems.isEmpty) {
      showSnack(context, _activeTab == 1 ? 'Custom queue is empty' : 'No devices in this category', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final title = _activeTab == 1
          ? 'Custom Asset QR Codes'
          : (_selectedCategories.length == 1
              ? '${_categories.firstWhere((c) => c['key'] == _selectedCategories.first)['label']} QR Codes'
              : _selectedCategories.length == _categories.length
                  ? 'All Fleet QR Asset Codes'
                  : 'Inventory Asset QR Codes');

      await LabelService.printDeviceQrCodes(
        items: qrItems,
        title: title,
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'QR export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportWifiCards() async {
    if (_selectedWifiNets.isEmpty) {
      showSnack(context, 'Please select at least one Wi-Fi network', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await WifiPdfService.generateAndShareWifiCards(
        networks: _selectedWifiNets.toList(),
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Wi-Fi Cards export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPortableWifiCards() async {
    if (_selectedWifiNets.isEmpty) {
      showSnack(context, 'Please select at least one Wi-Fi network', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await WifiPdfService.generateAndSharePortableWifiCards(
        networks: _selectedWifiNets.toList(),
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Portable Wi-Fi Cards export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = _currentLabels;

    // Build preview grid (padded to multiple of 4)
    final items = List<String>.from(labels);
    while (items.length % 4 != 0) {
      items.add('');
    }
    final rows = <List<String>>[];
    for (var i = 0; i < items.length; i += 4) {
      rows.add(items.sublist(i, i + 4));
    }

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Export Asset Labels & QR',
        subtitle: _activeTab == 2
            ? 'Printable Wi-Fi network credential cards'
            : (_exportFormat == 'qr'
                ? 'Printable QR code sticker tags'
                : 'Printable 4-column device labels'),
        actions: [
          if (_activeTab == 1 && _customQueue.isNotEmpty)
            FintechCircleButton(
              icon: Icons.delete_sweep_outlined,
              tooltip: 'Clear Custom Queue',
              onTap: () => setState(() => _customQueue.clear()),
            ),
        ],
      ),
      body: _dataLoaded
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 3-Subtab Mode Switcher ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // Subtab 0: Category Inventory
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _activeTab == 0
                                  ? AppColors.cardSurface(context)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: _activeTab == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Categories',
                                style: TextStyle(
                                  fontWeight: _activeTab == 0 ? FontWeight.w800 : FontWeight.w500,
                                  fontSize: 12.5,
                                  color: _activeTab == 0
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Subtab 1: Custom Label Queue
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _activeTab == 1
                                  ? AppColors.cardSurface(context)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: _activeTab == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Custom Queue (${_customQueue.length})',
                                style: TextStyle(
                                  fontWeight: _activeTab == 1 ? FontWeight.w800 : FontWeight.w500,
                                  fontSize: 12.5,
                                  color: _activeTab == 1
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Subtab 2: Wi-Fi Cards
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 2),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _activeTab == 2
                                  ? AppColors.cardSurface(context)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: _activeTab == 2
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Wi-Fi Cards',
                                style: TextStyle(
                                  fontWeight: _activeTab == 2 ? FontWeight.w800 : FontWeight.w500,
                                  fontSize: 12.5,
                                  color: _activeTab == 2
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Wi-Fi Cards Subtab View ────────────────────────
                if (_activeTab == 2) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionLabel('SELECT WI-FI NETWORKS (3 / PAGE OR PORTABLE)'),
                      if (_allWifiNets.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedWifiNets.length == _allWifiNets.length) {
                                _selectedWifiNets.clear();
                              } else {
                                _selectedWifiNets.clear();
                                _selectedWifiNets.addAll(_allWifiNets);
                              }
                            });
                          },
                          child: Text(
                            _selectedWifiNets.length == _allWifiNets.length ? 'Deselect All' : 'Select All',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generate framed Standard cards (3 per A4 sheet) or compact Portable Cards (7cm × 4cm, 20 per Landscape A4 sheet) with QR codes.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_allWifiNets.isEmpty)
                    const EmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'No Wi-Fi Networks Configured',
                      subtitle: 'Add Wi-Fi SSIDs in Routers or MiFis inventory to generate cards.',
                    )
                  else ...[
                    ...List.generate(_allWifiNets.length, (i) {
                      final net = _allWifiNets[i];
                      final isSel = _selectedWifiNets.contains(net);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel
                                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: CheckboxListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          title: Text(net.ssid, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${net.locationOrTag} • Password: ${net.password.isNotEmpty ? "••••••••" : "None"}'),
                          secondary: Icon(Icons.wifi_rounded, color: theme.colorScheme.primary),
                          value: isSel,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedWifiNets.add(net);
                              } else {
                                _selectedWifiNets.remove(net);
                              }
                            });
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _loading || _selectedWifiNets.isEmpty ? null : _exportWifiCards,
                            icon: _loading
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.print_rounded, size: 18),
                            label: const Text('Standard (3/Page)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loading || _selectedWifiNets.isEmpty ? null : _exportPortableWifiCards,
                            icon: const Icon(Icons.badge_outlined, size: 18),
                            label: const Text('Portable (7×4cm)'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else ...[
                  // ── Output Format Switcher (Labels vs QR) ──────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _exportFormat = 'labels'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _exportFormat == 'labels'
                                    ? AppColors.cardSurface(context)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: _exportFormat == 'labels'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.label_outline_rounded,
                                      size: 16,
                                      color: _exportFormat == 'labels'
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Text Labels (4-Col)',
                                    style: TextStyle(
                                      fontWeight: _exportFormat == 'labels' ? FontWeight.w800 : FontWeight.w600,
                                      fontSize: 12,
                                      color: _exportFormat == 'labels'
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _exportFormat = 'qr'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _exportFormat == 'qr'
                                    ? AppColors.cardSurface(context)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: _exportFormat == 'qr'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code_2_rounded,
                                      size: 16,
                                      color: _exportFormat == 'qr'
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'QR Code Stickers',
                                    style: TextStyle(
                                      fontWeight: _exportFormat == 'qr' ? FontWeight.w800 : FontWeight.w600,
                                      fontSize: 12,
                                      color: _exportFormat == 'qr'
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (_activeTab == 0) ...[
                    // ── Category chips ──────────────────────────────
                    const SectionLabel('SELECT CATEGORY'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final key = cat['key'] as String;
                        final isSelected = _selectedCategories.contains(key);
                        final cnt = (_labels[key] ?? []).length;
                        return FintechFilterPill(
                          label: '${cat['label']} ($cnt)',
                          icon: cat['icon'] as IconData,
                          selected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedCategories.remove(key);
                              } else {
                                _selectedCategories.add(key);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    // ── Custom queue controls ───────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SectionLabel('TEMPORARY LABELS QUEUE'),
                        ElevatedButton.icon(
                          onPressed: _addCustomItemDialog,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Label'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Build a temporary list of arbitrary or custom label texts to export matching the same printable grid.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Preview grid ────────────────────────────────
                  if (_exportFormat == 'qr') ...[
                    const SectionLabel('QR CODE STICKERS PREVIEW'),
                    if (_currentQrItems.isEmpty)
                      const EmptyState(
                        icon: Icons.qr_code_2_rounded,
                        title: 'No Assets Selected',
                        subtitle: 'Select categories above to preview and export QR stickers.',
                      )
                    else ...[
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.88,
                        ),
                        itemCount: _currentQrItems.length > 9 ? 9 : _currentQrItems.length,
                        itemBuilder: (ctx, i) {
                          final item = _currentQrItems[i];
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_2_rounded, size: 48, color: theme.colorScheme.onSurface),
                                const SizedBox(height: 6),
                                Text(
                                  item['code'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Showing preview of ${_currentQrItems.length > 9 ? 9 : _currentQrItems.length} of ${_currentQrItems.length} sticker(s) · 12 per A4 sheet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ] else ...[
                    const SectionLabel('LABEL PREVIEW'),
                    if (labels.isEmpty)
                      const EmptyState(
                        icon: Icons.label_outline,
                        title: 'No Labels',
                        subtitle: 'No devices in this category.')
                    else ...[
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor, width: 2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Table(
                          border: TableBorder.all(
                              color: theme.dividerColor, width: 1.5),
                          columnWidths: const {
                            0: FlexColumnWidth(),
                            1: FlexColumnWidth(),
                            2: FlexColumnWidth(),
                            3: FlexColumnWidth(),
                          },
                          children: rows.map((row) {
                            return TableRow(
                              children: row.map((cell) {
                                return TableCell(
                                  verticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  child: Container(
                                    height: cell.contains('\n') ? 54 : 44,
                                    color: cell.isEmpty
                                        ? theme.colorScheme
                                            .surfaceContainerHighest
                                        : null,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.all(6),
                                    child: cell.isEmpty
                                        ? Text(
                                            '—',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.3),
                                              letterSpacing: 0.2,
                                            ),
                                          )
                                        : cell.contains('\n')
                                            ? Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    cell.split('\n')[0],
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 11,
                                                      color: theme.colorScheme.onSurface,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 1),
                                                  Text(
                                                    cell.split('\n')[1],
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 9,
                                                      color: theme.colorScheme.onSurface
                                                          .withValues(alpha: 0.55),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                cell,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11,
                                                  color: theme.colorScheme.onSurface,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                  ),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${labels.length} label(s) · ${rows.length} row(s) · 4 columns',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),

                  // ── Export button ───────────────────────────────
                  if ((_exportFormat == 'qr' ? _currentQrItems : labels).isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _loading ? null : (_exportFormat == 'qr' ? _exportQr : _export),
                      icon: _loading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(_exportFormat == 'qr' ? Icons.qr_code_2_rounded : Icons.share_outlined),
                      label: Text(_loading
                          ? 'Generating PDF…'
                          : (_exportFormat == 'qr'
                              ? 'Export Printable QR Codes PDF (${_currentQrItems.length} stickers)'
                              : 'Export PDF (${labels.length} labels)')),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // ── Info box ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _exportFormat == 'qr'
                                ? 'Generates a PDF of high-contrast printable QR code asset stickers '
                                  'formatted 12-per-page for asset tagging and scanner pairing.'
                                : 'Generates a PDF with a 4-column label grid matching '
                                  'the attached format, then opens the share sheet so '
                                  'you can save, print, or send it.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            )
          : const ShimmerListLoader(),
    );
  }
}
