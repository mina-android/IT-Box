// lib/services/global_search_service.dart
import '../database/database_helper.dart';

enum SearchCategory {
  laptop,
  networkDevice,
  printer,
  mifi,
  electronic,
  employee,
  email,
  staticIp,
  vendorContact,
}

class SearchResultItem {
  final int id;
  final String title;
  final String subtitle;
  final String extraInfo;
  final SearchCategory category;
  final String categoryLabel;

  const SearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.extraInfo,
    required this.category,
    required this.categoryLabel,
  });
}

class GlobalSearchService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<SearchResultItem>> search(String rawQuery) async {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final results = <SearchResultItem>[];

    // 1. Laptops
    final laptops = await _db.getLaptops();
    for (final l in laptops) {
      if (l.laptopNumber.toLowerCase().contains(query) ||
          l.model.toLowerCase().contains(query) ||
          l.user.toLowerCase().contains(query) ||
          l.notes.toLowerCase().contains(query) ||
          l.cpu.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: l.id!,
          title: '${l.laptopNumber} • ${l.model}',
          subtitle: l.user.isNotEmpty ? 'Assigned: ${l.user}' : 'Unassigned (${l.condition})',
          extraInfo: [l.cpu, l.ram, l.storage].where((s) => s.isNotEmpty).join(' / '),
          category: SearchCategory.laptop,
          categoryLabel: 'Laptop',
        ));
      }
    }

    // 2. Network Devices (Routers/Switches)
    final netDevices = await _db.getNetworkDevices();
    for (final d in netDevices) {
      if (d.deviceNumber.toLowerCase().contains(query) ||
          d.model.toLowerCase().contains(query) ||
          d.deviceLocation.toLowerCase().contains(query) ||
          d.serviceProvider.toLowerCase().contains(query) ||
          d.notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: d.id ?? 0,
          title: '${d.deviceNumber} • ${d.model}',
          subtitle: d.deviceLocation.isNotEmpty ? d.deviceLocation : d.serviceProvider,
          extraInfo: d.gateway.isNotEmpty ? 'Gateway: ${d.gateway}' : '',
          category: SearchCategory.networkDevice,
          categoryLabel: 'Network Device',
        ));
      }
    }

    // 3. Printers
    final printers = await _db.getPrinters();
    for (final p in printers) {
      if (p.printerNumber.toLowerCase().contains(query) ||
          p.model.toLowerCase().contains(query) ||
          p.location.toLowerCase().contains(query) ||
          p.notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: p.id ?? 0,
          title: '#${p.printerNumber} • ${p.model}',
          subtitle: p.location.isNotEmpty ? p.location : 'Location unassigned',
          extraInfo: 'Condition: ${p.condition}',
          category: SearchCategory.printer,
          categoryLabel: 'Printer',
        ));
      }
    }

    // 4. MiFis
    final mifis = await _db.getMiFis();
    for (final m in mifis) {
      if (m.deviceNumber.toLowerCase().contains(query) ||
          m.model.toLowerCase().contains(query) ||
          m.phoneNumber.toLowerCase().contains(query) ||
          m.wifiName.toLowerCase().contains(query) ||
          m.serviceProvider.toLowerCase().contains(query) ||
          m.notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: m.id!,
          title: 'MiFi #${m.deviceNumber} • ${m.model}',
          subtitle: 'Status: ${m.status} • Provider: ${m.serviceProvider}',
          extraInfo: m.phoneNumber.isNotEmpty ? 'Phone: ${m.phoneNumber}' : 'Wi-Fi: ${m.wifiName}',
          category: SearchCategory.mifi,
          categoryLabel: 'MiFi',
        ));
      }
    }

    // 5. Electronics
    final electronics = await _db.getElectronics();
    for (final e in electronics) {
      if (e.deviceNumber.toLowerCase().contains(query) ||
          e.deviceName.toLowerCase().contains(query) ||
          e.details.toLowerCase().contains(query) ||
          e.notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: e.id!,
          title: '${e.deviceName} #${e.deviceNumber}',
          subtitle: 'Status: ${e.status}',
          extraInfo: e.details,
          category: SearchCategory.electronic,
          categoryLabel: 'Electronics',
        ));
      }
    }

    // 6. Employees
    final employees = await _db.getEmployees();
    for (final emp in employees) {
      if (emp.name.toLowerCase().contains(query) ||
          emp.phoneNumber.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: emp.id!,
          title: emp.name,
          subtitle: emp.phoneNumber.isNotEmpty ? emp.phoneNumber : 'No phone',
          extraInfo: '',
          category: SearchCategory.employee,
          categoryLabel: 'Employee',
        ));
      }
    }

    // 7. Emails
    final emails = await _db.getEmailAccounts();
    for (final em in emails) {
      if (em.email.toLowerCase().contains(query) ||
          em.employeeName.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: em.id!,
          title: em.email,
          subtitle: em.employeeName.isNotEmpty ? 'Employee: ${em.employeeName}' : 'Unassigned',
          extraInfo: '',
          category: SearchCategory.email,
          categoryLabel: 'Email Account',
        ));
      }
    }

    // 8. Static IPs
    final staticIps = await _db.getStaticIps();
    for (final ip in staticIps) {
      final ipStr = ip['ip_address']?.toString() ?? '';
      final deviceName = ip['device_name']?.toString() ?? '';
      final assignedTo = ip['assigned_to']?.toString() ?? '';
      final mac = ip['mac_address']?.toString() ?? '';
      if (ipStr.toLowerCase().contains(query) ||
          deviceName.toLowerCase().contains(query) ||
          assignedTo.toLowerCase().contains(query) ||
          mac.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: ip['id'] as int? ?? 0,
          title: '$ipStr • $deviceName',
          subtitle: assignedTo.isNotEmpty ? 'Assigned: $assignedTo' : 'No user assigned',
          extraInfo: mac.isNotEmpty ? 'MAC: $mac' : '',
          category: SearchCategory.staticIp,
          categoryLabel: 'Static IP',
        ));
      }
    }

    // 9. Vendor Contacts
    final vendors = await _db.getVendorContacts();
    for (final v in vendors) {
      if (v.name.toLowerCase().contains(query) ||
          v.company.toLowerCase().contains(query) ||
          v.role.toLowerCase().contains(query) ||
          v.accountNumber.toLowerCase().contains(query) ||
          v.phoneNumber.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: v.id ?? 0,
          title: '${v.name} (${v.contactType})',
          subtitle: [v.company, v.role].where((s) => s.isNotEmpty).join(' • '),
          extraInfo: v.accountNumber.isNotEmpty ? 'Acc/CID: ${v.accountNumber}' : v.phoneNumber,
          category: SearchCategory.vendorContact,
          categoryLabel: 'Vendor Runbook',
        ));
      }
    }

    return results;
  }
}
