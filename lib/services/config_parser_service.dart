// lib/services/config_parser_service.dart

class CiscoInterfaceConfig {
  final String name;
  final String description;
  final String? ipAddress;
  final String? subnetMask;
  final bool isShutdown;
  final int? vlan;
  final String mode; // 'access', 'trunk', 'routed', 'unknown'

  const CiscoInterfaceConfig({
    required this.name,
    this.description = '',
    this.ipAddress,
    this.subnetMask,
    this.isShutdown = false,
    this.vlan,
    this.mode = 'unknown',
  });
}

class CiscoParsedConfig {
  final String hostname;
  final List<String> vlans;
  final List<CiscoInterfaceConfig> interfaces;
  final List<String> staticRoutes;
  final List<String> warnings;

  const CiscoParsedConfig({
    required this.hostname,
    required this.vlans,
    required this.interfaces,
    required this.staticRoutes,
    required this.warnings,
  });
}

class ConfigParserService {
  /// Parse Cisco IOS running-config / startup-config text.
  CiscoParsedConfig parseCiscoIos(String rawConfig) {
    final lines = rawConfig.split('\n');
    String hostname = 'Router/Switch';
    final vlans = <String>{};
    final interfaces = <CiscoInterfaceConfig>[];
    final staticRoutes = <String>[];
    final warnings = <String>[];

    String? currentIfName;
    String currentIfDesc = '';
    String? currentIfIp;
    String? currentIfMask;
    bool currentIfShutdown = false;
    int? currentIfVlan;
    String currentIfMode = 'unknown';

    void commitCurrentInterface() {
      if (currentIfName != null) {
        interfaces.add(CiscoInterfaceConfig(
          name: currentIfName!,
          description: currentIfDesc,
          ipAddress: currentIfIp,
          subnetMask: currentIfMask,
          isShutdown: currentIfShutdown,
          vlan: currentIfVlan,
          mode: currentIfMode,
        ));
      }
      currentIfName = null;
      currentIfDesc = '';
      currentIfIp = null;
      currentIfMask = null;
      currentIfShutdown = false;
      currentIfVlan = null;
      currentIfMode = 'unknown';
    }

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('!')) continue;

      if (line.toLowerCase().startsWith('hostname ')) {
        hostname = line.substring(9).trim();
      } else if (line.toLowerCase().startsWith('interface ')) {
        commitCurrentInterface();
        currentIfName = line.substring(10).trim();
      } else if (currentIfName != null) {
        if (line.toLowerCase().startsWith('description ')) {
          currentIfDesc = line.substring(12).trim();
        } else if (line.toLowerCase().startsWith('ip address ')) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            currentIfIp = parts[2];
            currentIfMask = parts[3];
            currentIfMode = 'routed';
          }
        } else if (line.toLowerCase() == 'shutdown') {
          currentIfShutdown = true;
        } else if (line.toLowerCase().startsWith('switchport access vlan ')) {
          final vlanStr = line.split(RegExp(r'\s+')).last;
          currentIfVlan = int.tryParse(vlanStr);
          if (currentIfVlan != null) vlans.add(vlanStr);
          currentIfMode = 'access';
        } else if (line.toLowerCase().contains('switchport mode trunk')) {
          currentIfMode = 'trunk';
        }
      } else if (line.toLowerCase().startsWith('ip route ')) {
        staticRoutes.add(line);
      } else if (line.toLowerCase().startsWith('vlan ')) {
        final vlanStr = line.substring(5).trim();
        if (int.tryParse(vlanStr) != null) vlans.add(vlanStr);
      }
    }

    commitCurrentInterface();

    if (interfaces.isEmpty) {
      warnings.add('No network interfaces identified. Ensure file is a standard Cisco IOS text export.');
    }

    return CiscoParsedConfig(
      hostname: hostname,
      vlans: vlans.toList()..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0)),
      interfaces: interfaces,
      staticRoutes: staticRoutes,
      warnings: warnings,
    );
  }
}
