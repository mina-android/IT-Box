// lib/services/auto_backup_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

class AutoBackupService {
  static const String prefAutoBackupEnabled = 'auto_backup_enabled';
  static const String prefLastBackupTimestamp = 'auto_backup_last_run';
  static const String autoBackupDirName = 'itbox_auto_backups';
  static const int maxRollingBackups = 7;

  final DatabaseHelper _db = DatabaseHelper();

  /// Check if automated backup is due (runs once per 24 hours if enabled).
  Future<void> runIfDue() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(prefAutoBackupEnabled) ?? true;
    if (!isEnabled) return;

    final lastRunStr = prefs.getString(prefLastBackupTimestamp);
    if (lastRunStr != null) {
      final lastRun = DateTime.tryParse(lastRunStr);
      if (lastRun != null) {
        final hoursSince = DateTime.now().difference(lastRun).inHours;
        if (hoursSince < 24) {
          // Backup not due yet
          return;
        }
      }
    }

    await performAutoBackup();
  }

  /// Perform a silent, non-blocking background snapshot of all 21 tables.
  Future<File?> performAutoBackup() async {
    try {
      final jsonStr = await _db.exportJson();

      final docDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docDir.path}/$autoBackupDirName');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFile = File('${backupDir.path}/itbox_autobackup_$dateStr.json');
      await backupFile.writeAsString(jsonStr);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefLastBackupTimestamp, DateTime.now().toIso8601String());

      // Prune rolling backups older than 7 copies
      await _pruneOldBackups(backupDir);

      debugPrint('AutoBackupService: Successfully created auto-backup at ${backupFile.path}');
      return backupFile;
    } catch (e, stack) {
      debugPrint('AutoBackupService error: $e\n$stack');
      return null;
    }
  }

  /// List available auto-backup files.
  Future<List<File>> getAvailableAutoBackups() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docDir.path}/$autoBackupDirName');
      if (!await backupDir.exists()) return [];

      final files = await backupDir.list().where((f) => f is File && f.path.endsWith('.json')).toList();
      final fileList = files.cast<File>();
      fileList.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return fileList;
    } catch (_) {
      return [];
    }
  }

  Future<void> _pruneOldBackups(Directory dir) async {
    try {
      final files = await dir.list().where((f) => f is File && f.path.endsWith('.json')).toList();
      final fileList = files.cast<File>();
      fileList.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (fileList.length > maxRollingBackups) {
        for (int i = maxRollingBackups; i < fileList.length; i++) {
          await fileList[i].delete();
        }
      }
    } catch (e) {
      debugPrint('AutoBackupService prune error: $e');
    }
  }
}
