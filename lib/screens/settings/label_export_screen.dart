import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../services/label_service.dart';
import '../../widgets/common_widgets.dart';

class LabelExportScreen extends StatefulWidget {
  const LabelExportScreen({super.key});
  @override
  State<LabelExportScreen> createState() => _LabelExportScreenState();
}

class _LabelExportScreenState extends State<LabelExportScreen> {
  final _db = DatabaseHelper();
  String _category = 'laptops';
  bool _loading = false;
  Map<String, List<String>> _labels = {};
  bool _dataLoaded = false;

  final _categories = const [
    {'key': 'laptops',     'label': 'Laptops',         'icon': Icons.laptop_outlined},
    {'key': 'network',     'label': 'Network Devices',  'icon': Icons.router_outlined},
    {'key': 'mifis',       'label': 'MiFis',            'icon': Icons.wifi_tethering_outlined},
    {'key': 'printers',    'label': 'Printers',         'icon': Icons.print_outlined},
    {'key': 'electronics', 'label': 'Electronics',      'icon': Icons.devices_other_outlined},
    {'key': 'all',         'label': 'All Devices',      'icon': Icons.inventory_2_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final laptops     = await _db.getLaptops();
    final nets        = await _db.getNetworkDevices();
    final mifis       = await _db.getMiFis();
    final printers    = await _db.getPrinters();
    final electronics = await _db.getElectronics();
    if (!mounted) return;
    setState(() {
      _labels = {
        'laptops':     laptops.map((l) => l.laptopNumber).toList(),
        'network':     nets.map((d) => d.deviceNumber).toList(),
        'mifis':       mifis.map((m) => m.deviceNumber).toList(),
        'printers':    printers.map((p) => p.printerNumber).toList(),
        'electronics': electronics.map((e) => e.deviceNumber).toList(),
        'all': [
          ...laptops.map((l) => l.laptopNumber),
          ...nets.map((d) => d.deviceNumber),
          ...mifis.map((m) => m.deviceNumber),
          ...printers.map((p) => p.printerNumber),
          ...electronics.map((e) => e.deviceNumber),
        ],
      };
      _dataLoaded = true;
    });
  }

  List<String> get _currentLabels => _labels[_category] ?? [];

  Future<void> _export() async {
    final labels = _currentLabels;
    if (labels.isEmpty) {
      showSnack(context, 'No devices in this category', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final catName = _categories
          .firstWhere((c) => c['key'] == _category)['label'] as String;
      await LabelService.printLabels(
        labels: labels,
        title: '$catName Labels',
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = _currentLabels;

    // Build preview grid (padded to multiple of 3)
    final items = List<String>.from(labels);
    while (items.length % 3 != 0) {
      items.add('');
    }
    final rows = <List<String>>[];
    for (var i = 0; i < items.length; i += 3) {
      rows.add(items.sublist(i, i + 3));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Export Labels')),
      body: _dataLoaded
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Category chips ──────────────────────────────
                const SectionLabel('SELECT CATEGORY'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final key = cat['key'] as String;
                    final isSelected = _category == key;
                    final cnt = (_labels[key] ?? []).length;
                    return FilterChip(
                      label: Text('${cat['label']} ($cnt)'),
                      avatar: Icon(cat['icon'] as IconData, size: 16),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _category = key),
                      selectedColor:
                          theme.colorScheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: theme.colorScheme.primary,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── Preview grid ────────────────────────────────
                const SectionLabel('LABEL PREVIEW'),
                if (labels.isEmpty)
                  const EmptyState(
                    icon: Icons.label_outline,
                    title: 'No Labels',
                    subtitle: 'No devices in this category.',
                  )
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
                      },
                      children: rows.map((row) {
                        return TableRow(
                          children: row.map((cell) {
                            return TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Container(
                                height: 44,
                                color: cell.isEmpty
                                    ? theme.colorScheme
                                        .surfaceContainerHighest
                                    : null,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  cell.isEmpty ? '—' : cell,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: cell.isEmpty ? 12 : 11,
                                    color: cell.isEmpty
                                        ? theme.colorScheme.onSurface
                                            .withValues(alpha: 0.3)
                                        : theme.colorScheme.onSurface,
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
                    '${labels.length} label(s) · ${rows.length} row(s) · 3 columns',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // ── Export button ───────────────────────────────
                if (labels.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _export,
                    icon: _loading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.share_outlined),
                    label: Text(_loading
                        ? 'Generating PDF…'
                        : 'Export PDF (${labels.length} labels)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
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
                          'Generates a PDF with a 3-column label grid matching '
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
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
