import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import 'dashboard/dashboard_screen.dart';
import 'inventory/inventory_screen.dart';
import 'borrowed/borrowed_screen.dart';
import 'expenses/expenses_screen.dart';
import 'logs/logs_screen.dart';
import 'more_screen.dart';

class HomeScreen extends StatefulWidget {
  final ThemeService themeService;
  const HomeScreen({super.key, required this.themeService});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;

  static const _labels = ['Dashboard', 'Inventory', 'Borrowed', 'Expenses', 'Log', 'More'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.inventory_2_outlined,
    Icons.swap_horiz_outlined,
    Icons.receipt_long_outlined,
    Icons.history_outlined,
    Icons.grid_view_outlined,
  ];
  static const _activeIcons = [
    Icons.dashboard,
    Icons.inventory_2,
    Icons.swap_horiz,
    Icons.receipt_long,
    Icons.history,
    Icons.grid_view,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: IndexedStack(
          key: ValueKey<int>(_idx),
          index: _idx,
          children: [
            DashboardScreen(onSwitchTab: (i) => setState(() => _idx = i)),
            const InventoryScreen(),
            const BorrowedScreen(),
            const ExpensesScreen(),
            const LogsScreen(),
            MoreScreen(themeService: widget.themeService),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: List.generate(6, (i) => NavigationDestination(
          icon: Icon(_icons[i]),
          selectedIcon: Icon(_activeIcons[i]),
          label: _labels[i],
        )),
      ),
    );
  }
}
