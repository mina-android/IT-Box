// lib/screens/more_screen.dart
import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../utils/haptics.dart';
import 'employees/employees_screen.dart';
import 'bills/bills_screen.dart';
import 'subscriptions/subscriptions_screen.dart';
import 'expenses/expenses_screen.dart';
import 'settings/settings_screen.dart';
import 'settings/label_export_screen.dart';
import 'settings/data_hub_screen.dart';
import 'network_tools/network_scanner_screen.dart';
import 'network_tools/cidr_calculator_screen.dart';
import 'network_tools/static_ip_list_screen.dart';
import 'network_tools/switch_patch_matrix_screen.dart';
import 'barcode_scanner/barcode_scanner_screen.dart';
import 'audit_trail/activity_feed_screen.dart';
import 'wifi_networks/wifi_networks_screen.dart';
import 'accounts_passwords/accounts_passwords_screen.dart';
import 'vendor_contacts/vendor_contacts_screen.dart';
import 'network_tools/unit_converter_screen.dart';
import 'search/global_search_screen.dart';
import 'network_tools/diagnostics/network_diagnostics_screen.dart';
import 'maintenance/maintenance_calendar_screen.dart';
import 'package:itbox/widgets/common_widgets.dart';

class _MoreItem {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final Widget screen;

  const _MoreItem({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.screen,
  });
}

class _MoreSection {
  final String title;
  final List<_MoreItem> items;

  const _MoreSection({
    required this.title,
    required this.items,
  });
}

class MoreScreen extends StatelessWidget {
  final ThemeService themeService;
  const MoreScreen({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tabTeal = isDark ? const Color(0xFF4DB6AC) : const Color(0xFF00897B);

    final sections = [
      const _MoreSection(
        title: 'MANAGEMENT & DIRECTORY',
        items: [
          _MoreItem(
            icon: Icons.people_outline_rounded,
            label: 'Employees',
            sub: 'Profiles, 360° & offboarding',
            color: Color(0xFF0EA5E9),
            screen: EmployeesScreen(),
          ),
          _MoreItem(
            icon: Icons.receipt_long_rounded,
            label: 'Recurring Bills',
            sub: 'Internet & power',
            color: Color(0xFF7C3AED),
            screen: BillsScreen(),
          ),
          _MoreItem(
            icon: Icons.subscriptions_rounded,
            label: 'Subscriptions',
            sub: 'Licenses & renewals',
            color: Color(0xFFE11D48),
            screen: SubscriptionsScreen(),
          ),
          _MoreItem(
            icon: Icons.payments_rounded,
            label: 'Expenses',
            sub: 'Ledger & spending',
            color: Color(0xFF10B981),
            screen: ExpensesScreen(),
          ),
          _MoreItem(
            icon: Icons.vpn_key_rounded,
            label: 'Accounts & Passwords',
            sub: 'Credentials & platform vault',
            color: Color(0xFFF59E0B),
            screen: AccountsPasswordsScreen(),
          ),
        ],
      ),
      const _MoreSection(
        title: 'NETWORK & SYSADMIN SUITE',
        items: [
          _MoreItem(
            icon: Icons.radar_rounded,
            label: 'Network Scanner',
            sub: 'Sweep subnet, OS & ports',
            color: Color(0xFF3B82F6),
            screen: NetworkScannerScreen(),
          ),
          _MoreItem(
            icon: Icons.lan_rounded,
            label: 'Static IP Registry',
            sub: 'IPAM address management',
            color: Color(0xFF06B6D4),
            screen: StaticIpListScreen(),
          ),
          _MoreItem(
            icon: Icons.settings_input_hdmi_rounded,
            label: 'Switch Patch Matrix',
            sub: '24-port visual patch panel',
            color: Color(0xFF8B5CF6),
            screen: SwitchPatchMatrixScreen(),
          ),
          _MoreItem(
            icon: Icons.wifi_password_rounded,
            label: 'Wi-Fi Networks',
            sub: 'SSIDs, passwords & admin portal',
            color: Color(0xFF059669),
            screen: WifiNetworksScreen(),
          ),
          _MoreItem(
            icon: Icons.calculate_outlined,
            label: 'Subnet Calculator',
            sub: 'Subnet & mask calculator',
            color: Color(0xFF14B8A6),
            screen: CidrCalculatorScreen(),
          ),
          _MoreItem(
            icon: Icons.transform_rounded,
            label: 'Unit Converter',
            sub: 'Network, storage & RF units',
            color: Color(0xFF0D9488),
            screen: UnitConverterScreen(),
          ),
          _MoreItem(
            icon: Icons.contact_phone_rounded,
            label: 'Vendor Runbook',
            sub: 'ISPs, hotlines & vendor contacts',
            color: Color(0xFF0284C7),
            screen: VendorContactsScreen(),
          ),
          _MoreItem(
            icon: Icons.troubleshoot_rounded,
            label: 'Network Diagnostics',
            sub: 'DNS, port probe & speed test',
            color: Color(0xFF6366F1),
            screen: NetworkDiagnosticsScreen(),
          ),
          _MoreItem(
            icon: Icons.calendar_month_rounded,
            label: 'Maintenance Calendar',
            sub: 'Planned repairs & service events',
            color: Color(0xFFD97706),
            screen: MaintenanceCalendarScreen(),
          ),
        ],
      ),
      const _MoreSection(
        title: 'TOOLS & EXPORTS',
        items: [
          _MoreItem(
            icon: Icons.search_rounded,
            label: 'Global Search',
            sub: 'Search all 21 tables & assets',
            color: Color(0xFF6366F1),
            screen: GlobalSearchScreen(),
          ),
          _MoreItem(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan Barcode / QR',
            sub: 'Hardware tag lookup & audit',
            color: Color(0xFFEC4899),
            screen: BarcodeScannerScreen(),
          ),
          _MoreItem(
            icon: Icons.qr_code_2_rounded,
            label: 'Asset Labels',
            sub: 'Printable tags & Wi-Fi cards',
            color: Color(0xFFB45309),
            screen: LabelExportScreen(),
          ),
          _MoreItem(
            icon: Icons.sync_alt_rounded,
            label: 'Data Hub',
            sub: 'Backup, import & restore',
            color: Color(0xFF6366F1),
            screen: DataHubScreen(),
          ),
          _MoreItem(
            icon: Icons.history_rounded,
            label: 'Audit Trail',
            sub: 'System activity history',
            color: Color(0xFF64748B),
            screen: ActivityFeedScreen(),
          ),
        ],
      ),
    ];

    final totalTools = sections.fold<int>(0, (sum, s) => sum + s.items.length);

    return Scaffold(
      appBar: FintechAppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: 'More Operations',
        subtitle: '$totalTools management tools & preferences',
        actions: [
          FintechCircleButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onPressed: () {
              AppHaptics.tap(context, HapticStrength.light);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(themeService: themeService),
                ),
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          for (final section in sections) ...[
            SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 16, 10),
                        child: Text(
                          section.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: tabTeal,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.36,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildCard(context, section.items[index], isDark),
                          childCount: section.items.length,
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 120),
                  ),
                ],
              ),
    );
  }

  Widget _buildCard(BuildContext context, _MoreItem item, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer.withValues(alpha: isDark ? 0.45 : 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            AppHaptics.tap(context, HapticStrength.selection);
            Navigator.push(context, MaterialPageRoute(builder: (_) => item.screen));
          },
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
