// lib/screens/network_tools/unit_converter_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';

enum ConverterCategory {
  dataTransfer,
  storage,
  powerDbm,
}

class UnitConverterScreen extends StatefulWidget {
  const UnitConverterScreen({super.key});

  @override
  State<UnitConverterScreen> createState() => _UnitConverterScreenState();
}

class _UnitConverterScreenState extends State<UnitConverterScreen> {
  ConverterCategory _category = ConverterCategory.dataTransfer;
  final _inputCtrl = TextEditingController(text: '100');

  String _fromUnit = 'Mbps';
  String _toUnit = 'MB/s';

  static const List<String> _dataTransferUnits = [
    'bps',
    'Kbps',
    'Mbps',
    'Gbps',
    'B/s',
    'KB/s',
    'MB/s',
    'GB/s',
  ];

  static const List<String> _storageUnits = [
    'Bytes',
    'KB',
    'MB',
    'GB',
    'TB',
    'KiB',
    'MiB',
    'GiB',
    'TiB',
  ];

  static const List<String> _powerUnits = [
    'dBm',
    'mW',
    'W',
  ];

  @override
  void initState() {
    super.initState();
    _updateUnitsForCategory();
    _inputCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _updateUnitsForCategory() {
    switch (_category) {
      case ConverterCategory.dataTransfer:
        _fromUnit = 'Mbps';
        _toUnit = 'MB/s';
        break;
      case ConverterCategory.storage:
        _fromUnit = 'GB';
        _toUnit = 'GiB';
        break;
      case ConverterCategory.powerDbm:
        _fromUnit = 'dBm';
        _toUnit = 'mW';
        break;
    }
  }

  List<String> get _currentUnits {
    switch (_category) {
      case ConverterCategory.dataTransfer:
        return _dataTransferUnits;
      case ConverterCategory.storage:
        return _storageUnits;
      case ConverterCategory.powerDbm:
        return _powerUnits;
    }
  }

  double _convertValue(double input) {
    if (_fromUnit == _toUnit) return input;

    if (_category == ConverterCategory.dataTransfer) {
      // Base unit: bits per second (bps)
      double toBps(double v, String u) {
        switch (u) {
          case 'bps': return v;
          case 'Kbps': return v * 1e3;
          case 'Mbps': return v * 1e6;
          case 'Gbps': return v * 1e9;
          case 'B/s': return v * 8;
          case 'KB/s': return v * 8e3;
          case 'MB/s': return v * 8e6;
          case 'GB/s': return v * 8e9;
          default: return v;
        }
      }

      double fromBps(double bps, String u) {
        switch (u) {
          case 'bps': return bps;
          case 'Kbps': return bps / 1e3;
          case 'Mbps': return bps / 1e6;
          case 'Gbps': return bps / 1e9;
          case 'B/s': return bps / 8;
          case 'KB/s': return bps / 8e3;
          case 'MB/s': return bps / 8e6;
          case 'GB/s': return bps / 8e9;
          default: return bps;
        }
      }

      return fromBps(toBps(input, _fromUnit), _toUnit);
    } else if (_category == ConverterCategory.storage) {
      // Base unit: bytes
      double toBytes(double v, String u) {
        switch (u) {
          case 'Bytes': return v;
          case 'KB': return v * 1000;
          case 'MB': return v * 1e6;
          case 'GB': return v * 1e9;
          case 'TB': return v * 1e12;
          case 'KiB': return v * 1024;
          case 'MiB': return v * pow(1024, 2);
          case 'GiB': return v * pow(1024, 3);
          case 'TiB': return v * pow(1024, 4);
          default: return v;
        }
      }

      double fromBytes(double b, String u) {
        switch (u) {
          case 'Bytes': return b;
          case 'KB': return b / 1000;
          case 'MB': return b / 1e6;
          case 'GB': return b / 1e9;
          case 'TB': return b / 1e12;
          case 'KiB': return b / 1024;
          case 'MiB': return b / pow(1024, 2);
          case 'GiB': return b / pow(1024, 3);
          case 'TiB': return b / pow(1024, 4);
          default: return b;
        }
      }

      return fromBytes(toBytes(input, _fromUnit), _toUnit);
    } else {
      // Power: dBm <-> mW <-> W
      // Base unit: mW
      double toMilliwatts(double v, String u) {
        switch (u) {
          case 'dBm': return pow(10, v / 10).toDouble();
          case 'mW': return v;
          case 'W': return v * 1000;
          default: return v;
        }
      }

      double fromMilliwatts(double mw, String u) {
        if (mw <= 0 && u == 'dBm') return double.negativeInfinity;
        switch (u) {
          case 'dBm': return 10 * (log(mw) / ln10);
          case 'mW': return mw;
          case 'W': return mw / 1000;
          default: return mw;
        }
      }

      return fromMilliwatts(toMilliwatts(input, _fromUnit), _toUnit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final inputVal = double.tryParse(_inputCtrl.text.trim()) ?? 0.0;
    final converted = _convertValue(inputVal);

    String resultText;
    if (converted.isInfinite || converted.isNaN) {
      resultText = 'Undefined';
    } else if (converted.abs() >= 1e6 || (converted.abs() < 1e-4 && converted != 0)) {
      resultText = converted.toStringAsExponential(4);
    } else {
      resultText = converted.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '');
    }

    return Scaffold(
      appBar: const FintechAppBar(
        title: 'IT & Network Unit Converter',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ConverterCategory>(
            segments: const [
              ButtonSegment(
                value: ConverterCategory.dataTransfer,
                label: Text('Speed'),
                icon: Icon(Icons.speed_rounded),
              ),
              ButtonSegment(
                value: ConverterCategory.storage,
                label: Text('Storage'),
                icon: Icon(Icons.sd_storage_rounded),
              ),
              ButtonSegment(
                value: ConverterCategory.powerDbm,
                label: Text('RF Power'),
                icon: Icon(Icons.wifi_tethering_rounded),
              ),
            ],
            selected: {_category},
            onSelectionChanged: (val) {
              AppHaptics.tap(context, HapticStrength.selection);
              setState(() {
                _category = val.first;
                _updateUnitsForCategory();
              });
            },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INPUT VALUE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _inputCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          hintText: '0.0',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _fromUnit,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        items: _currentUnits
                            .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontWeight: FontWeight.w700))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _fromUnit = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.swap_vert_rounded),
                    onPressed: () {
                      AppHaptics.tap(context, HapticStrength.light);
                      setState(() {
                        final temp = _fromUnit;
                        _fromUnit = _toUnit;
                        _toUnit = temp;
                      });
                    },
                    tooltip: 'Swap Units',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'TARGET UNIT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _toUnit,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: _currentUnits
                      .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontWeight: FontWeight.w700))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _toUnit = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FintechHeroCard(
            accentColor: cs.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CONVERTED EQUIVALENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: Colors.white70,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white),
                      onPressed: () {
                        AppHaptics.tap(context, HapticStrength.light);
                        showSnack(context, '$resultText $_toUnit copied to clipboard');
                      },
                      tooltip: 'Copy result',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$resultText $_toUnit',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_inputCtrl.text} $_fromUnit = $resultText $_toUnit',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
