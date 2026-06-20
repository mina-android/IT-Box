import 'package:flutter/material.dart';
import '../laptops/laptops_screen.dart';
import '../network_devices/network_devices_screen.dart';
import '../mifis/mifis_screen.dart';
import '../printers/printers_screen.dart';
import '../electronics/electronics_screen.dart';
import '../../services/company_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final company = CompanyService().name;
    final title = company.isNotEmpty ? '$company Inventory' : 'Inventory';
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: TabBar(
            controller: _tabs,
            isScrollable: false,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 10),
            tabs: const [
              Tab(icon: Icon(Icons.laptop_outlined,         size: 20), text: 'Laptops'),
              Tab(icon: Icon(Icons.router_outlined,         size: 20), text: 'Network'),
              Tab(icon: Icon(Icons.wifi_tethering_outlined, size: 20), text: 'MiFis'),
              Tab(icon: Icon(Icons.print_outlined,          size: 20), text: 'Printers'),
              Tab(icon: Icon(Icons.devices_other_outlined,  size: 20), text: 'Electronics'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          LaptopsScreen(),
          NetworkDevicesScreen(),
          MiFisScreen(),
          PrintersScreen(),
          ElectronicsScreen(),
        ],
      ),
    );
  }
}
