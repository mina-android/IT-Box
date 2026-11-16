// lib/screens/barcode_scanner/barcode_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../database/database_helper.dart';
import '../../widgets/common_widgets.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final bool returnCodeOnly;
  const BarcodeScannerScreen({super.key, this.returnCodeOnly = false});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  Map<String, dynamic>? _foundAsset;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawVal = barcodes.first.rawValue;
    if (rawVal == null || rawVal.trim().isEmpty) return;

    final code = rawVal.trim();

    if (widget.returnCodeOnly) {
      Navigator.pop(context, code);
      return;
    }

    setState(() => _isProcessing = true);

    // Search asset in database
    final db = DatabaseHelper();
    final laptops = await db.getLaptops();
    final networkDevs = await db.getNetworkDevices();
    final printers = await db.getPrinters();
    final electronics = await db.getElectronics();
    final mifis = await db.getMiFis();

    Map<String, dynamic>? match;

    for (final l in laptops) {
      if (l.laptopNumber.toLowerCase() == code.toLowerCase()) {
        match = {'type': 'Laptop', 'number': l.laptopNumber, 'name': l.model, 'user': l.user, 'condition': l.condition};
        break;
      }
    }
    if (match == null) {
      for (final n in networkDevs) {
        if (n.deviceNumber.toLowerCase() == code.toLowerCase()) {
          match = {'type': 'Router', 'number': n.deviceNumber, 'name': n.model, 'user': n.deviceLocation, 'condition': n.status};
          break;
        }
      }
    }
    if (match == null) {
      for (final p in printers) {
        if (p.printerNumber.toLowerCase() == code.toLowerCase()) {
          match = {'type': 'Printer', 'number': p.printerNumber, 'name': p.model, 'user': p.location, 'condition': p.condition};
          break;
        }
      }
    }
    if (match == null) {
      for (final e in electronics) {
        if (e.deviceNumber.toLowerCase() == code.toLowerCase()) {
          match = {'type': 'Electronic', 'number': e.deviceNumber, 'name': e.deviceName, 'user': e.details, 'condition': e.status};
          break;
        }
      }
    }
    if (match == null) {
      for (final m in mifis) {
        if (m.deviceNumber.toLowerCase() == code.toLowerCase()) {
          match = {'type': 'MiFi', 'number': m.deviceNumber, 'name': m.model, 'user': m.phoneNumber, 'condition': m.status};
          break;
        }
      }
    }

    if (mounted) {
      setState(() {
        _foundAsset = match ?? {'type': 'Unknown', 'number': code, 'name': 'Asset not registered in IT Box', 'user': '—', 'condition': '—'};
      });
      _showAssetSheet(_foundAsset!);
    }
  }

  void _showAssetSheet(Map<String, dynamic> asset) {
    showFintechBottomSheet(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  asset['type'] == 'Unknown' ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                  color: asset['type'] == 'Unknown' ? Colors.amber : Colors.green,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Tag / S/N: ${asset['number']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Category:'),
                Text(asset['type'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Assigned / Location:'),
                Text(asset['user'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Status:'),
                Text(asset['condition'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _isProcessing = false);
                },
                child: const Text('Scan Next Item'),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      setState(() => _isProcessing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FintechAppBar(
        title: 'Asset Barcode / QR Scanner',
        actions: [
          FintechCircleButton(
            icon: Icons.flash_on_rounded,
            tooltip: 'Toggle Flash',
            onPressed: () => _controller.toggleTorch(),
          ),
          FintechCircleButton(
            icon: Icons.cameraswitch_rounded,
            tooltip: 'Switch Camera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Align QR code or Barcode inside the frame',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
