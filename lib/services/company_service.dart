import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../database/database_helper.dart';
import 'currency_service.dart';
import 'document_storage_service.dart';
import 'notification_service.dart';

class OrganizationProfile {
  final String id;
  final String name;
  final String logoPath;
  final String dbFileName;
  final String createdAt;

  const OrganizationProfile({
    required this.id,
    required this.name,
    required this.logoPath,
    required this.dbFileName,
    required this.createdAt,
  });

  OrganizationProfile copyWith({
    String? name,
    String? logoPath,
  }) {
    return OrganizationProfile(
      id: id,
      name: name ?? this.name,
      logoPath: logoPath ?? this.logoPath,
      dbFileName: dbFileName,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'logo_path': logoPath,
        'db_file': dbFileName,
        'created_at': createdAt,
      };

  factory OrganizationProfile.fromMap(Map<String, dynamic> map) => OrganizationProfile(
        id: map['id'] as String? ?? 'default',
        name: map['name'] as String? ?? '',
        logoPath: map['logo_path'] as String? ?? '',
        dbFileName: map['db_file'] as String? ?? 'itbox.db',
        createdAt: map['created_at'] as String? ?? '',
      );
}

class CompanyService extends ChangeNotifier {
  static final CompanyService _i = CompanyService._();
  factory CompanyService() => _i;
  CompanyService._();

  static const _keyName = 'company_name';
  static const _keyOnboarded = 'onboarding_done';
  static const _keyLogo = 'company_logo_path';
  static const _keyOrgsList = 'app_organizations_list';
  static const _keyActiveOrgId = 'app_active_organization_id';

  List<OrganizationProfile> _organizations = [];
  String _activeOrgId = 'default';
  String _name = '';
  bool _onboarded = false;
  String _logoPath = '';
  bool _hasLogo = false;

  List<OrganizationProfile> get organizations => List.unmodifiable(_organizations);
  String get activeOrganizationId => _activeOrgId;
  OrganizationProfile get activeOrganization {
    return _organizations.firstWhere(
      (o) => o.id == _activeOrgId,
      orElse: () => OrganizationProfile(
        id: 'default',
        name: _name.isNotEmpty ? _name : 'Primary Organization',
        logoPath: _logoPath,
        dbFileName: 'itbox.db',
        createdAt: '',
      ),
    );
  }

  String get name => _name;
  bool get onboarded => _onboarded;
  String get logoPath => _logoPath;
  bool get hasLogo => _hasLogo;

  void _updateHasLogo() {
    _hasLogo = _logoPath.isNotEmpty && File(_logoPath).existsSync();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final legacyName = p.getString(_keyName) ?? '';
    _onboarded = p.getBool(_keyOnboarded) ?? false;
    final legacyLogo = p.getString(_keyLogo) ?? '';

    final jsonList = p.getStringList(_keyOrgsList);
    if (jsonList != null && jsonList.isNotEmpty) {
      _organizations = jsonList
          .map((s) => OrganizationProfile.fromMap(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } else {
      _organizations = [
        OrganizationProfile(
          id: 'default',
          name: legacyName.isNotEmpty ? legacyName : 'Primary Organization',
          logoPath: legacyLogo,
          dbFileName: 'itbox.db',
          createdAt: DateTime.now().toIso8601String(),
        ),
      ];
      await _saveOrganizations(p);
    }

    _activeOrgId = p.getString(_keyActiveOrgId) ?? _organizations.first.id;
    if (!_organizations.any((o) => o.id == _activeOrgId)) {
      _activeOrgId = _organizations.first.id;
    }

    final active = activeOrganization;
    _name = active.name;
    _logoPath = active.logoPath;
    _updateHasLogo();

    // Ensure AppDatabase opens the active organization's database on startup
    AppDatabase.activeDatabaseFile = active.dbFileName;
    notifyListeners();
  }

  Future<void> _saveOrganizations(SharedPreferences p) async {
    final jsonList = _organizations.map((o) => jsonEncode(o.toMap())).toList();
    await p.setStringList(_keyOrgsList, jsonList);
    await p.setString(_keyActiveOrgId, _activeOrgId);
  }

  Future<void> setCompanyName(String name) async {
    _name = name.trim();
    final idx = _organizations.indexWhere((o) => o.id == _activeOrgId);
    if (idx != -1) {
      _organizations[idx] = _organizations[idx].copyWith(name: _name);
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyName, _name);
    await _saveOrganizations(p);
    notifyListeners();
  }

  Future<void> setCompanyLogo(String path) async {
    _logoPath = path.trim();
    _updateHasLogo();
    final idx = _organizations.indexWhere((o) => o.id == _activeOrgId);
    if (idx != -1) {
      _organizations[idx] = _organizations[idx].copyWith(logoPath: _logoPath);
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyLogo, _logoPath);
    await _saveOrganizations(p);
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
    final idx = _organizations.indexWhere((o) => o.id == _activeOrgId);
    if (idx != -1) {
      _organizations[idx] = _organizations[idx].copyWith(logoPath: '');
    }
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyLogo);
    await _saveOrganizations(p);
    notifyListeners();
  }

  Future<OrganizationProfile> createOrganization({
    required String name,
    String logoPath = '',
    bool switchImmediately = true,
  }) async {
    final cleanName = name.trim();
    final id = 'org_${DateTime.now().millisecondsSinceEpoch}';
    final dbFile = 'itbox_$id.db';
    final org = OrganizationProfile(
      id: id,
      name: cleanName,
      logoPath: logoPath.trim(),
      dbFileName: dbFile,
      createdAt: DateTime.now().toIso8601String(),
    );

    _organizations.add(org);
    final p = await SharedPreferences.getInstance();
    await _saveOrganizations(p);

    if (switchImmediately) {
      await switchOrganization(org.id);
    } else {
      notifyListeners();
    }
    return org;
  }

  Future<void> switchOrganization(String orgId) async {
    final target = _organizations.firstWhere(
      (o) => o.id == orgId,
      orElse: () => _organizations.first,
    );
    if (target.id == _activeOrgId && AppDatabase.activeDatabaseFile == target.dbFileName) {
      return;
    }

    _activeOrgId = target.id;
    _name = target.name;
    _logoPath = target.logoPath;
    _updateHasLogo();

    final p = await SharedPreferences.getInstance();
    await p.setString(_keyActiveOrgId, _activeOrgId);
    await p.setString(_keyName, _name);
    if (_logoPath.isNotEmpty) {
      await p.setString(_keyLogo, _logoPath);
    } else {
      await p.remove(_keyLogo);
    }

    await AppDatabase.switchDatabaseInstance(target.dbFileName);
    await DatabaseHelper().onDatabaseSwitched();
    await CurrencyService().reloadForActiveOrganization();
    try {
      final logs = await DatabaseHelper().getBorrowLogs();
      await NotificationService().reconcileReminders(logs);
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> deleteOrganization(String orgId) async {
    if (orgId == 'default' || _organizations.length <= 1) {
      return false;
    }
    final idx = _organizations.indexWhere((o) => o.id == orgId);
    if (idx == -1) {
      return false;
    }
    final target = _organizations[idx];

    if (orgId == _activeOrgId) {
      final fallback = _organizations.firstWhere((o) => o.id != orgId);
      await switchOrganization(fallback.id);
    }

    _organizations.removeWhere((o) => o.id == orgId);
    final p = await SharedPreferences.getInstance();
    await _saveOrganizations(p);

    await AppDatabase.deleteDatabaseFile(target.dbFileName);
    await DocumentStorageService.deleteOrganizationDirectories(target.id);
    if (target.logoPath.isNotEmpty) {
      final logoFile = File(target.logoPath);
      if (logoFile.existsSync()) {
        try {
          logoFile.deleteSync();
        } catch (_) {}
      }
    }

    notifyListeners();
    return true;
  }

  Future<void> completeOnboarding(String companyName) async {
    await setCompanyName(companyName);
    _onboarded = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyOnboarded, true);
    notifyListeners();
  }
}
