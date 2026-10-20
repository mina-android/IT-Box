import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompanyService extends ChangeNotifier {
  static final CompanyService _i = CompanyService._();
  factory CompanyService() => _i;
  CompanyService._();

  static const _keyName = 'company_name';
  static const _keyOnboarded = 'onboarding_done';
  static const _keyLogo = 'company_logo_path';

  String _name = '';
  bool _onboarded = false;
  String _logoPath = '';
  bool _hasLogo = false;

  String get name => _name;
  bool get onboarded => _onboarded;
  String get logoPath => _logoPath;
  bool get hasLogo => _hasLogo;

  void _updateHasLogo() {
    _hasLogo = _logoPath.isNotEmpty && File(_logoPath).existsSync();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _name = p.getString(_keyName) ?? '';
    _onboarded = p.getBool(_keyOnboarded) ?? false;
    _logoPath = p.getString(_keyLogo) ?? '';
    _updateHasLogo();
    notifyListeners();
  }

  Future<void> setCompanyName(String name) async {
    _name = name.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyName, _name);
    notifyListeners();
  }

  Future<void> setCompanyLogo(String path) async {
    _logoPath = path.trim();
    _updateHasLogo();
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyLogo, _logoPath);
    notifyListeners();
  }

  Future<void> removeCompanyLogo() async {
    if (_logoPath.isNotEmpty) {
      final f = File(_logoPath);
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
    _logoPath = '';
    _hasLogo = false;
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyLogo);
    notifyListeners();
  }

  Future<void> completeOnboarding(String companyName) async {
    await setCompanyName(companyName);
    _onboarded = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyOnboarded, true);
    notifyListeners();
  }
}
