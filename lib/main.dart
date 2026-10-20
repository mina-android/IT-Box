import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'services/theme_service.dart';
import 'services/company_service.dart';
import 'services/notification_service.dart';
import 'database/database_helper.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/network_tools/network_scanner_screen.dart';
import 'screens/barcode_scanner/barcode_scanner_screen.dart';
import 'screens/borrowed/add_borrow_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _cleanupOldTempFiles() async {
  try {
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final files = tempDir.listSync();
    for (final entity in files) {
      if (entity is File) {
        final ext = entity.path.toLowerCase();
        if (ext.endsWith('.pdf') || ext.endsWith('.xlsx') || ext.endsWith('.png') || ext.endsWith('.csv')) {
          final stat = await entity.stat();
          if (now.difference(stat.modified).inHours >= 24) {
            await entity.delete();
          }
        }
      }
    }
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));

  // Pre-load services concurrently
  await Future.wait([
    ThemeService().load(),
    CompanyService().load(),
    NotificationService().init(),
    DatabaseHelper().init(),
  ]);

  _cleanupOldTempFiles();

  const QuickActions quickActions = QuickActions();
  quickActions.initialize((shortcutType) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    switch (shortcutType) {
      case 'action_scanner':
        nav.push(MaterialPageRoute(builder: (_) => const NetworkScannerScreen()));
        break;
      case 'action_scan_tag':
        nav.push(MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
        break;
      case 'action_new_borrow':
        nav.push(MaterialPageRoute(builder: (_) => const AddBorrowScreen()));
        break;
    }
  });

  quickActions.setShortcutItems(<ShortcutItem>[
    const ShortcutItem(
      type: 'action_scanner',
      localizedTitle: 'Network Scanner',
      icon: 'ic_launcher',
    ),
    const ShortcutItem(
      type: 'action_scan_tag',
      localizedTitle: 'Scan Asset Tag',
      icon: 'ic_launcher',
    ),
    const ShortcutItem(
      type: 'action_new_borrow',
      localizedTitle: 'New Checkout',
      icon: 'ic_launcher',
    ),
  ]);

  runApp(const ITBoxApp());
}

class ITBoxApp extends StatefulWidget {
  const ITBoxApp({super.key});
  @override
  State<ITBoxApp> createState() => _ITBoxAppState();
}

class _ITBoxAppState extends State<ITBoxApp> {
  final ThemeService _theme = ThemeService();
  bool _onboarded = CompanyService().onboarded;

  @override
  void initState() {
    super.initState();
    _theme.addListener(_rebuild);
  }

  @override
  void dispose() {
    _theme.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _finishOnboarding() => setState(() => _onboarded = true);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final usesDynamic = _theme.dynamicColorEnabled;

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'IT Box',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(
            seed: _theme.themeSeed,
            dark: false,
            amoled: false,
            appFont: _theme.appFont,
            dynamicScheme: usesDynamic ? lightDynamic : null,
          ),
          darkTheme: buildTheme(
            seed: _theme.themeSeed,
            dark: true,
            amoled: _theme.amoledSurfaces,
            appFont: _theme.appFont,
            dynamicScheme: usesDynamic ? darkDynamic : null,
          ),
          themeMode: resolveThemeMode(_theme.themeMode),
          color: _theme.themeMode == 'light' ? const Color(0xFFF8FAFC) : const Color(0xFF141218),
          builder: (context, child) => Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: child!,
          ),
          home: _onboarded
              ? HomeScreen(themeService: _theme)
              : OnboardingScreen(onDone: _finishOnboarding),
        );
      },
    );
  }
}
