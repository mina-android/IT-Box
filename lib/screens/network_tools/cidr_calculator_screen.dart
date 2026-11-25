// lib/screens/network_tools/cidr_calculator_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class CidrCalculatorScreen extends StatefulWidget {
  const CidrCalculatorScreen({super.key});

  @override
  State<CidrCalculatorScreen> createState() => _CidrCalculatorScreenState();
}

class _CidrCalculatorScreenState extends State<CidrCalculatorScreen> {
  final _ipController = TextEditingController(text: '192.168.1.0');
  int _prefix = 24;

  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _calculate() {
    final ipStr = _ipController.text.trim();
    final parts = ipStr.split('.');
    if (parts.length != 4) {
      setState(() => _result = null);
      return;
    }

    final parsed = parts.map((p) => int.tryParse(p)).toList();
    if (parsed.any((o) => o == null || o < 0 || o > 255)) {
      setState(() => _result = null);
      return;
    }
    final octets = parsed.cast<int>();

    final ipInt = (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
    final maskInt = _prefix == 0 ? 0 : (~0 << (32 - _prefix)) & 0xFFFFFFFF;
    final netInt = ipInt & maskInt;
    final bcastInt = netInt | (~maskInt & 0xFFFFFFFF);

    final totalHosts = pow(2, 32 - _prefix).toInt();
    final usableHosts = _prefix >= 31 ? 0 : totalHosts - 2;

    final firstUsable = usableHosts > 0 ? netInt + 1 : netInt;
    final lastUsable = usableHosts > 0 ? bcastInt - 1 : bcastInt;

    setState(() {
      _result = {
        'netmask': _intToIp(maskInt),
        'wildcard': _intToIp(~maskInt & 0xFFFFFFFF),
        'network': _intToIp(netInt),
        'broadcast': _intToIp(bcastInt),
        'firstUsable': _intToIp(firstUsable),
        'lastUsable': _intToIp(lastUsable),
        'usableHosts': usableHosts,
        'totalHosts': totalHosts,
      };
    });
  }

  String _intToIp(int val) {
    return '${(val >> 24) & 0xFF}.${(val >> 16) & 0xFF}.${(val >> 8) & 0xFF}.${val & 0xFF}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: const FintechAppBar(
        title: 'Subnet Calculator',
        subtitle: 'IPv4 subnet boundaries & host capacity',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FintechGroupedCard(
              title: 'IP & Prefix Configuration',
              children: [
                AppTextField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: 'IP Address',
                    hintText: 'e.g. 192.168.1.0 or 10.0.0.1',
                    prefixIcon: Icon(Icons.lan_rounded),
                  ),
                  keyboardType: TextInputType.datetime,
                  onChanged: (_) => _calculate(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subnet Prefix: /$_prefix', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      _result != null ? 'Mask: ${_result!['netmask']}' : '',
                      style: TextStyle(fontSize: 12, color: cs.primary),
                    ),
                  ],
                ),
                Slider(
                  value: _prefix.toDouble(),
                  min: 8,
                  max: 32,
                  divisions: 24,
                  label: '/$_prefix',
                  onChanged: (v) {
                    setState(() => _prefix = v.toInt());
                    _calculate();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_result != null) ...[
              FintechHeroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'USABLE HOST CAPACITY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_result!['usableHosts']} Hosts',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Range: ${_result!['firstUsable']} – ${_result!['lastUsable']}',
                      style: credentialFont(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FintechGroupedCard(
                title: 'Subnet Details',
                children: [
                  _detailRow('Network Address', _result!['network']),
                  _detailRow('Broadcast Address', _result!['broadcast']),
                  _detailRow('Subnet Mask', _result!['netmask']),
                  _detailRow('Wildcard Mask', _result!['wildcard']),
                  _detailRow('Total Addresses', '${_result!['totalHosts']}'),
                  _detailRow('Usable Hosts', '${_result!['usableHosts']}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: credentialFont(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
