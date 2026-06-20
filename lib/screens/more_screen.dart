import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import 'employees/employees_screen.dart';
import 'bills/bills_screen.dart';
import 'settings/settings_screen.dart';

class MoreScreen extends StatelessWidget {
  final ThemeService themeService;
  const MoreScreen({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SectionLabel('MANAGEMENT'),
          _NavCard(
            icon: Icons.people_outline,
            activeIcon: Icons.people,
            color: const Color(0xFF0EA5E9),
            title: 'Employees',
            subtitle: 'View and manage employee directory',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const EmployeesScreen())),
          ),
          const SizedBox(height: 10),
          _NavCard(
            icon: Icons.receipt_outlined,
            activeIcon: Icons.receipt,
            color: const Color(0xFF7C3AED),
            title: 'Bills',
            subtitle: 'Track recurring bills by category',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BillsScreen())),
          ),
          const SizedBox(height: 24),
          _SectionLabel('APP'),
          _NavCard(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            color: const Color(0xFF6B7280),
            title: 'Settings',
            subtitle: 'Theme, backup, export, import, labels',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(themeService: themeService))),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 4),
    child: Text(text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.8,
      )),
  );
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.activeIcon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  )),
                const SizedBox(height: 2),
                Text(subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  )),
              ],
            )),
            Icon(Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
          ]),
        ),
      ),
    );
  }
}
