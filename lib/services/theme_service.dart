import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal() { _load(); }

  static const _key = 'dark_mode';
  bool _dark = true;

  bool get isDark => _dark;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _dark = prefs.getBool(_key) ?? true;
    notifyListeners();
  }

  Future<void> toggle() async {
    _dark = !_dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _dark);
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    _dark = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _dark);
    notifyListeners();
  }
}
