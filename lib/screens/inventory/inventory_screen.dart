import 'package:flutter/material.dart';
import '../laptops/laptops_screen.dart';
import '../network_devices/network_devices_screen.dart';
import '../mifis/mifis_screen.dart';
import '../access_points/access_points_screen.dart';
import '../printers/printers_screen.dart';
import '../electronics/electronics_screen.dart';
import '../others/other_devices_screen.dart';
import '../../services/company_service.dart';
import '../../widgets/fintech_components.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 7, vsync: this);
  final ScrollController _scrollController = ScrollController();

  static const _categories = [
    ('Laptops', Icons.laptop_outlined, Icons.laptop_mac_rounded),
    ('Routers', Icons.router_outlined, Icons.router_rounded),
    ('MiFis', Icons.wifi_tethering_outlined, Icons.wifi_tethering_rounded),
    ('APs', Icons.cell_tower_outlined, Icons.cell_tower_rounded),
    ('Printers', Icons.print_outlined, Icons.print_rounded),
    ('Electronics', Icons.devices_other_outlined, Icons.devices_other_rounded),
    ('Others', Icons.devices_outlined, Icons.devices_rounded),
  ];

  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (mounted && !_tabs.indexIsChanging && _tabs.index != _lastIndex) {
        _lastIndex = _tabs.index;
        setState(() {});
        _scrollToSelectedTab(_tabs.index);
      }
    });
  }

  void _scrollToSelectedTab(int index) {
    if (!_scrollController.hasClients) {
      return;
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final itemOffset = index * 106.0;
    final targetOffset = (itemOffset - (screenWidth / 2) + 50 + 16).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CompanyService(),
      builder: (context, _) {
        final theme = Theme.of(context);
        final company = CompanyService().name;
        final title = company.isNotEmpty ? '$company Inventory' : 'Hardware Inventory';

        return Scaffold(
      appBar: FintechAppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: title,
        subtitle: 'Hardware assets & operational registry',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: SizedBox(
            height: 58,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final isSelected = _tabs.index == i;
                return SizedBox(
                  width: 98,
                  height: 50,
                  child: InkWell(
                    onTap: () {
                      _tabs.animateTo(i);
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? cat.$3 : cat.$2,
                            size: 19,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cat.$1,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          LaptopsScreen(),
          NetworkDevicesScreen(),
          MiFisScreen(),
          AccessPointsScreen(),
          PrintersScreen(),
          ElectronicsScreen(),
          OtherDevicesScreen(),
        ],
      ),
    );
  },
);
  }
}
