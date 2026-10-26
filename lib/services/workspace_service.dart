// lib/services/workspace_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../database/database_helper.dart';

class WorkspaceInfo {
  final String id;
  final String name;
  final String dbFileName;

  const WorkspaceInfo({
    required this.id,
    required this.name,
    required this.dbFileName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'db_file': dbFileName,
      };

  factory WorkspaceInfo.fromMap(Map<String, dynamic> map) => WorkspaceInfo(
        id: map['id'] as String,
        name: map['name'] as String,
        dbFileName: map['db_file'] as String,
      );
}

class WorkspaceService extends ChangeNotifier {
  static final WorkspaceService _instance = WorkspaceService._internal();
  factory WorkspaceService() => _instance;
  WorkspaceService._internal();

  static const String prefWorkspacesKey = 'app_workspaces_list';
  static const String prefActiveWorkspaceKey = 'app_active_workspace_id';

  List<WorkspaceInfo> _workspaces = [
    const WorkspaceInfo(id: 'default', name: 'Primary HQ', dbFileName: 'inventory.db'),
  ];
  String _activeId = 'default';

  List<WorkspaceInfo> get workspaces => List.unmodifiable(_workspaces);
  String get activeId => _activeId;
  WorkspaceInfo get activeWorkspace =>
      _workspaces.firstWhere((w) => w.id == _activeId, orElse: () => _workspaces.first);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(prefWorkspacesKey);
    if (jsonList != null && jsonList.isNotEmpty) {
      _workspaces = jsonList
          .map((s) => WorkspaceInfo.fromMap(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    }
    _activeId = prefs.getString(prefActiveWorkspaceKey) ?? 'default';
    if (!_workspaces.any((w) => w.id == _activeId)) {
      _activeId = _workspaces.first.id;
    }
    notifyListeners();
  }

  Future<void> createWorkspace(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final id = 'ws_${DateTime.now().millisecondsSinceEpoch}';
    final dbFile = 'inventory_$id.db';

    final ws = WorkspaceInfo(id: id, name: cleanName, dbFileName: dbFile);
    _workspaces.add(ws);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> switchWorkspace(String workspaceId) async {
    final target = _workspaces.firstWhere((w) => w.id == workspaceId, orElse: () => _workspaces.first);
    if (target.id == _activeId) return;

    _activeId = target.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefActiveWorkspaceKey, _activeId);

    // Switch underlying Drift database isolate & recreate tables
    await AppDatabase.switchDatabaseInstance(target.dbFileName);

    // Notify DatabaseHelper tables changed to refresh all active UI streams
    DatabaseHelper().notifyTableChanged('laptops');
    notifyListeners();
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    if (workspaceId == 'default' || _workspaces.length <= 1) return;

    _workspaces.removeWhere((w) => w.id == workspaceId);
    if (_activeId == workspaceId) {
      await switchWorkspace(_workspaces.first.id);
    } else {
      await _saveToPrefs();
      notifyListeners();
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _workspaces.map((w) => jsonEncode(w.toMap())).toList();
    await prefs.setStringList(prefWorkspacesKey, jsonList);
    await prefs.setString(prefActiveWorkspaceKey, _activeId);
  }
}
