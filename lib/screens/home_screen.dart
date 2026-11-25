// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/theme_service.dart';
import '../services/auto_backup_service.dart';
import '../utils/haptics.dart';
import '../widgets/rounded_square_border.dart';
import 'dashboard/dashboard_screen.dart';
import 'inventory/inventory_screen.dart';
import 'activity_screen.dart';
import 'emails/emails_screen.dart';
import 'more_screen.dart';

class HomeScreen extends StatefulWidget {
  final ThemeService themeService;
  const HomeScreen({super.key, required this.themeService});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _idx = 0;
  int _activitySubTab = 0;
  int? _activityFocusItemId;
  int? _emailFocusItemId;
  int _focusRequestToken = 0;
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh UI on day/date rollover or return from background
      AutoBackupService.runCatchUpIfNeeded();
      setState(() {});
    }
  }

  static Color _getTabColor(int index, ColorScheme cs, bool isDark) {
    switch (index) {
      case 0: // Home
        return cs.primary;
      case 1: // Inventory
        return isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
      case 2: // Activity
        return isDark ? const Color(0xFFBA68C8) : const Color(0xFF8E24AA);
      case 3: // Emails
        return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
      case 4: // More
        return cs.tertiary;
      default:
        return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    final screens = [
      DashboardScreen(onSwitchTab: (i, {int subTab = 0, int? focusItemId}) {
        setState(() {
          _idx = i;
          _visited.add(i);
          if (focusItemId != null) {
            _focusRequestToken++;
          }
          if (i == 2) {
            _activitySubTab = subTab;
            _activityFocusItemId = focusItemId;
          } else if (i == 3) {
            _emailFocusItemId = focusItemId;
          }
        });
      }),
      _visited.contains(1) ? const InventoryScreen() : const SizedBox.shrink(),
      _visited.contains(2)
          ? ActivityScreen(
              initialTab: _activitySubTab,
              focusItemId: _activityFocusItemId,
              focusRequestToken: _focusRequestToken,
            )
          : const SizedBox.shrink(),
      _visited.contains(3)
          ? EmailsScreen(
              initialItemId: _emailFocusItemId,
              focusRequestToken: _focusRequestToken,
            )
          : const SizedBox.shrink(),
      _visited.contains(4)
          ? MoreScreen(themeService: widget.themeService)
          : const SizedBox.shrink(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope(
        canPop: _idx == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }
          setState(() => _idx = 0);
        },
        child: Scaffold(
          extendBody: true,
          body: HomeShellScope(
            bottomInset: 96.0,
            child: FadeIndexedStack(index: _idx, children: screens),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  elevation: 0,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Theme(
                      data: theme.copyWith(
                        splashFactory: NoSplash.splashFactory,
                        highlightColor: Colors.transparent,
                        splashColor: Colors.transparent,
                      ),
                      child: NavigationBarTheme(
                        data: NavigationBarThemeData(
                          height: 64,
                          indicatorColor: _getTabColor(_idx, cs, isDark)
                              .withValues(alpha: isDark ? 0.22 : 0.16),
                          indicatorShape: const RoundedSquareBorder(
                            borderRadius: 14,
                            size: 40,
                          ),
                          overlayColor: WidgetStateProperty.all(Colors.transparent),
                          iconTheme: WidgetStateProperty.resolveWith((states) {
                            return const IconThemeData(size: 24);
                          }),
                        ),
                        child: NavigationBar(
                          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                          selectedIndex: _idx,
                          animationDuration: const Duration(milliseconds: 120),
                          onDestinationSelected: (i) {
                            AppHaptics.tap(context, HapticStrength.selection);
                            setState(() {
                              _idx = i;
                              _visited.add(i);
                            });
                          },
                          destinations: [
                            NavigationDestination(
                              icon: Icon(
                                Icons.home_outlined,
                                color: _getTabColor(0, cs, isDark).withValues(alpha: 0.6),
                              ),
                              selectedIcon: Icon(
                                Icons.home,
                                color: _getTabColor(0, cs, isDark),
                              ),
                              label: 'Home',
                            ),
                            NavigationDestination(
                              icon: Icon(
                                Icons.inventory_2_outlined,
                                color: _getTabColor(1, cs, isDark).withValues(alpha: 0.6),
                              ),
                              selectedIcon: Icon(
                                Icons.inventory_2,
                                color: _getTabColor(1, cs, isDark),
                              ),
                              label: 'Inventory',
                            ),
                            NavigationDestination(
                              icon: Icon(
                                Icons.explore_outlined,
                                color: _getTabColor(2, cs, isDark).withValues(alpha: 0.6),
                              ),
                              selectedIcon: Icon(
                                Icons.explore,
                                color: _getTabColor(2, cs, isDark),
                              ),
                              label: 'Activity',
                            ),
                            NavigationDestination(
                              icon: Icon(
                                Icons.alternate_email_rounded,
                                color: _getTabColor(3, cs, isDark).withValues(alpha: 0.6),
                              ),
                              selectedIcon: Icon(
                                Icons.mark_email_read_rounded,
                                color: _getTabColor(3, cs, isDark),
                              ),
                              label: 'Emails',
                            ),
                            NavigationDestination(
                              icon: Icon(
                                Icons.grid_view_outlined,
                                color: _getTabColor(4, cs, isDark).withValues(alpha: 0.6),
                              ),
                              selectedIcon: Icon(
                                Icons.grid_view_rounded,
                                color: _getTabColor(4, cs, isDark),
                              ),
                              label: 'More',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration, value: 1.0);
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: IndexedStack(
        index: widget.index,
        children: widget.children,
      ),
    );
  }
}

/// Provides the shell's bottom inset (for navigation bar padding)
/// to children inside the IndexedStack shell.
class HomeShellScope extends InheritedWidget {
  final double bottomInset;

  const HomeShellScope({
    super.key,
    required this.bottomInset,
    required super.child,
  });

  static double of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HomeShellScope>();
    return scope?.bottomInset ?? 0.0;
  }

  @override
  bool updateShouldNotify(HomeShellScope oldWidget) =>
      bottomInset != oldWidget.bottomInset;
}
