// lib/screens/network_tools/switch_patch_matrix_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/database_helper.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import 'switch_patch_chassis_form_screen.dart';

class PatchPanelChassis {
  final int id;
  String name;
  String type; // 'Switch' or 'Patch Panel'
  int totalPorts; // 8, 12, 16, 24, 48
  String location;

  PatchPanelChassis({
    required this.id,
    required this.name,
    this.type = 'Switch',
    this.totalPorts = 24,
    this.location = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'totalPorts': totalPorts,
        'location': location,
      };

  factory PatchPanelChassis.fromJson(Map<String, dynamic> json) =>
      PatchPanelChassis(
        id: json['id'] as int,
        name: json['name'] as String,
        type: json['type'] as String? ?? 'Switch',
        totalPorts: json['totalPorts'] as int? ?? 24,
        location: json['location'] as String? ?? '',
      );
}

class SwitchPatchMatrixScreen extends StatefulWidget {
  const SwitchPatchMatrixScreen({super.key});

  @override
  State<SwitchPatchMatrixScreen> createState() =>
      _SwitchPatchMatrixScreenState();
}

class _SwitchPatchMatrixScreenState extends State<SwitchPatchMatrixScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  static const String _prefKey = 'custom_switch_patch_chassis_v1';

  List<PatchPanelChassis> _chassisList = [];
  PatchPanelChassis? _selectedChassis;
  List<Map<String, dynamic>> _ports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_prefKey);

    if (rawJson != null) {
      try {
        final List decoded = jsonDecode(rawJson);
        _chassisList =
            decoded.map((e) => PatchPanelChassis.fromJson(e)).toList();
      } catch (_) {
        _chassisList = [];
      }
    } else {
      // Fresh install: initialize with default standard units
      _chassisList = [
        PatchPanelChassis(
          id: 1,
          name: 'Core Distribution Switch',
          type: 'Switch',
          totalPorts: 24,
          location: 'Server Room Rack 1',
        ),
        PatchPanelChassis(
          id: 2,
          name: 'MDF Patch Panel A',
          type: 'Patch Panel',
          totalPorts: 24,
          location: 'Main Distribution Frame',
        ),
      ];
      await _saveChassisList();
    }

    if (_chassisList.isNotEmpty) {
      _selectedChassis ??= _chassisList.first;
      // Verify currently selected chassis still exists
      if (!_chassisList.any((c) => c.id == _selectedChassis?.id)) {
        _selectedChassis = _chassisList.first;
      }

      if (_selectedChassis != null) {
        _ports = await _db.getSwitchPatchPorts(_selectedChassis!.id);
      }
    } else {
      _selectedChassis = null;
      _ports = [];
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveChassisList() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_chassisList.map((e) => e.toJson()).toList());
    await prefs.setString(_prefKey, encoded);
  }

  Future<void> _selectChassis(PatchPanelChassis chassis) async {
    setState(() {
      _selectedChassis = chassis;
    });
    final p = await _db.getSwitchPatchPorts(chassis.id);
    if (mounted) {
      setState(() => _ports = p);
    }
  }

  Future<void> _showAddOrEditChassisDialog([PatchPanelChassis? toEdit]) async {
    final result = await Navigator.push<PatchPanelChassis>(
      context,
      MaterialPageRoute(
        builder: (_) => SwitchPatchChassisFormScreen(chassis: toEdit),
      ),
    );
    if (result != null && mounted) {
      if (toEdit == null) {
        _chassisList.add(result);
        _selectedChassis = result;
      } else {
        // C9: Clean up any ports that exceed the updated totalPorts
        final existingPorts = await _db.getSwitchPatchPorts(result.id);
        for (final p in existingPorts) {
          final pNum = p['port_number'] as int? ?? 0;
          if (pNum > result.totalPorts) {
            final portId = p['id'] as int?;
            if (portId != null) {
              await _db.deleteSwitchPatchPort(portId);
            }
          }
        }
      }
      await _saveChassisList();
      if (_selectedChassis != null) {
        _ports = await _db.getSwitchPatchPorts(_selectedChassis!.id);
      }
      setState(() {});
    }
  }

  Future<void> _deleteChassis(PatchPanelChassis chassis) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Unit',
      message: 'Delete "${chassis.name}" and all associated port mappings?',
      confirmText: 'Delete',
    );
    if (!ok || !mounted) return;

    await _db.deleteSwitchPatchPortsForSwitch(chassis.id);
    _chassisList.removeWhere((c) => c.id == chassis.id);
    await _saveChassisList();

    if (!mounted) return;

    if (_chassisList.isNotEmpty) {
      _selectedChassis = _chassisList.first;
      _ports = await _db.getSwitchPatchPorts(_selectedChassis!.id);
    } else {
      _selectedChassis = null;
      _ports = [];
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _configurePort(int portNum) {
    if (_selectedChassis == null) return;
    final existing = _ports.firstWhere(
      (p) => p['port_number'] == portNum,
      orElse: () => {},
    );

    final deviceCtrl =
        TextEditingController(text: existing['connected_device'] ?? '');
    final roomCtrl =
        TextEditingController(text: existing['destination_room'] ?? '');
    final vlanCtrl = TextEditingController(text: existing['vlan'] ?? '1');
    String status = existing['status'] ?? 'Active';

    showFintechBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_selectedChassis!.name} • Port $portNum',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              FintechGroupedCard(
                children: [
                  AppTextField(
                    controller: deviceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Connected Device / Host',
                      hintText: 'e.g. AP-Floor2 / Server-01 / Workstation 14',
                      prefixIcon: Icon(Icons.devices_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: roomCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Destination Room / Patch Drop',
                      hintText: 'e.g. Room 204 Drop A / Desk 12',
                      prefixIcon: Icon(Icons.room_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: vlanCtrl,
                    decoration: const InputDecoration(
                      labelText: 'VLAN Tag',
                      hintText: 'e.g. 10 (Data) / 20 (Voice)',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FintechDropdown<String>(
                    labelText: 'Port Status',
                    prefixIcon: const Icon(Icons.power_settings_new_rounded),
                    value: status,
                    items: const [
                      DropdownMenuItem(value: 'Active', child: Text('Active (Up / Connected)')),
                      DropdownMenuItem(value: 'Down', child: Text('Down (Disconnected)')),
                      DropdownMenuItem(value: 'Disabled', child: Text('Admin Disabled (Port Off)')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setSheetState(() => status = v);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final map = {
                    'switch_device_id': _selectedChassis!.id,
                    'port_number': portNum,
                    'connected_device': deviceCtrl.text.trim(),
                    'destination_room': roomCtrl.text.trim(),
                    'vlan': vlanCtrl.text.trim(),
                    'status': status,
                  };
                  if (existing.isNotEmpty && existing['id'] != null) {
                    await _db.updateSwitchPatchPort(map, existing['id'] as int);
                  } else {
                    await _db.insertSwitchPatchPort(map);
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  _ports = await _db.getSwitchPatchPorts(_selectedChassis!.id);
                  if (mounted) {
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Save Port', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_loading) {
      return const Scaffold(
        appBar: FintechAppBar(
          title: 'Switch & Patch Matrix',
          subtitle: 'Loading chassis & port mappings...',
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final activePortsCount = _ports.where((p) => p['status'] == 'Active').length;
    final totalPorts = _selectedChassis?.totalPorts ?? 24;
    final double rawRatio = totalPorts > 0 ? (activePortsCount / totalPorts) : 0.0;
    final double progressValue = rawRatio.clamp(0.0, 1.0);
    final percentUtilized = (progressValue * 100).round();

    return Scaffold(
      appBar: FintechAppBar(
        title: 'Switch & Patch Matrix',
        subtitle: _selectedChassis != null
            ? '${_selectedChassis!.name} • ${_selectedChassis!.totalPorts} Ports'
            : 'Port mapping & patch bay management',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Horizontal Unit Selector Carousel
            const Text(
              'SELECT CHASSIS / PATCH BAY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _chassisList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) {
                  final c = _chassisList[i];
                  final isSel = c.id == _selectedChassis?.id;
                  final isSwitch = c.type == 'Switch';

                  return InkWell(
                    onTap: () => _selectChassis(c),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel
                            ? cs.primaryContainer.withValues(alpha: 0.5)
                            : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSel
                              ? cs.primary
                              : cs.outlineVariant.withValues(alpha: 0.2),
                          width: isSel ? 1.8 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSwitch
                                ? Icons.hub_rounded
                                : Icons.settings_input_component_rounded,
                            color: isSel ? cs.primary : cs.onSurfaceVariant,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                c.name,
                                style: TextStyle(
                                  fontWeight:
                                      isSel ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 13,
                                  color: isSel ? cs.primary : cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c.type} • ${c.totalPorts} Ports',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                          if (isSel) ...[
                            const SizedBox(width: 10),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 18),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showAddOrEditChassisDialog(c);
                                } else if (val == 'delete') {
                                  _deleteChassis(c);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit Unit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete Unit',
                                          style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            if (_selectedChassis != null) ...[
              // Chassis Port Grid Container
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueGrey.shade800, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedChassis!.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_selectedChassis!.location.isNotEmpty)
                                Text(
                                  _selectedChassis!.location,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.greenAccent.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '${_selectedChassis!.totalPorts}-PORT ${_selectedChassis!.type.toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.blueGrey, height: 24),

                    // Chassis Port Bay (edge-to-edge for < 24 ports, scrollable for >= 24)
                    Builder(
                      builder: (context) {
                        final expand = _selectedChassis!.totalPorts < 24;
                        final portRows = Column(
                          crossAxisAlignment: expand
                              ? CrossAxisAlignment.stretch
                              : CrossAxisAlignment.start,
                          children: [
                            _buildPortRow(
                              1,
                              (_selectedChassis!.totalPorts / 2).ceil(),
                              expand: expand,
                            ),
                            const SizedBox(height: 12),
                            _buildPortRow(
                              (_selectedChassis!.totalPorts / 2).ceil() + 1,
                              _selectedChassis!.totalPorts,
                              expand: expand,
                            ),
                          ],
                        );

                        if (expand) {
                          return portRows;
                        }
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: IntrinsicWidth(
                            child: portRows,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Utilization & Health Card
              FintechGroupedCard(
                title: 'Chassis Telemetry & Port Utilization',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$activePortsCount / $totalPorts Ports Active',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                            Text(
                              '$percentUtilized% Utilized',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: percentUtilized > 85
                                    ? Colors.amber
                                    : cs.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            minHeight: 8,
                            backgroundColor: cs.outlineVariant.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              percentUtilized > 85 ? Colors.amber : cs.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statBadge('Active', activePortsCount, Colors.greenAccent),
                            _statBadge(
                              'Down',
                              _ports.where((p) => p['status'] == 'Down').length,
                              Colors.amberAccent,
                            ),
                            _statBadge(
                              'Disabled',
                              _ports.where((p) => p['status'] == 'Disabled').length,
                              Colors.redAccent,
                            ),
                            _statBadge(
                              'Available',
                              (totalPorts - _ports.length).clamp(0, totalPorts),
                              Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Port Status Legend
              FintechGroupedCard(
                title: 'Port LED Status Legend',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _legendItem(Colors.greenAccent, 'Active (Up)'),
                        _legendItem(Colors.amberAccent, 'Down / Idle'),
                        _legendItem(Colors.redAccent, 'Disabled'),
                        _legendItem(Colors.blueGrey, 'Unconfigured'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FintechFab(
        onPressed: () => _showAddOrEditChassisDialog(),
        tooltip: 'Add Switch or Patch Panel',
        icon: Icons.add_rounded,
      ),
    );
  }

  Widget _statBadge(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPortRow(int start, int end, {bool expand = false}) {
    if (start > end) return const SizedBox();
    final items = List.generate(end - start + 1, (index) {
      final portNum = start + index;
      final conf = _ports.firstWhere(
        (p) => p['port_number'] == portNum,
        orElse: () => {},
      );

      Color ledColor = Colors.blueGrey.shade700;
      if (conf.isNotEmpty) {
        if (conf['status'] == 'Active') ledColor = Colors.greenAccent;
        if (conf['status'] == 'Down') ledColor = Colors.amberAccent;
        if (conf['status'] == 'Disabled') ledColor = Colors.redAccent;
      }

      final portWidget = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5),
        child: InkWell(
          onTap: () => _configurePort(portNum),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: expand ? null : 32,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: conf.isNotEmpty
                    ? ledColor.withValues(alpha: 0.5)
                    : Colors.blueGrey.shade800,
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: ledColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ledColor.withValues(alpha: 0.7),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                const Icon(Icons.usb_rounded, size: 15, color: Colors.blueGrey),
                const SizedBox(height: 3),
                Text(
                  '$portNum',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      return expand ? Expanded(child: portWidget) : portWidget;
    });

    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: items,
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4)
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
