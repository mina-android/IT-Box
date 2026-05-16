import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import 'borrowed/borrowed_screen.dart';
import 'expenses/expenses_screen.dart';
import 'employees/employees_screen.dart';
import 'inventory/inventory_screen.dart';
import 'bills/bills_screen.dart';
import 'emails/emails_screen.dart';

class HomeScreen extends StatefulWidget {
  final ThemeService themeService;
  const HomeScreen({super.key, required this.themeService});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;

  static const _labels = ['Borrowed', 'Expenses', 'Employees', 'Inventory', 'Bills', 'Emails'];
  static const _icons  = [
    Icons.swap_horiz_outlined,
    Icons.receipt_long_outlined,
    Icons.people_outline,
    Icons.inventory_2_outlined,
    Icons.receipt_outlined,
    Icons.email_outlined,
  ];
  static const _activeIcons = [
    Icons.swap_horiz,
    Icons.receipt_long,
    Icons.people,
    Icons.inventory_2,
    Icons.receipt,
    Icons.email,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _idx,
        children: const [
          BorrowedScreen(),
          ExpensesScreen(),
          EmployeesScreen(),
          InventoryScreen(),
          BillsScreen(),
          EmailsScreen(),
        ],
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
