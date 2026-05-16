import 'package:shared_preferences/shared_preferences.dart';

class CompanyService {
  static final CompanyService _i = CompanyService._();
  factory CompanyService() => _i;
  CompanyService._();

  static const _keyName = 'company_name';
  static const _keyOnboarded = 'onboarding_done';

  String _name = '';
  bool _onboarded = false;

  String get name => _name;
  bool get onboarded => _onboarded;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _name = p.getString(_keyName) ?? '';
    _onboarded = p.getBool(_keyOnboarded) ?? false;
  }

  Future<void> setCompanyName(String name) async {
    _name = name.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyName, _name);
  }

  Future<void> completeOnboarding(String companyName) async {
    await setCompanyName(companyName);
    _onboarded = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyOnboarded, true);
  }
}
