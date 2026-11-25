// lib/services/network_scanner_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:network_info_plus/network_info_plus.dart';

enum DeviceTypeGuess {
  router,
  printer,
  workstation,
  server,
  mobile,
  smartTv,
  iot,
  other,
}

class ScanOptions {
  final int socketTimeoutMs;
  final int concurrency;
  final bool enableMdns;
  final bool enableSsdp;
  final bool enableNetbios;
  final bool enableLlmnr;
  final bool enableHttpTitle;
  final bool enableIcmpPing;
  final bool enableDualPass;
  final List<int> portsToProbe;

  const ScanOptions({
    this.socketTimeoutMs = 250,
    this.concurrency = 32,
    this.enableMdns = true,
    this.enableSsdp = true,
    this.enableNetbios = true,
    this.enableLlmnr = true,
    this.enableHttpTitle = true,
    this.enableIcmpPing = true,
    this.enableDualPass = true,
    this.portsToProbe = NetworkScannerService.defaultProbePorts,
  });

  ScanOptions copyWith({
    int? socketTimeoutMs,
    int? concurrency,
    bool? enableMdns,
    bool? enableSsdp,
    bool? enableNetbios,
    bool? enableLlmnr,
    bool? enableHttpTitle,
    bool? enableIcmpPing,
    bool? enableDualPass,
    List<int>? portsToProbe,
  }) {
    return ScanOptions(
      socketTimeoutMs: socketTimeoutMs ?? this.socketTimeoutMs,
      concurrency: concurrency ?? this.concurrency,
      enableMdns: enableMdns ?? this.enableMdns,
      enableSsdp: enableSsdp ?? this.enableSsdp,
      enableNetbios: enableNetbios ?? this.enableNetbios,
      enableLlmnr: enableLlmnr ?? this.enableLlmnr,
      enableHttpTitle: enableHttpTitle ?? this.enableHttpTitle,
      enableIcmpPing: enableIcmpPing ?? this.enableIcmpPing,
      enableDualPass: enableDualPass ?? this.enableDualPass,
      portsToProbe: portsToProbe ?? this.portsToProbe,
    );
  }
}

class ProbePortsResult {
  final List<int> openPorts;
  final bool connectionRefused;
  const ProbePortsResult({this.openPorts = const [], this.connectionRefused = false});
}

class DiscoveredHost {
  final String ip;
  String hostname;
  String? macAddress;
  String? vendor;
  String osGuess;
  DeviceTypeGuess typeGuess;
  int responseTimeMs;
  List<int> openPorts;
  String? webTitle;
  String? netbiosGroup;
  String? netbiosUser;
  String? serviceBanner;
  String discoveryMethod;
  bool isAlive;

  DiscoveredHost({
    required this.ip,
    this.hostname = '',
    this.macAddress,
    this.vendor,
    this.osGuess = 'Unknown Device',
    this.typeGuess = DeviceTypeGuess.other,
    this.responseTimeMs = 0,
    List<int>? openPorts,
    this.webTitle,
    this.netbiosGroup,
    this.netbiosUser,
    this.serviceBanner,
    this.discoveryMethod = 'Layer-2 ARP',
    this.isAlive = true,
  }) : openPorts = openPorts ?? [];

  String get displayName {
    if (hostname.isNotEmpty) {
      return hostname;
    }
    if (webTitle != null && webTitle!.trim().isNotEmpty) {
      return webTitle!.trim();
    }
    if (vendor != null && vendor!.isNotEmpty) {
      return '$vendor Device';
    }
    switch (typeGuess) {
      case DeviceTypeGuess.router:
        return 'Network Gateway';
      case DeviceTypeGuess.printer:
        return 'Network Printer';
      case DeviceTypeGuess.workstation:
        return 'Workstation / PC';
      case DeviceTypeGuess.server:
        return 'Network Server';
      case DeviceTypeGuess.mobile:
        return 'Mobile Device';
      case DeviceTypeGuess.smartTv:
        return 'Smart TV / Media';
      case DeviceTypeGuess.iot:
        return 'IoT Device';
      case DeviceTypeGuess.other:
        return 'Host ($ip)';
    }
  }
}

// ── Native Windows Win32 SendARP Bridge ─────────────────────────────────────
typedef _SendArpNative = Uint32 Function(
  Uint32 destIp,
  Uint32 srcIp,
  Pointer<Uint8> pMacAddr,
  Pointer<Uint32> phyAddrLen,
);
typedef _SendArpDart = int Function(
  int destIp,
  int srcIp,
  Pointer<Uint8> pMacAddr,
  Pointer<Uint32> phyAddrLen,
);

class Win32ArpScanner {
  static final Win32ArpScanner _i = Win32ArpScanner._();
  factory Win32ArpScanner() => _i;

  _SendArpDart? _sendArp;
  bool _initialized = false;

  Win32ArpScanner._() {
    if (Platform.isWindows) {
      try {
        final dylib = DynamicLibrary.open('iphlpapi.dll');
        _sendArp = dylib.lookupFunction<_SendArpNative, _SendArpDart>('SendARP');
        _initialized = true;
      } catch (_) {
        _initialized = false;
      }
    }
  }

  bool get isSupported => _initialized && _sendArp != null;

  /// Sends a low-level Layer-2 ARP request to [ip].
  /// Returns the hardware MAC address if the host replied, or null if unreachable.
  String? resolveMac(String ip) {
    if (!_initialized || _sendArp == null) {
      return null;
    }

    final parts = ip.split('.').map((s) => int.tryParse(s) ?? -1).toList();
    if (parts.length != 4 || parts.any((p) => p < 0 || p > 255)) {
      return null;
    }

    // Windows in_addr network byte format: b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    final ipInt = parts[0] | (parts[1] << 8) | (parts[2] << 16) | (parts[3] << 24);

    final macBuf = calloc<Uint8>(8);
    final lenBuf = calloc<Uint32>(1)..value = 6;

    try {
      final res = _sendArp!(ipInt, 0, macBuf, lenBuf);
      if (res == 0 && lenBuf.value == 6) {
        final mac = [
          macBuf[0].toRadixString(16).padLeft(2, '0'),
          macBuf[1].toRadixString(16).padLeft(2, '0'),
          macBuf[2].toRadixString(16).padLeft(2, '0'),
          macBuf[3].toRadixString(16).padLeft(2, '0'),
          macBuf[4].toRadixString(16).padLeft(2, '0'),
          macBuf[5].toRadixString(16).padLeft(2, '0'),
        ].join(':').toUpperCase();
        return mac != '00:00:00:00:00:00' && mac != 'FF:FF:FF:FF:FF:FF' ? mac : null;
      }
    } catch (_) {
      return null;
    } finally {
      calloc.free(macBuf);
      calloc.free(lenBuf);
    }
    return null;
  }
}

class NetworkScannerService {
  static final NetworkScannerService _i = NetworkScannerService._();
  factory NetworkScannerService() => _i;
  NetworkScannerService._();

  final NetworkInfo _info = NetworkInfo();
  final Win32ArpScanner _win32Arp = Win32ArpScanner();

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  static const List<int> defaultProbePorts = [
    80, 443, 22, 445, 139, 8080, 9100, 3389, 53, 8000, 8081, 62078, 5000, 8443, 554, 21, 23
  ];

  static const List<int> fullPortList = [
    21, 22, 23, 25, 53, 80, 110, 135, 139, 143, 443, 445, 554, 993, 995,
    1433, 1900, 3306, 3389, 5000, 5353, 5355, 5432, 5900, 8000, 8080, 8443, 9100
  ];

  // ── Expanded IEEE OUI Vendor Database (100+ Leading Manufacturers) ─────────
  static const Map<String, String> _ouiMap = {
    // Apple
    '00:03:93': 'Apple', '00:05:02': 'Apple', '00:0a:95': 'Apple', '00:10:fa': 'Apple',
    '00:14:51': 'Apple', '00:16:cb': 'Apple', '00:17:f2': 'Apple', '00:19:e3': 'Apple',
    '00:1b:63': 'Apple', '00:1c:b3': 'Apple', '00:1d:4f': 'Apple', '00:1e:52': 'Apple',
    '00:1e:c2': 'Apple', '00:21:e9': 'Apple', '00:22:41': 'Apple', '00:23:12': 'Apple',
    '00:23:32': 'Apple', '00:23:6c': 'Apple', '00:24:36': 'Apple', '00:25:00': 'Apple',
    '00:25:4b': 'Apple', '00:25:bc': 'Apple', '00:26:08': 'Apple', '00:26:4a': 'Apple',
    '00:26:b0': 'Apple', '00:88:65': 'Apple', '3c:07:54': 'Apple', '3c:15:c2': 'Apple',
    '3c:2e:ff': 'Apple', '40:6c:8f': 'Apple', '48:d7:05': 'Apple', '70:3e:ac': 'Apple',
    '88:66:5a': 'Apple', '9c:20:7b': 'Apple', 'a4:83:e7': 'Apple', 'ac:bc:32': 'Apple',
    'b8:e8:56': 'Apple', 'bc:d1:1f': 'Apple', 'c8:69:cd': 'Apple', 'd0:81:7a': 'Apple',
    'dc:a9:04': 'Apple', 'e4:9a:79': 'Apple', 'f0:18:98': 'Apple', 'f4:5c:89': 'Apple',
    '28:cf:e9': 'Apple', '38:ca:84': 'Apple', '44:4c:0c': 'Apple', '60:f4:45': 'Apple',
    '78:4f:43': 'Apple', '80:e6:50': 'Apple', '94:e6:f7': 'Apple', 'a8:66:7f': 'Apple',

    // Samsung
    '00:07:ab': 'Samsung', '00:0d:ae': 'Samsung', '00:12:47': 'Samsung', '00:15:99': 'Samsung',
    '00:16:32': 'Samsung', '00:18:af': 'Samsung', '00:1a:8a': 'Samsung', '00:1d:25': 'Samsung',
    '00:21:19': 'Samsung', '00:23:c2': 'Samsung', '00:24:54': 'Samsung', '00:26:5d': 'Samsung',
    '08:08:c2': 'Samsung', '14:89:fd': 'Samsung', '24:4b:03': 'Samsung', '34:23:ba': 'Samsung',
    '48:44:f7': 'Samsung', '50:01:d9': 'Samsung', '58:c3:8b': 'Samsung', '64:b8:53': 'Samsung',
    '70:2a:d5': 'Samsung', '78:bd:bc': 'Samsung', '84:25:db': 'Samsung', '90:f1:aa': 'Samsung',
    'a8:06:00': 'Samsung', 'b8:57:d8': 'Samsung', 'c4:73:1e': 'Samsung', 'd0:22:be': 'Samsung',
    'dc:71:44': 'Samsung', 'e4:58:b8': 'Samsung', 'f0:72:ea': 'Samsung', 'fc:a1:3e': 'Samsung',

    // Intel
    '00:02:b3': 'Intel', '00:03:47': 'Intel', '00:04:23': 'Intel', '00:0e:0c': 'Intel',
    '00:13:e8': 'Intel', '00:15:00': 'Intel', '00:16:76': 'Intel', '00:18:de': 'Intel',
    '00:19:d1': 'Intel', '00:1b:21': 'Intel', '00:1c:bf': 'Intel', '00:1e:67': 'Intel',
    '00:21:5c': 'Intel', '00:22:fb': 'Intel', '00:23:14': 'Intel', '00:24:d7': 'Intel',
    '00:26:c7': 'Intel', '00:27:0e': 'Intel', '34:13:e8': 'Intel', '3c:fd:fe': 'Intel',
    '48:51:b7': 'Intel', '54:e1:ad': 'Intel', '68:05:ca': 'Intel', '70:cd:60': 'Intel',
    '7c:b0:c2': 'Intel', '80:86:f2': 'Intel', '84:3a:4b': 'Intel', '8c:85:90': 'Intel',
    'a0:36:9f': 'Intel', 'a4:34:d9': 'Intel', 'ac:fd:ce': 'Intel', 'b8:85:84': 'Intel',
    'c8:f7:50': 'Intel', 'd4:5d:64': 'Intel', 'dc:53:60': 'Intel', 'f4:4d:30': 'Intel',

    // HP Inc.
    '00:01:e6': 'HP Inc.', '00:08:02': 'HP Inc.', '00:0e:7f': 'HP Inc.', '00:11:0a': 'HP Inc.',
    '00:16:35': 'HP Inc.', '00:17:08': 'HP Inc.', '00:18:71': 'HP Inc.', '00:1a:4b': 'HP Inc.',
    '00:1e:0b': 'HP Inc.', '00:21:5a': 'HP Inc.', '00:22:64': 'HP Inc.', '00:23:7d': 'HP Inc.',
    '00:24:81': 'HP Inc.', '00:25:b3': 'HP Inc.', '00:26:55': 'HP Inc.', '10:1f:74': 'HP Inc.',
    '10:60:4b': 'HP Inc.', '28:80:23': 'HP Inc.', '30:e1:71': 'HP Inc.', '3c:d9:2b': 'HP Inc.',
    '48:ba:4e': 'HP Inc.', '58:20:b1': 'HP Inc.', '6c:3b:6b': 'HP Inc.', '70:5a:0f': 'HP Inc.',
    '74:46:a0': 'HP Inc.', '80:c1:6e': 'HP Inc.', '9c:8e:99': 'HP Inc.', 'd8:d3:85': 'HP Inc.',

    // Dell
    '00:06:5b': 'Dell', '00:08:74': 'Dell', '00:0b:db': 'Dell', '00:0d:56': 'Dell',
    '00:0f:1f': 'Dell', '00:11:43': 'Dell', '00:12:3f': 'Dell', '00:13:72': 'Dell',
    '00:14:22': 'Dell', '00:16:36': 'Dell', '00:18:8b': 'Dell', '00:19:b9': 'Dell',
    '00:1a:a0': 'Dell', '00:1c:23': 'Dell', '00:1d:09': 'Dell', '00:1e:4f': 'Dell',
    '00:21:70': 'Dell', '00:22:19': 'Dell', '00:24:e8': 'Dell', '00:26:b9': 'Dell',
    '14:18:77': 'Dell', '18:66:da': 'Dell', '24:b6:fd': 'Dell', '34:17:eb': 'Dell',
    '44:a8:42': 'Dell', '54:48:10': 'Dell', '74:86:7a': 'Dell', 'f0:1f:af': 'Dell',
    'f8:db:88': 'Dell', 'ec:f4:bb': 'Dell',

    // Lenovo
    '00:09:2d': 'Lenovo', '00:12:fe': 'Lenovo', '00:16:d3': 'Lenovo', '00:1a:64': 'Lenovo',
    '00:21:86': 'Lenovo', '04:7d:7b': 'Lenovo', '28:6e:d4': 'Lenovo', '54:ee:75': 'Lenovo',
    '60:02:92': 'Lenovo', '80:2b:f9': 'Lenovo', 'a4:c4:94': 'Lenovo', 'd8:bb:c1': 'Lenovo',
    'ec:70:97': 'Lenovo',

    // TP-Link
    '00:27:19': 'TP-Link', '14:cc:20': 'TP-Link', '1c:3b:f3': 'TP-Link', '30:de:4b': 'TP-Link',
    '50:c7:bf': 'TP-Link', '54:e6:fc': 'TP-Link', '60:32:b1': 'TP-Link', '74:05:a5': 'TP-Link',
    '84:16:f9': 'TP-Link', '88:25:93': 'TP-Link', '88:9e:96': 'TP-Link', '90:f6:52': 'TP-Link',
    '98:48:27': 'TP-Link', 'a0:f3:c1': 'TP-Link', 'b0:48:7a': 'TP-Link', 'c0:25:e9': 'TP-Link',
    'c4:6e:1f': 'TP-Link', 'd8:07:b6': 'TP-Link', 'd8:47:32': 'TP-Link', 'e4:c3:2a': 'TP-Link',
    'ec:08:6b': 'TP-Link', 'f4:f2:6d': 'TP-Link', '0c:80:63': 'TP-Link',

    // Ubiquiti Networks
    '00:15:6d': 'Ubiquiti', '00:27:22': 'Ubiquiti', '04:18:d6': 'Ubiquiti', '18:e8:29': 'Ubiquiti',
    '24:a4:3c': 'Ubiquiti', '44:d9:e7': 'Ubiquiti', '68:72:51': 'Ubiquiti', '70:a7:41': 'Ubiquiti',
    '74:83:c2': 'Ubiquiti', '78:8a:20': 'Ubiquiti', '80:2a:a8': 'Ubiquiti', 'b4:fb:e4': 'Ubiquiti',
    'dc:9f:db': 'Ubiquiti', 'f0:9f:c2': 'Ubiquiti',

    // MikroTik
    '00:0c:42': 'MikroTik', '2c:c8:1b': 'MikroTik', '48:8f:5a': 'MikroTik', '64:d1:54': 'MikroTik',
    '74:4d:28': 'MikroTik', 'b8:69:f4': 'MikroTik', 'c4:ad:34': 'MikroTik', 'cc:2d:e0': 'MikroTik',
    'dc:2c:6e': 'MikroTik',

    // Cisco Systems
    '00:00:0c': 'Cisco', '00:01:42': 'Cisco', '00:01:64': 'Cisco', '00:01:c7': 'Cisco',
    '00:02:16': 'Cisco', '00:02:4b': 'Cisco', '00:03:e3': 'Cisco', '00:04:4d': 'Cisco',
    '00:05:31': 'Cisco', '00:06:52': 'Cisco', '00:07:0d': 'Cisco', '00:08:20': 'Cisco',
    '00:0b:fc': 'Cisco', '00:11:20': 'Cisco', '00:14:1c': 'Cisco', '00:17:94': 'Cisco',
    '00:1a:2f': 'Cisco', '00:1d:a1': 'Cisco', '00:21:55': 'Cisco', '00:24:14': 'Cisco',

    // Espressif IoT (ESP8266 / ESP32)
    '18:fe:34': 'Espressif IoT', '24:0a:c4': 'Espressif IoT', '24:6f:28': 'Espressif IoT',
    '24:b2:de': 'Espressif IoT', '2c:f4:32': 'Espressif IoT', '30:ae:a4': 'Espressif IoT',
    '3c:71:bf': 'Espressif IoT', '48:3f:da': 'Espressif IoT', '4c:11:ae': 'Espressif IoT',
    '54:5a:a6': 'Espressif IoT', '84:0d:8e': 'Espressif IoT', '84:f3:eb': 'Espressif IoT',
    'a4:e5:7c': 'Espressif IoT', 'ac:d0:74': 'Espressif IoT', 'bc:dd:c2': 'Espressif IoT',

    // Raspberry Pi Foundation
    'b8:27:eb': 'Raspberry Pi', 'dc:a6:32': 'Raspberry Pi', 'e4:5f:01': 'Raspberry Pi',
    '28:cd:c1': 'Raspberry Pi',

    // Google / Alphabet
    '00:1a:11': 'Google', '3c:5a:37': 'Google', '40:b4:cd': 'Google', '48:d6:d5': 'Google',
    '54:60:09': 'Google', '74:75:48': 'Google', '94:eb:2c': 'Google', 'a4:77:33': 'Google',
    'd8:6c:63': 'Google', 'f4:f5:db': 'Google',

    // Xiaomi
    '00:9e:c8': 'Xiaomi', '04:cf:8c': 'Xiaomi', '10:2a:b3': 'Xiaomi', '18:59:36': 'Xiaomi',
    '28:6c:07': 'Xiaomi', '34:80:b3': 'Xiaomi', '50:64:2b': 'Xiaomi', '58:44:98': 'Xiaomi',
    '64:09:80': 'Xiaomi', '74:23:44': 'Xiaomi', '7c:49:eb': 'Xiaomi', '8c:be:be': 'Xiaomi',

    // Microsoft
    '00:03:ff': 'Microsoft', '00:0d:3a': 'Microsoft', '00:12:5a': 'Microsoft', '00:15:5d': 'Microsoft (Hyper-V)',
    '00:17:fa': 'Microsoft', '00:1d:d8': 'Microsoft', '00:22:48': 'Microsoft', '28:18:78': 'Microsoft Surface',
    'dc:98:40': 'Microsoft',

    // Printers (Brother, Canon, Epson, Xerox)
    '00:80:77': 'Brother', '00:1b:a9': 'Brother', '30:05:5c': 'Brother', '54:13:79': 'Brother',
    '00:00:85': 'Canon', '00:1e:8f': 'Canon', '08:00:46': 'Canon', '70:85:c2': 'Canon',
    '00:00:48': 'Epson', '00:26:ab': 'Epson', '44:d2:44': 'Epson', '64:eb:8c': 'Epson',
    '00:00:aa': 'Xerox', '00:00:07': 'Xerox', '9c:93:4e': 'Xerox',

    // D-Link & Netgear
    '00:05:5d': 'D-Link', '00:0d:88': 'D-Link', '00:11:95': 'D-Link', '14:d6:4d': 'D-Link',
    '00:09:5b': 'Netgear', '00:0f:b5': 'Netgear', '00:14:6c': 'Netgear', '20:4e:7f': 'Netgear',

    // Asus & Realtek
    '00:0c:6e': 'ASUS', '00:18:f3': 'ASUS', '04:d9:f5': 'ASUS', '10:7b:44': 'ASUS',
    '00:07:0e': 'Realtek', '00:e0:4c': 'Realtek', '52:54:00': 'QEMU / KVM Virtual NIC',

    // Synology & QNAP
    '00:11:32': 'Synology NAS', '90:09:d0': 'Synology NAS', '00:08:9b': 'QNAP NAS', '24:5e:be': 'QNAP NAS',

    // IoT / Smart Media (Sony, LG, Roku, Sonos, Amazon)
    '00:01:4a': 'Sony', '00:04:1f': 'Sony', 'fc:f1:52': 'Sony PlayStation',
    '00:05:c9': 'LG Electronics', 'a8:23:fe': 'LG Electronics',
    '00:0d:4b': 'Roku', 'ac:3a:7a': 'Roku', 'b8:3e:59': 'Roku',
    '00:0e:58': 'Sonos', '94:9f:3e': 'Sonos',
    '00:fc:8b': 'Amazon Echo/Fire', '44:65:0d': 'Amazon Echo/Fire', 'fc:a6:67': 'Amazon Echo/Fire',
  };

  /// Lookup manufacturer from MAC address
  static String? lookupVendor(String? mac) {
    if (mac == null || mac.length < 8) return null;
    final clean = mac.replaceAll('-', ':').toLowerCase();
    final prefix = clean.substring(0, 8);
    return _ouiMap[prefix];
  }

  Future<String?> getWifiIp() async {
    try {
      final ip = await _info.getWifiIP();
      if (ip != null && ip.isNotEmpty && ip != '0.0.0.0') {
        return ip;
      }
    } catch (_) {}

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> getGatewayIp() async {
    try {
      final gw = await _info.getWifiGatewayIP();
      if (gw != null && gw.isNotEmpty && gw != '0.0.0.0') {
        return gw;
      }
    } catch (_) {}
    return null;
  }

  bool _arpUnavailable = false;

  /// Read the OS ARP table dynamically.
  Future<Map<String, String>> getArpTableFromOs() async {
    if (_arpUnavailable) return const {};
    final arpTable = <String, String>{};

    // 1. Linux & Android: Read /proc/net/arp directly
    try {
      final arpProc = File('/proc/net/arp');
      if (await arpProc.exists()) {
        final lines = await arpProc.readAsLines();
        for (final line in lines.skip(1)) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final ip = parts[0];
            final flags = parts[2];
            final mac = parts[3].toLowerCase();
            if (flags != '0x0' && mac != '00:00:00:00:00:00' && mac.contains(':')) {
              arpTable[ip] = mac.toUpperCase();
            }
          }
        }
        if (arpTable.isNotEmpty) {
          return arpTable;
        }
      }
    } catch (_) {}

    // 2. Android: Try 'ip neigh' or 'ip neighbor'
    try {
      final res = await Process.run('ip', ['neigh']).timeout(const Duration(milliseconds: 600));
      if (res.exitCode == 0) {
        final text = res.stdout.toString();
        final regex = RegExp(r'(\d+\.\d+\.\d+\.\d+)\s+.*lladdr\s+([0-9a-fA-F[:-]{11,17})');
        for (final match in regex.allMatches(text)) {
          final ip = match.group(1);
          final mac = match.group(2)?.replaceAll('-', ':').toUpperCase();
          if (ip != null && mac != null && !mac.startsWith('01:00:5E')) {
            arpTable[ip] = mac;
          }
        }
        if (arpTable.isNotEmpty) {
          return arpTable;
        }
      }
    } catch (_) {}

    // 3. Fallback: 'arp -a' or 'arp -an'
    try {
      final res = await Process.run('arp', ['-a']).timeout(const Duration(milliseconds: 800));
      if (res.exitCode == 0) {
        final text = res.stdout.toString();
        final regex = RegExp(r'(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F[:-]{11,17})');
        for (final match in regex.allMatches(text)) {
          final ip = match.group(1);
          final mac = match.group(2)?.replaceAll('-', ':').toUpperCase();
          if (ip != null && mac != null && mac != 'FF:FF:FF:FF:FF:FF' && !mac.startsWith('01:00:5E')) {
            arpTable[ip] = mac;
          }
        }
      }
    } catch (_) {}

    if (arpTable.isEmpty && !Platform.isWindows) {
      _arpUnavailable = true;
    }

    return arpTable;
  }

  /// Sends a fast ICMP ping packet via OS process to awaken the remote host and populate the OS ARP table.
  Future<bool> sendIcmpPing(String ip, {int timeoutMs = 500}) async {
    Process? process;
    try {
      final isWin = Platform.isWindows;
      final args = isWin
          ? ['-n', '1', '-w', timeoutMs.toString(), ip]
          : ['-c', '1', '-W', (timeoutMs / 1000).ceil().toString(), ip];
      process = await Process.start('ping', args);
      process.stdout.drain<void>().catchError((_) {});
      process.stderr.drain<void>().catchError((_) {});
      final exitCode = await process.exitCode.timeout(
        Duration(milliseconds: timeoutMs + 250),
      );
      return exitCode == 0;
    } catch (_) {
      try {
        process?.kill();
      } catch (_) {}
      return false;
    }
  }

  /// Query NetBIOS node status on UDP 137 to obtain machine name, workgroup, and user.
  Future<Map<String, String>?> resolveNetbiosDetails(String ip, {int timeoutMs = 400}) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final packet = <int>[
        0x80, 0x94, // Transaction ID
        0x00, 0x00, // Query
        0x00, 0x01, // Questions: 1
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x20, // Name length: 32 bytes
        0x43, 0x4B, // 'CK'
        0x43, 0x41, 0x43, 0x41, 0x43, 0x41, 0x43, 0x41,
        0x43, 0x41, 0x43, 0x41, 0x43, 0x41, 0x43, 0x41,
        0x43, 0x41, 0x43, 0x41, 0x43, 0x41, 0x43, 0x41,
        0x43, 0x41, 0x43, 0x41, 0x43, 0x41,
        0x00, // Null byte
        0x00, 0x21, // Type: NBSTAT
        0x00, 0x01, // Class: IN
      ];

      socket.send(packet, InternetAddress(ip), 137);

      final completer = Completer<Map<String, String>?>();
      final timer = Timer(Duration(milliseconds: timeoutMs), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null && dg.data.length > 56) {
            try {
              final data = dg.data;
              final numNames = data[56];
              String name = '';
              String group = '';
              String user = '';
              String? unitMac;

              for (int i = 0; i < numNames && 57 + (i * 18) + 18 <= data.length; i++) {
                final offset = 57 + (i * 18);
                final entryName = String.fromCharCodes(data.sublist(offset, offset + 15)).trim();
                final typeCode = data[offset + 15];
                final flags = (data[offset + 16] << 8) | data[offset + 17];
                final isGroup = (flags & 0x8000) != 0;

                if (isGroup && group.isEmpty && entryName.isNotEmpty) {
                  group = entryName;
                } else if (!isGroup) {
                  if (typeCode == 0x00 && name.isEmpty && entryName.isNotEmpty) {
                    name = entryName;
                  } else if (typeCode == 0x03 && user.isEmpty && entryName.isNotEmpty) {
                    user = entryName;
                  } else if (name.isEmpty && entryName.isNotEmpty) {
                    name = entryName;
                  }
                }
              }

              // Unit ID (MAC address) is stored at 57 + (numNames * 18)
              final macOffset = 57 + (numNames * 18);
              if (macOffset + 6 <= data.length) {
                final macBytes = data.sublist(macOffset, macOffset + 6);
                unitMac = macBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
                if (unitMac == '00:00:00:00:00:00') {
                  unitMac = null;
                }
              }

              if (!completer.isCompleted) {
                timer.cancel();
                completer.complete({
                  'name': name,
                  'group': group,
                  'user': user,
                  if (unitMac != null) 'mac': unitMac,
                });
              }
            } catch (_) {}
          }
        }
      });

      final res = await completer.future;
      timer.cancel();
      return res;
    } catch (_) {
      return null;
    } finally {
      socket?.close();
    }
  }

  /// Listen for SSDP / UPnP M-SEARCH responses and extract friendlyName & manufacturer
  Future<Map<String, Map<String, String>>> discoverSsdpDetails({Duration timeout = const Duration(milliseconds: 1400)}) async {
    final results = <String, Map<String, String>>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      const mSearch =
          'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 1\r\n'
          'ST: ssdp:all\r\n\r\n';

      final bytes = utf8.encode(mSearch);
      socket.send(bytes, InternetAddress('239.255.255.250'), 1900);

      final locationMap = <String, String>{};

      final sub = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null) {
            final text = utf8.decode(dg.data, allowMalformed: true);
            final ip = dg.address.address;
            final match = RegExp(r'LOCATION:\s*(http://[^\r\n]+)', caseSensitive: false).firstMatch(text);
            if (match != null && match.group(1) != null) {
              locationMap[ip] = match.group(1)!.trim();
            }
          }
        }
      });

      await Future.delayed(timeout);
      await sub.cancel();

      // Fetch descriptor XMLs concurrently to parse <friendlyName> and <manufacturer>
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
      final futures = locationMap.entries.take(20).map((entry) async {
        try {
          final req = await client.getUrl(Uri.parse(entry.value));
          final resp = await req.close().timeout(const Duration(milliseconds: 800));
          final body = await resp.transform(const Utf8Decoder(allowMalformed: true)).take(2).join();
          final fnMatch = RegExp(r'<friendlyName>([^<]+)</friendlyName>', caseSensitive: false).firstMatch(body);
          final manMatch = RegExp(r'<manufacturer>([^<]+)</manufacturer>', caseSensitive: false).firstMatch(body);
          final modelMatch = RegExp(r'<modelName>([^<]+)</modelName>', caseSensitive: false).firstMatch(body);

          final details = <String, String>{};
          if (fnMatch != null && fnMatch.group(1) != null) {
            details['name'] = fnMatch.group(1)!.trim();
          }
          if (manMatch != null && manMatch.group(1) != null) {
            details['manufacturer'] = manMatch.group(1)!.trim();
          }
          if (modelMatch != null && modelMatch.group(1) != null) {
            details['model'] = modelMatch.group(1)!.trim();
          }

          if (details.isNotEmpty) {
            results[entry.key] = details;
          }
        } catch (_) {}
      });
      await Future.wait(futures);
      client.close();
    } catch (_) {} finally {
      socket?.close();
    }
    return results;
  }

  /// Listen for mDNS / Bonjour PTR & SRV responses targeting iOS, Android, Google Cast, and Printers
  Future<Map<String, String>> discoverMdnsNames({Duration timeout = const Duration(milliseconds: 1500)}) async {
    final names = <String, String>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final services = [
        '_airplay._tcp.local',
        '_googlecast._tcp.local',
        '_companion-link._tcp.local',
        '_apple-mobdev2._tcp.local',
        '_raop._tcp.local',
        '_ipp._tcp.local',
        '_printer._tcp.local',
        '_http._tcp.local',
        '_workstation._tcp.local',
      ];

      for (final s in services) {
        final query = _buildDnsPtrQuery(s);
        socket.send(query, InternetAddress('224.0.0.251'), 5353);
      }

      final sub = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null) {
            final senderIp = dg.address.address;
            final extracted = _parseMdnsFriendlyName(dg.data);
            if (extracted != null && extracted.isNotEmpty) {
              names[senderIp] = extracted;
            }
          }
        }
      });

      await Future.delayed(timeout);
      await sub.cancel();
    } catch (_) {} finally {
      socket?.close();
    }
    return names;
  }

  List<int> _buildDnsPtrQuery(String fqdn) {
    final bytes = <int>[
      0x00, 0x00, // ID
      0x00, 0x00, // Flags: Standard Query
      0x00, 0x01, // Questions: 1
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ];
    for (final label in fqdn.split('.')) {
      if (label.isEmpty) continue;
      bytes.add(label.length);
      bytes.addAll(utf8.encode(label));
    }
    bytes.add(0x00); // End of QNAME
    bytes.addAll([0x00, 0x0C]); // Type: PTR (12)
    bytes.addAll([0x00, 0x01]); // Class: IN (1)
    return bytes;
  }

  String? _parseMdnsFriendlyName(List<int> data) {
    try {
      final asciiStr = String.fromCharCodes(data.where((b) => b >= 32 && b <= 126));
      final match = RegExp(
        r'([A-Za-z0-9\s\-_’\x27]{3,35})\._(companion-link|airplay|googlecast|apple-mobdev2|raop|ipp|printer|http|workstation)',
        caseSensitive: false,
      ).firstMatch(asciiStr);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    } catch (_) {}
    return null;
  }

  /// Resolve hostname via Reverse DNS
  Future<String?> resolveDnsName(String ip) async {
    try {
      final lookup = await InternetAddress(ip).reverse().timeout(
        const Duration(milliseconds: 300),
      );
      final host = lookup.host.trim();
      if (host.isNotEmpty && host != ip) {
        return host.endsWith('.') ? host.substring(0, host.length - 1) : host;
      }
    } catch (_) {}
    return null;
  }

  /// Send LLMNR query (UDP 5355) for Windows Link-Local Name Resolution
  Future<String?> resolveLlmnrName(String ip, {int timeoutMs = 350}) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final query = <int>[
        0x12, 0x34, // Transaction ID
        0x00, 0x00, // Standard query
        0x00, 0x01, // 1 question
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ];

      // Form reverse in-addr.arpa name
      final parts = ip.split('.').reversed.toList();
      for (final p in parts) {
        query.add(p.length);
        query.addAll(utf8.encode(p));
      }
      query.addAll([7, 105, 110, 45, 97, 100, 100, 114, 4, 97, 114, 112, 97, 0]);
      query.addAll([0x00, 0x0C, 0x00, 0x01]); // PTR, IN

      socket.send(query, InternetAddress(ip), 5355);

      final completer = Completer<String?>();
      final timer = Timer(Duration(milliseconds: timeoutMs), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null && dg.data.length > 12) {
            final ascii = String.fromCharCodes(dg.data.where((b) => b >= 32 && b <= 126));
            final match = RegExp(r'([A-Za-z0-9\-]{2,30})\.(local|arpa)', caseSensitive: false).firstMatch(ascii);
            if (match != null && match.group(1) != null && !completer.isCompleted) {
              timer.cancel();
              completer.complete(match.group(1)!.trim());
            }
          }
        }
      });

      final res = await completer.future;
      timer.cancel();
      return res;
    } catch (_) {
      return null;
    } finally {
      socket?.close();
    }
  }

  /// Send UDP wake-up and ARP stimulation packets to [ip]
  Future<void> sendUdpStimulation(String ip) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final dummy = [0x00, 0x01, 0x02];
      // Ports: 137 (NetBIOS), 5353 (mDNS), 1900 (SSDP), 7 (Echo)
      socket.send(dummy, InternetAddress(ip), 137);
      socket.send(dummy, InternetAddress(ip), 5353);
      socket.send(dummy, InternetAddress(ip), 1900);
      socket.send(dummy, InternetAddress(ip), 7);
    } catch (_) {
    } finally {
      socket?.close();
    }
  }

  /// Broadcast awakening packets to the local subnet
  Future<void> sendSubnetBroadcastWakeup([String broadcastIp = '255.255.255.255']) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final dummy = [0x00, 0x00];
      socket.send(dummy, InternetAddress(broadcastIp), 5353);
      socket.send(dummy, InternetAddress(broadcastIp), 1900);
    } catch (_) {
    } finally {
      socket?.close();
    }
  }

  /// Fast multi-port concurrent probe detecting open ports and TCP RST rejections
  Future<ProbePortsResult> _probeOpenPorts(String ip, List<int> ports, int timeoutMs) async {
    final open = <int>[];
    bool refused = false;
    final futures = ports.map((port) async {
      try {
        final s = await Socket.connect(
          ip,
          port,
          timeout: Duration(milliseconds: timeoutMs),
        );
        open.add(port);
        s.destroy();
      } on SocketException catch (e) {
        final code = e.osError?.errorCode;
        if (code == 111 || code == 10061 || code == 61 || e.message.toLowerCase().contains('refused')) {
          refused = true;
        }
      } catch (_) {}
    });
    await Future.wait(futures);
    return ProbePortsResult(openPorts: open, connectionRefused: refused);
  }

  /// Grab service banner (e.g. SSH version string or FTP banner)
  Future<String?> _grabBanner(String ip, int port) async {
    try {
      final s = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 300));
      final completer = Completer<String?>();
      final timer = Timer(const Duration(milliseconds: 350), () {
        if (!completer.isCompleted) completer.complete(null);
      });
      s.listen((data) {
        if (!completer.isCompleted) {
          final text = String.fromCharCodes(data).trim();
          timer.cancel();
          completer.complete(text.split('\n').first.trim());
        }
      }, onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      });
      final res = await completer.future;
      timer.cancel();
      s.destroy();
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Fetch HTTP Web Title & Server Header
  Future<Map<String, String>> _fetchHttpDetails(String ip, int port) async {
    final details = <String, String>{};
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 450)
      ..badCertificateCallback = (_, __, ___) => true;
    try {
      final scheme = (port == 443 || port == 8443) ? 'https' : 'http';
      final request = await client.getUrl(Uri.parse('$scheme://$ip:$port/'));
      final response = await request.close().timeout(const Duration(milliseconds: 650));

      final serverHeader = response.headers.value('server');
      if (serverHeader != null && serverHeader.isNotEmpty) {
        details['server'] = serverHeader.trim();
      }

      final body = await response.transform(const Utf8Decoder(allowMalformed: true)).take(1).join();

      final match = RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(body);
      if (match != null && match.group(1) != null) {
        details['title'] = match.group(1)!.trim();
      }
    } catch (_) {} finally {
      client.close(force: true);
    }
    return details;
  }

  /// Send Wake-on-LAN magic packet (6x 0xFF followed by 16x MAC address)
  static Future<bool> sendWakeOnLan(String macAddress, {String broadcastIp = '255.255.255.255', int port = 9}) async {
    try {
      final cleanMac = macAddress.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
      if (cleanMac.length != 12) return false;

      final macBytes = <int>[];
      for (int i = 0; i < 12; i += 2) {
        macBytes.add(int.parse(cleanMac.substring(i, i + 2), radix: 16));
      }

      final packet = <int>[...List.filled(6, 0xFF)];
      for (int i = 0; i < 16; i++) {
        packet.addAll(macBytes);
      }

      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(packet, InternetAddress(broadcastIp), port);
      // Also send to port 7 (echo)
      socket.send(packet, InternetAddress(broadcastIp), 7);
      socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deep scan across full port list for a specific host (batched concurrency)
  Future<List<int>> scanHostPorts(
    String ip, {
    List<int> ports = fullPortList,
    int timeoutMs = 350,
    void Function(int current, int total)? onProgress,
  }) async {
    final open = <int>[];
    int scanned = 0;
    final total = ports.length;
    const batchSize = 8;

    for (int i = 0; i < total; i += batchSize) {
      final batch = ports.sublist(i, (i + batchSize) > total ? total : (i + batchSize));
      await Future.wait(batch.map((port) async {
        try {
          final s = await Socket.connect(ip, port, timeout: Duration(milliseconds: timeoutMs));
          open.add(port);
          s.destroy();
        } catch (_) {}
        scanned++;
        onProgress?.call(scanned, total);
      }));
    }
    open.sort();
    return open;
  }

  /// Generate list of IPv4 strings from either CIDR or Start-End range
  static List<String> parseTargetIps(String input, {String fallbackSubnet = '192.168.1'}) {
    final text = input.trim();
    if (text.isEmpty) {
      return List.generate(254, (i) => '$fallbackSubnet.${i + 1}');
    }

    // Format 1: CIDR (e.g. 192.168.1.0/24 or 10.0.0.1/28)
    if (text.contains('/')) {
      final parts = text.split('/');
      final ip = parts[0];
      final prefix = int.tryParse(parts[1]) ?? 24;
      return _ipsFromCidr(ip, prefix);
    }

    // Format 2: Range (e.g. 192.168.1.1 - 192.168.1.50 or 192.168.1.1-50)
    if (text.contains('-')) {
      final parts = text.split('-');
      final startPart = parts[0].trim();
      final endPart = parts[1].trim();

      if (startPart.contains('.') && !endPart.contains('.')) {
        final sub = startPart.substring(0, startPart.lastIndexOf('.'));
        final startNum = int.tryParse(startPart.split('.').last) ?? 1;
        final endNum = int.tryParse(endPart) ?? 254;
        if (startNum <= endNum && endNum <= 254) {
          return List.generate(endNum - startNum + 1, (i) => '$sub.${startNum + i}');
        }
      } else if (startPart.contains('.') && endPart.contains('.')) {
        final startInt = _ipToInt(startPart);
        final endInt = _ipToInt(endPart);
        if (startInt != null && endInt != null && startInt <= endInt && (endInt - startInt) <= 1024) {
          final list = <String>[];
          for (int ip = startInt; ip <= endInt; ip++) {
            list.add(_intToIp(ip));
          }
          return list;
        }
      }
    }

    // Format 3: Subnet base (e.g. 192.168.1)
    if (text.split('.').length == 3) {
      return List.generate(254, (i) => '$text.${i + 1}');
    }

    // Format 4: Single IP
    if (text.split('.').length == 4) {
      return [text];
    }

    return List.generate(254, (i) => '$fallbackSubnet.${i + 1}');
  }

  static List<String> _ipsFromCidr(String ipStr, int prefix) {
    final ipParts = ipStr.split('.');
    if (ipParts.length != 4) return [];
    final ipInt = _ipToInt(ipStr);
    if (ipInt == null) return [];

    final safePrefix = prefix.clamp(16, 32);
    final maskInt = safePrefix == 0 ? 0 : (~0 << (32 - safePrefix)) & 0xFFFFFFFF;
    final netInt = ipInt & maskInt;
    final bcastInt = netInt | (~maskInt & 0xFFFFFFFF);

    final total = bcastInt - netInt + 1;
    if (total > 1024) {
      return List.generate(254, (i) => _intToIp(netInt + i + 1));
    }

    final list = <String>[];
    for (int i = 1; i < total - 1; i++) {
      list.add(_intToIp(netInt + i));
    }
    return list.isEmpty ? [ipStr] : list;
  }

  static int? _ipToInt(String ip) {
    final p = ip.split('.').map((s) => int.tryParse(s) ?? -1).toList();
    if (p.length != 4 || p.any((n) => n < 0 || n > 255)) return null;
    return (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
  }

  static String _intToIp(int val) {
    return '${(val >> 24) & 0xFF}.${(val >> 16) & 0xFF}.${(val >> 8) & 0xFF}.${val & 0xFF}';
  }

  /// Real-time live streaming sweep across designated targets with options.
  Stream<DiscoveredHost> sweepTargets({
    required List<String> targetIps,
    String? localIp,
    String? gatewayIp,
    ScanOptions options = const ScanOptions(),
    Function(int scanned, int total, String phase)? onProgress,
  }) {
    _isScanning = true;
    final controller = StreamController<DiscoveredHost>();
    final total = targetIps.length;

    () async {
      onProgress?.call(0, total, 'Initializing Advanced Discovery Pipeline…');

      // Send initial broadcast wake-up packet to stimulate local subnet
      unawaited(sendSubnetBroadcastWakeup());

      // Phase 1: Pre-populate mDNS, SSDP, and initial ARP cache in background
      final mdnsFuture = options.enableMdns ? discoverMdnsNames() : Future.value(<String, String>{});
      final ssdpFuture = options.enableSsdp ? discoverSsdpDetails() : Future.value(<String, Map<String, String>>{});
      final arpInitialFuture = getArpTableFromOs();

      final results = await Future.wait([mdnsFuture, ssdpFuture, arpInitialFuture]);
      final mdnsMap = results[0] as Map<String, String>;
      final ssdpMap = results[1] as Map<String, Map<String, String>>;
      final arpCache = results[2] as Map<String, String>;

      final discoveredIps = <String>{};

      // Probe Gateway immediately if present
      if (gatewayIp != null && targetIps.contains(gatewayIp)) {
        final gwHost = await _probeSingleHost(
          gatewayIp,
          arpCache: arpCache,
          mdnsMap: mdnsMap,
          ssdpMap: ssdpMap,
          isGateway: true,
          options: options,
        );
        if (gwHost != null) {
          discoveredIps.add(gatewayIp);
          controller.add(gwHost);
        }
      }

      // Probe Local IP immediately if present
      if (localIp != null && targetIps.contains(localIp) && !discoveredIps.contains(localIp)) {
        final localHost = await _probeSingleHost(
          localIp,
          arpCache: arpCache,
          mdnsMap: mdnsMap,
          ssdpMap: ssdpMap,
          isLocal: true,
          options: options,
        );
        if (localHost != null) {
          discoveredIps.add(localIp);
          controller.add(localHost);
        }
      }

      int scanned = 0;
      final runningTasks = <Future<void>>{};
      final maxConcurrent = options.concurrency.clamp(4, 128);

      onProgress?.call(scanned, total, 'Sweeping Target Range…');

      for (int i = 0; i < total; i++) {
        if (!_isScanning) {
          break;
        }
        final targetIp = targetIps[i];

        late final Future<void> task;
        task = () async {
          if (!_isScanning) return;
          if (!discoveredIps.contains(targetIp)) {
            final host = await _probeSingleHost(
              targetIp,
              arpCache: arpCache,
              mdnsMap: mdnsMap,
              ssdpMap: ssdpMap,
              options: options,
            );
            if (host != null && !discoveredIps.contains(targetIp)) {
              discoveredIps.add(targetIp);
              controller.add(host);
            }
          }
          scanned++;
          onProgress?.call(scanned, total, 'Sweeping $targetIp ($scanned/$total)');
        }().whenComplete(() => runningTasks.remove(task));

        runningTasks.add(task);

        if (runningTasks.length >= maxConcurrent) {
          await Future.any(runningTasks);
        }
      }

      if (runningTasks.isNotEmpty) {
        await Future.wait(runningTasks);
      }

      // Phase 2: Aggressive Second Pass for quiet / deep-sleep / firewalled devices
      if (options.enableDualPass && _isScanning) {
        final missingIps = targetIps.where((ip) => !discoveredIps.contains(ip)).toList();
        if (missingIps.isNotEmpty) {
          onProgress?.call(scanned, total, 'Deep discovery pass for ${missingIps.length} quiet hosts…');

          // Refresh full dynamic ARP table from OS
          final pass2Arp = await getArpTableFromOs();

          final pass2Options = options.copyWith(
            socketTimeoutMs: 600,
            concurrency: 40,
          );

          final pass2Tasks = <Future<void>>{};
          final pass2MaxConcurrent = pass2Options.concurrency.clamp(4, 128);

          for (final missingIp in missingIps) {
            if (!_isScanning) break;

            late final Future<void> task;
            task = () async {
              if (!_isScanning) return;
              final host = await _probeSingleHost(
                missingIp,
                arpCache: pass2Arp,
                mdnsMap: mdnsMap,
                ssdpMap: ssdpMap,
                options: pass2Options,
              );
              if (host != null && !discoveredIps.contains(missingIp)) {
                discoveredIps.add(missingIp);
                controller.add(host);
              }
            }().whenComplete(() => pass2Tasks.remove(task));

            pass2Tasks.add(task);

            if (pass2Tasks.length >= pass2MaxConcurrent) {
              await Future.any(pass2Tasks);
            }
          }

          if (pass2Tasks.isNotEmpty) {
            await Future.wait(pass2Tasks);
          }
        }
      }

      _isScanning = false;
      await controller.close();
    }();

    return controller.stream;
  }

  void stopScan() {
    _isScanning = false;
  }

  /// Advanced multi-tier host probing modeled after Advanced IP Scanner:
  /// 1. Layer-2 ARP check (Win32 SendARP on Windows / ARP cache on Android)
  /// 2. UDP wake-up and ARP stimulation
  /// 3. ICMP Echo Ping
  /// 4. NetBIOS NBSTAT query (UDP 137)
  /// 5. mDNS / SSDP identity matching
  /// 6. Fast Multi-Port TCP SYN & TCP RST (Refused) probe
  /// 7. Dynamic OS Kernel ARP table harvesting
  Future<DiscoveredHost?> _probeSingleHost(
    String ip, {
    Map<String, String>? arpCache,
    Map<String, String>? mdnsMap,
    Map<String, Map<String, String>>? ssdpMap,
    bool isGateway = false,
    bool isLocal = false,
    ScanOptions options = const ScanOptions(),
  }) async {
    final sw = Stopwatch()..start();

    String? macAddress = arpCache?[ip];
    bool isAlive = isGateway || isLocal;
    String discoveryMethod = isGateway ? 'Gateway' : (isLocal ? 'Local Host' : 'Unknown');

    // ── Tier 1: Windows Native Win32 SendARP ──────────────────────────────────
    if (_win32Arp.isSupported) {
      final winMac = _win32Arp.resolveMac(ip);
      if (winMac != null) {
        macAddress = winMac;
        isAlive = true;
        discoveryMethod = 'Win32 ARP';
      }
    }

    // ── Tier 1b: Existing Layer-2 ARP Cache Match ────────────────────────────
    if (!isAlive && macAddress != null && macAddress.isNotEmpty) {
      isAlive = true;
      discoveryMethod = 'Layer-2 ARP';
    }

    // Stimulate host ARP resolution via UDP packet
    await sendUdpStimulation(ip);

    // ── Tier 2: ICMP Ping Probe ───────────────────────────────────────────────
    if (!isAlive && options.enableIcmpPing) {
      final pingOk = await sendIcmpPing(ip, timeoutMs: options.socketTimeoutMs);
      if (pingOk) {
        isAlive = true;
        discoveryMethod = 'ICMP Echo';
      }
    }

    // ── Tier 3: NetBIOS NBSTAT Discovery (UDP 137) ─────────────────────────────
    Map<String, String>? nbDetails;
    if (options.enableNetbios) {
      nbDetails = await resolveNetbiosDetails(ip, timeoutMs: options.socketTimeoutMs);
      if (nbDetails != null && (nbDetails['name']?.isNotEmpty == true || nbDetails['group']?.isNotEmpty == true)) {
        isAlive = true;
        discoveryMethod = 'NetBIOS NBSTAT';
        if (macAddress == null && nbDetails['mac'] != null) {
          macAddress = nbDetails['mac'];
        }
      }
    }

    // ── Tier 4: Fast Multi-Port TCP SYN & RST Probe ───────────────────────────
    final portsResult = await _probeOpenPorts(ip, options.portsToProbe, options.socketTimeoutMs);
    final openPorts = portsResult.openPorts;
    if (openPorts.isNotEmpty) {
      isAlive = true;
      if (discoveryMethod == 'Unknown') {
        discoveryMethod = 'TCP Probe';
      }
    } else if (portsResult.connectionRefused) {
      isAlive = true;
      if (discoveryMethod == 'Unknown') {
        discoveryMethod = 'TCP RST';
      }
    }

    // ── Tier 5: Check mDNS & SSDP Tables ──────────────────────────────────────
    final mdnsName = mdnsMap?[ip];
    final ssdpInfo = ssdpMap?[ip];
    if (mdnsName != null || ssdpInfo != null) {
      isAlive = true;
      if (discoveryMethod == 'Unknown') {
        discoveryMethod = mdnsName != null ? 'mDNS / Bonjour' : 'SSDP UPnP';
      }
    }

    // ── Tier 6: Check OS ARP Table (post stimulation) ─────────────────────────
    if (!isAlive) {
      final freshMac = arpCache?[ip];
      if (freshMac != null && freshMac.isNotEmpty) {
        macAddress = freshMac;
        isAlive = true;
        discoveryMethod = 'Layer-2 ARP';
      }
    }

    // If still not verified alive, host is offline / inactive
    if (!isAlive) {
      return null;
    }

    // Refresh ARP table entry from cache if still missing
    macAddress ??= arpCache?[ip];

    sw.stop();

    // ── Stage 2: Deep Identity & Hostname Resolution ─────────────────────────
    String hostname = '';
    String? netbiosGroup = nbDetails?['group'];
    String? netbiosUser = nbDetails?['user'];
    String? vendor = lookupVendor(macAddress);

    if (ssdpInfo != null && ssdpInfo['manufacturer'] != null && (vendor == null || vendor.isEmpty)) {
      vendor = ssdpInfo['manufacturer'];
    }

    if (nbDetails != null && nbDetails['name']!.isNotEmpty) {
      hostname = nbDetails['name']!;
    } else if (mdnsName != null && mdnsName.isNotEmpty) {
      hostname = mdnsName;
    } else if (ssdpInfo != null && ssdpInfo['name'] != null && ssdpInfo['name']!.isNotEmpty) {
      hostname = ssdpInfo['name']!;
    } else {
      // Reverse DNS
      final rDns = await resolveDnsName(ip);
      if (rDns != null && rDns.isNotEmpty) {
        hostname = rDns;
      } else if (options.enableLlmnr) {
        final llmnr = await resolveLlmnrName(ip);
        if (llmnr != null && llmnr.isNotEmpty) {
          hostname = llmnr;
        }
      }
    }

    // ── Stage 3: Web Title & Service Banners ──────────────────────────────────
    String? webTitle;
    String? serviceBanner;

    if (options.enableHttpTitle && (openPorts.contains(80) || openPorts.contains(8080) || openPorts.contains(443))) {
      final webPort = openPorts.contains(80) ? 80 : (openPorts.contains(8080) ? 8080 : 443);
      final httpDetails = await _fetchHttpDetails(ip, webPort);
      webTitle = httpDetails['title'];
      if (httpDetails['server'] != null) {
        serviceBanner = httpDetails['server'];
      }
    }

    if (serviceBanner == null && openPorts.contains(22)) {
      serviceBanner = await _grabBanner(ip, 22);
    } else if (serviceBanner == null && openPorts.contains(21)) {
      serviceBanner = await _grabBanner(ip, 21);
    }

    // ── Stage 4: Role & Device Type Deduction ────────────────────────────────
    final typeGuess = _deduceDeviceType(
      ip: ip,
      isGateway: isGateway,
      openPorts: openPorts,
      vendor: vendor,
      hostname: hostname,
      webTitle: webTitle,
      serviceBanner: serviceBanner,
    );

    final osGuess = _deduceOsGuess(
      openPorts: openPorts,
      vendor: vendor,
      serviceBanner: serviceBanner,
      netbiosGroup: netbiosGroup,
      typeGuess: typeGuess,
    );

    return DiscoveredHost(
      ip: ip,
      hostname: hostname,
      macAddress: macAddress,
      vendor: vendor,
      osGuess: osGuess,
      typeGuess: typeGuess,
      responseTimeMs: sw.elapsedMilliseconds,
      openPorts: openPorts,
      webTitle: webTitle,
      netbiosGroup: netbiosGroup,
      netbiosUser: netbiosUser,
      serviceBanner: serviceBanner,
      discoveryMethod: discoveryMethod,
      isAlive: true,
    );
  }

  DeviceTypeGuess _deduceDeviceType({
    required String ip,
    required bool isGateway,
    required List<int> openPorts,
    String? vendor,
    String? hostname,
    String? webTitle,
    String? serviceBanner,
  }) {
    final lowerVendor = (vendor ?? '').toLowerCase();
    final lowerHost = (hostname ?? '').toLowerCase();
    final lowerTitle = (webTitle ?? '').toLowerCase();

    if (isGateway || lowerHost.contains('router') || lowerHost.contains('gateway') ||
        lowerTitle.contains('router') || lowerTitle.contains('gateway') || lowerTitle.contains('openwrt') ||
        lowerVendor.contains('tp-link') || lowerVendor.contains('ubiquiti') || lowerVendor.contains('mikrotik') ||
        lowerVendor.contains('cisco') || lowerVendor.contains('d-link') || lowerVendor.contains('netgear')) {
      return DeviceTypeGuess.router;
    }

    if (openPorts.contains(9100) || openPorts.contains(515) || openPorts.contains(631) ||
        lowerHost.contains('printer') || lowerHost.contains('laserjet') || lowerHost.contains('deskjet') ||
        lowerTitle.contains('printer') || lowerTitle.contains('laserjet') ||
        lowerVendor.contains('brother') || lowerVendor.contains('canon') || lowerVendor.contains('epson') ||
        lowerVendor.contains('xerox')) {
      return DeviceTypeGuess.printer;
    }

    if (lowerHost.contains('tv') || lowerHost.contains('cast') || lowerHost.contains('roku') ||
        lowerHost.contains('bravia') || lowerHost.contains('playstation') || lowerVendor.contains('roku') ||
        lowerVendor.contains('sonos') || lowerVendor.contains('sony') || lowerVendor.contains('lg electronics')) {
      return DeviceTypeGuess.smartTv;
    }

    if (lowerVendor.contains('espressif') || lowerVendor.contains('raspberry pi') || lowerVendor.contains('philips hue')) {
      return DeviceTypeGuess.iot;
    }

    if (openPorts.contains(3389) || openPorts.contains(445) || openPorts.contains(139) ||
        lowerVendor.contains('dell') || lowerVendor.contains('lenovo') || lowerVendor.contains('hp inc.') ||
        lowerVendor.contains('microsoft')) {
      return DeviceTypeGuess.workstation;
    }

    if (lowerVendor.contains('synology') || lowerVendor.contains('qnap') ||
        (openPorts.contains(22) && (openPorts.contains(80) || openPorts.contains(443) || openPorts.contains(3306) || openPorts.contains(5432)))) {
      return DeviceTypeGuess.server;
    }

    if (lowerVendor.contains('apple') || lowerVendor.contains('samsung') || lowerVendor.contains('xiaomi') ||
        lowerHost.contains('iphone') || lowerHost.contains('ipad') || lowerHost.contains('android') || lowerHost.contains('galaxy')) {
      return DeviceTypeGuess.mobile;
    }

    return DeviceTypeGuess.other;
  }

  String _deduceOsGuess({
    required List<int> openPorts,
    String? vendor,
    String? serviceBanner,
    String? netbiosGroup,
    required DeviceTypeGuess typeGuess,
  }) {
    final lowerBanner = (serviceBanner ?? '').toLowerCase();
    final lowerVendor = (vendor ?? '').toLowerCase();

    if (lowerBanner.contains('ubuntu') || lowerBanner.contains('debian')) {
      return 'Linux (Ubuntu/Debian)';
    }
    if (lowerBanner.contains('raspbian') || lowerVendor.contains('raspberry pi')) {
      return 'Raspberry Pi OS';
    }
    if (lowerBanner.contains('windows') || openPorts.contains(3389) || (netbiosGroup != null && netbiosGroup.isNotEmpty)) {
      return 'Windows OS';
    }
    if (lowerVendor.contains('apple')) {
      return typeGuess == DeviceTypeGuess.mobile ? 'Apple iOS' : 'Apple macOS';
    }
    if (lowerVendor.contains('samsung') || lowerVendor.contains('xiaomi')) {
      return 'Android OS';
    }
    if (typeGuess == DeviceTypeGuess.router) {
      return 'Network Device Firmware';
    }
    if (typeGuess == DeviceTypeGuess.printer) {
      return 'Embedded Printer Firmware';
    }
    if (typeGuess == DeviceTypeGuess.iot) {
      return 'IoT Embedded RTOS';
    }
    if (openPorts.contains(22)) {
      return 'Linux / Unix Server';
    }
    return 'Embedded / Generic OS';
  }
}
