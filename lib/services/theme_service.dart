import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  String _themeMode = 'dark'; // system|light|dark
  String _themeSeed = 'violet';
  String _appFont = 'default';
  bool _amoledSurfaces = false;
  bool _dynamicColorEnabled = false;

  String get themeMode => _themeMode;
  String get themeSeed => _themeSeed;
  String get appFont => _appFont;
  bool get amoledSurfaces => _amoledSurfaces;
  bool get dynamicColorEnabled => _dynamicColorEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Legacy mapping (just in case)
    if (!prefs.containsKey('themeMode') && prefs.containsKey('dark_mode')) {
      _themeMode = (prefs.getBool('dark_mode') ?? true) ? 'dark' : 'light';
    } else {
      _themeMode = prefs.getString('themeMode') ?? 'dark';
    }

    _themeSeed = prefs.getString('themeSeed') ?? 'violet';
    _appFont = prefs.getString('appFont') ?? 'default';
    _amoledSurfaces = prefs.getBool('amoledSurfaces') ?? false;
    _dynamicColorEnabled = prefs.getBool('dynamicColorEnabled') ?? false;
    notifyListeners();
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    switch (key) {
      case 'themeMode':
        _themeMode = value as String;
        await prefs.setString('themeMode', _themeMode);
        break;
      case 'themeSeed':
        _themeSeed = value as String;
        await prefs.setString('themeSeed', _themeSeed);
        break;
      case 'appFont':
        _appFont = value as String;
        await prefs.setString('appFont', _appFont);
        break;
      case 'amoledSurfaces':
        _amoledSurfaces = value as bool;
        await prefs.setBool('amoledSurfaces', _amoledSurfaces);
        break;
      case 'dynamicColorEnabled':
        _dynamicColorEnabled = value as bool;
        await prefs.setBool('dynamicColorEnabled', _dynamicColorEnabled);
        break;
    }
    notifyListeners();
  }
}
