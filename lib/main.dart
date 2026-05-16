import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/theme_service.dart';
import 'services/company_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  // Pre-load services
  await CompanyService().load();
  runApp(const InventoryaApp());
}

class InventoryaApp extends StatefulWidget {
  const InventoryaApp({super.key});
  @override
  State<InventoryaApp> createState() => _InventoryaAppState();
}

class _InventoryaAppState extends State<InventoryaApp> {
  final ThemeService _theme = ThemeService();
  bool _onboarded = CompanyService().onboarded;

  @override
  void initState() {
    super.initState();
    _theme.addListener(_rebuild);
  }

  @override
  void dispose() { _theme.removeListener(_rebuild); super.dispose(); }

  void _rebuild() => setState(() {});

  void _finishOnboarding() => setState(() => _onboarded = true);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventorya',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _theme.isDark ? ThemeMode.dark : ThemeMode.light,
      // Faster page transitions
      builder: (context, child) => child!,
      navigatorObservers: const [],
      home: _onboarded
        ? HomeScreen(themeService: _theme)
        : OnboardingScreen(onDone: _finishOnboarding),
    );
  }
}
