// lib/services/global_search_service.dart
import '../database/database_helper.dart';
import 'currency_service.dart';

enum SearchCategory {
  laptop,
  networkDevice,
  printer,
  mifi,
  accessPoint,
  electronic,
  otherDevice,
  employee,
  borrow,
  ticket,
  email,
  wifiNetwork,
  accountPassword,
  staticIp,
  vendorContact,
  expense,
  bill,
  subscription,
  custodyDocument,
  vaultDocument,
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
    if (query.isEmpty) {
      return const [];
    }

    final results = <SearchResultItem>[];
    final cur = CurrencyService();

    // 1. Laptops
    final laptops = await _db.getLaptops();
    for (final l in laptops) {
      if (l.laptopNumber.toLowerCase().contains(query) ||
          l.model.toLowerCase().contains(query) ||
          l.user.toLowerCase().contains(query) ||
          l.notes.toLowerCase().contains(query) ||
          l.cpu.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: l.id ?? 0,
          title: '${l.laptopNumber} • ${l.model}',
          subtitle: l.user.isNotEmpty ? 'Assigned: ${l.user}' : 'Unassigned (${l.condition})',
          extraInfo: [l.cpu, l.ram, l.storage].where((s) => s.isNotEmpty).join(' / '),
          category: SearchCategory.laptop,
          categoryLabel: 'Laptop',
        ));
      }
    }

    // 2. Network Devices (Routers)
    final netDevices = await _db.getNetworkDevices();
    for (final d in netDevices) {
      if (d.deviceNumber.toLowerCase().contains(query) ||
          d.model.toLowerCase().contains(query) ||
          d.deviceLocation.toLowerCase().contains(query) ||
          d.serviceProvider.toLowerCase().contains(query) ||
          d.gateway.toLowerCase().contains(query) ||
          d.notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: d.id ?? 0,
          title: '${d.deviceNumber} • ${d.model}',
          subtitle: d.deviceLocation.isNotEmpty ? d.deviceLocation : d.serviceProvider,
          extraInfo: d.gateway.isNotEmpty ? 'Gateway: ${d.gateway}' : '',
          category: SearchCategory.networkDevice,
          categoryLabel: 'Router',
        ));
      }
    }

    // 3. Access Points
    final aps = await _db.getAccessPoints();
    for (final ap in aps) {
      if (ap.deviceNumber.toLowerCase().contains(query) ||
          ap.model.toLowerCase().contains(query) ||
          ap.location.toLowerCase().contains(query) ||
          ap.portNumber.toLowerCase().contains(query) ||
          ap.notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: ap.id ?? 0,
          title: '${ap.deviceNumber} • ${ap.model}',
          subtitle: ap.location.isNotEmpty ? ap.location : 'Location unassigned',
          extraInfo: ap.portNumber.isNotEmpty ? 'Port: ${ap.portNumber}' : '',
          category: SearchCategory.accessPoint,
          categoryLabel: 'Access Point',
        ));
      }
    }

    // 4. Printers
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

    // 5. MiFis
    final mifis = await _db.getMiFis();
    for (final m in mifis) {
      if (m.deviceNumber.toLowerCase().contains(query) ||
          m.model.toLowerCase().contains(query) ||
          m.phoneNumber.toLowerCase().contains(query) ||
          m.wifiName.toLowerCase().contains(query) ||
          m.serviceProvider.toLowerCase().contains(query) ||
          m.notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: m.id ?? 0,
          title: 'MiFi #${m.deviceNumber} • ${m.model}',
          subtitle: 'Status: ${m.status} • Provider: ${m.serviceProvider}',
          extraInfo: m.phoneNumber.isNotEmpty ? 'Phone: ${m.phoneNumber}' : 'Wi-Fi: ${m.wifiName}',
          category: SearchCategory.mifi,
          categoryLabel: 'MiFi',
        ));
      }
    }

    // 6. Electronics
    final electronics = await _db.getElectronics();
    for (final e in electronics) {
      if (e.deviceNumber.toLowerCase().contains(query) ||
          e.deviceName.toLowerCase().contains(query) ||
          e.details.toLowerCase().contains(query) ||
          e.notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: e.id ?? 0,
          title: '${e.deviceName} #${e.deviceNumber}',
          subtitle: 'Status: ${e.status}',
          extraInfo: e.details,
          category: SearchCategory.electronic,
          categoryLabel: 'Electronics',
        ));
      }
    }

    // 7. Other Devices
    final others = await _db.getOtherDevices();
    for (final o in others) {
      if (o.deviceName.toLowerCase().contains(query) ||
          o.deviceType.toLowerCase().contains(query) ||
          o.model.toLowerCase().contains(query) ||
          o.notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: o.id ?? 0,
          title: o.deviceName,
          subtitle: 'Category: ${o.deviceType}',
          extraInfo: o.model,
          category: SearchCategory.otherDevice,
          categoryLabel: 'Other Device',
        ));
      }
    }

    // 8. Employees
    final employees = await _db.getEmployees();
    for (final emp in employees) {
      if (emp.name.toLowerCase().contains(query) ||
          emp.phoneNumber.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: emp.id ?? 0,
          title: emp.name,
          subtitle: emp.phoneNumber.isNotEmpty ? emp.phoneNumber : 'No phone',
          extraInfo: '',
          category: SearchCategory.employee,
          categoryLabel: 'Employee',
        ));
      }
    }

    // 9. Borrows
    final borrows = await _db.getBorrowLogs();
    for (final b in borrows) {
      if (b.deviceName.toLowerCase().contains(query) ||
          b.deviceNumber.toLowerCase().contains(query) ||
          b.employeeName.toLowerCase().contains(query) ||
          b.reason.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: b.id ?? 0,
          title: '${b.deviceName} (#${b.deviceNumber})',
          subtitle: 'Borrowed by ${b.employeeName}',
          extraInfo: b.isReturned ? 'Returned ${b.backDate ?? ''}' : 'Out since ${b.outDate}',
          category: SearchCategory.borrow,
          categoryLabel: 'Borrow',
        ));
      }
    }

    // 10. Tickets / Logs
    final tickets = await _db.getLogEntries();
    for (final t in tickets) {
      if (t.problem.toLowerCase().contains(query) ||
          t.solution.toLowerCase().contains(query) ||
          t.employeeName.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: t.id ?? 0,
          title: t.problem,
          subtitle: '${t.employeeName} • ${t.state} (${t.priority})',
          extraInfo: t.date,
          category: SearchCategory.ticket,
          categoryLabel: 'Ticket',
        ));
      }
    }

    // 11. Emails
    final emails = await _db.getEmailAccounts();
    for (final em in emails) {
      if (em.email.toLowerCase().contains(query) ||
          em.employeeName.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: em.id ?? 0,
          title: em.email,
          subtitle: em.employeeName.isNotEmpty ? 'Employee: ${em.employeeName}' : 'Unassigned',
          extraInfo: '',
          category: SearchCategory.email,
          categoryLabel: 'Email',
        ));
      }
    }

    // 12. Wi-Fi Networks
    final wifis = await _db.getWifiNetworks();
    for (final w in wifis) {
      if (w.networkName.toLowerCase().contains(query) ||
          w.locationDevice.toLowerCase().contains(query) ||
          w.phoneNumber.toLowerCase().contains(query) ||
          w.notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: w.id ?? 0,
          title: w.networkName,
          subtitle: w.locationDevice.isNotEmpty ? w.locationDevice : 'Wi-Fi Network',
          extraInfo: w.phoneNumber,
          category: SearchCategory.wifiNetwork,
          categoryLabel: 'Wi-Fi',
        ));
      }
    }

    // 13. Account Passwords
    final creds = await _db.getAccountPasswords();
    for (final c in creds) {
      if (c.platform.toLowerCase().contains(query) ||
          c.emailUsername.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: c.id ?? 0,
          title: c.platform,
          subtitle: c.emailUsername,
          extraInfo: 'Credential Vault',
          category: SearchCategory.accountPassword,
          categoryLabel: 'Credential',
        ));
      }
    }

    // 14. Static IPs
    final staticIps = await _db.getStaticIps();
    for (final ip in staticIps) {
      final ipStr = ip['ip_address']?.toString() ?? '';
      final deviceName = ip['assigned_device']?.toString() ?? '';
      final deviceType = ip['device_type']?.toString() ?? '';
      final mac = ip['mac_address']?.toString() ?? '';
      final notes = ip['notes']?.toString() ?? '';
      if (ipStr.toLowerCase().contains(query) ||
          deviceName.toLowerCase().contains(query) ||
          deviceType.toLowerCase().contains(query) ||
          mac.toLowerCase().contains(query) ||
          notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: ip['id'] as int? ?? 0,
          title: '$ipStr${deviceName.isNotEmpty ? ' • $deviceName' : ''}',
          subtitle: deviceType.isNotEmpty ? 'Type: $deviceType' : 'Static IP',
          extraInfo: mac.isNotEmpty ? 'MAC: $mac' : notes,
          category: SearchCategory.staticIp,
          categoryLabel: 'Static IP',
        ));
      }
    }

    // 15. Vendor Contacts
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
          categoryLabel: 'Vendor',
        ));
      }
    }

    // 16. Expenses
    final expenses = await _db.getExpenses();
    for (final ex in expenses) {
      if (ex.item.toLowerCase().contains(query) ||
          ex.details.toLowerCase().contains(query) ||
          ex.date.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: ex.id ?? 0,
          title: ex.item,
          subtitle: '${cur.format(ex.price)} • ${ex.date}',
          extraInfo: ex.details,
          category: SearchCategory.expense,
          categoryLabel: 'Expense',
        ));
      }
    }

    // 17. Bills
    final bills = await _db.getBills();
    for (final b in bills) {
      if (b.category.toLowerCase().contains(query) ||
          b.person.toLowerCase().contains(query) ||
          b.number.toLowerCase().contains(query) ||
          b.notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: b.id ?? 0,
          title: '${b.category} • ${b.number}',
          subtitle: '${cur.format(b.price)} ${b.person.isNotEmpty ? '• ${b.person}' : ''}',
          extraInfo: b.notes,
          category: SearchCategory.bill,
          categoryLabel: 'Bill',
        ));
      }
    }

    // 18. Subscriptions
    final subs = await _db.getSubscriptions();
    for (final s in subs) {
      if (s.service.toLowerCase().contains(query) ||
          s.type.toLowerCase().contains(query) ||
          s.notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: s.id ?? 0,
          title: s.service,
          subtitle: '${cur.format(s.price)} / ${s.type}',
          extraInfo: s.renewalDate.isNotEmpty ? 'Renews: ${s.renewalDate}' : s.notes,
          category: SearchCategory.subscription,
          categoryLabel: 'Subscription',
        ));
      }
    }

    // 19. Custody Documents & 20. Vault Documents
    final docResults = await Future.wait([
      _db.getCustodyDocuments(),
      _db.getVaultDocuments(),
    ]);
    for (final c in docResults[0] as List<dynamic>) {
      if (c.documentNumber.toLowerCase().contains(query) ||
          c.employeeName.toLowerCase().contains(query) ||
          c.title.toLowerCase().contains(query) ||
          c.itemsJson.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: c.id ?? 0,
          title: '${c.documentNumber} • ${c.employeeName}',
          subtitle: '${c.title} (${c.handoverDate})',
          extraInfo: c.sourceType.toUpperCase(),
          category: SearchCategory.custodyDocument,
          categoryLabel: 'Custody Doc',
        ));
      }
    }
    for (final v in docResults[1] as List<dynamic>) {
      if (v.title.toLowerCase().contains(query) ||
          v.category.toLowerCase().contains(query) ||
          v.linkedEmployeeName.toLowerCase().contains(query) ||
          v.linkedAssetLabel.toLowerCase().contains(query) ||
          v.notes.toLowerCase().contains(query)) {
        results.add(SearchResultItem(
          id: v.id ?? 0,
          title: v.title,
          subtitle: '${v.category} • ${v.formattedSize}',
          extraInfo: v.linkedEmployeeName.isNotEmpty ? v.linkedEmployeeName : v.linkedAssetLabel,
          category: SearchCategory.vaultDocument,
          categoryLabel: 'Vault Doc',
        ));
      }
    }

    return results;
  }
}
