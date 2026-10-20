// test/scanner_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:itbox/services/network_scanner_service.dart';

void main() {
  test('Network Scanner parses target IP ranges correctly', () {
    final ips1 = NetworkScannerService.parseTargetIps('192.168.1.1-5');
    expect(ips1, ['192.168.1.1', '192.168.1.2', '192.168.1.3', '192.168.1.4', '192.168.1.5']);

    final ips2 = NetworkScannerService.parseTargetIps('10.0.0.0/30');
    expect(ips2, ['10.0.0.1', '10.0.0.2']);

    final vendor = NetworkScannerService.lookupVendor('00:03:93:11:22:33');
    expect(vendor, 'Apple');

    final ciscoVendor = NetworkScannerService.lookupVendor('00:00:0c:ab:cd:ef');
    expect(ciscoVendor, 'Cisco');
  });

  test('Win32 Arp Scanner and Sweep initialize gracefully', () async {
    final scanner = NetworkScannerService();
    expect(scanner.isScanning, false);
  });
}
