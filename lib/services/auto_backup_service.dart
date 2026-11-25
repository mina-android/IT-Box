// lib/services/auto_backup_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:itbox_saf/itbox_saf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../database/database_helper.dart';
import 'company_service.dart';

enum BackupTrigger { scheduled, catchUp, manual }

class AutoBackupResult {
  final bool success;
  final bool skipped;
  final String? fileName;
  final int? size;
  final String? error;

  const AutoBackupResult({
    required this.success,
    this.skipped = false,
    this.fileName,
    this.size,
    this.error,
  });
}

class AutoBackupState {
  final bool enabled;
  final String folderUri;
  final String folderName;
  final int retention;
  final bool encrypted;
  final int lastSuccessMs;
  final int lastAttemptMs;
  final String lastError;
  final String lastFile;
  final int lastSize;
  final int nextRunMs;

  const AutoBackupState({
    required this.enabled,
    required this.folderUri,
    required this.folderName,
    required this.retention,
    required this.encrypted,
    required this.lastSuccessMs,
    required this.lastAttemptMs,
    required this.lastError,
    required this.lastFile,
    required this.lastSize,
    required this.nextRunMs,
  });

  static String _k(String base, String orgId) {
    if (orgId.isEmpty || orgId == 'default') {
      return base;
    }
    return '${base}_$orgId';
  }

  factory AutoBackupState.fromPrefs(SharedPreferences prefs, {String? orgId}) {
    final id = orgId ?? CompanyService().activeOrganizationId;
    return AutoBackupState(
      enabled: prefs.getBool(_k('itbox_ab_enabled', id)) ?? false,
      folderUri: prefs.getString(_k('itbox_ab_tree_uri', id)) ?? '',
      folderName: prefs.getString(_k('itbox_ab_folder_name', id)) ?? '',
      retention: prefs.getInt(_k('itbox_ab_retention', id)) ?? 7,
      encrypted: prefs.getBool(_k('itbox_ab_encrypted', id)) ?? false,
      lastSuccessMs: prefs.getInt(_k('itbox_ab_last_success_ms', id)) ?? 0,
      lastAttemptMs: prefs.getInt(_k('itbox_ab_last_attempt_ms', id)) ?? 0,
      lastError: prefs.getString(_k('itbox_ab_last_error', id)) ?? '',
      lastFile: prefs.getString(_k('itbox_ab_last_file', id)) ?? '',
      lastSize: prefs.getInt(_k('itbox_ab_last_size', id)) ?? 0,
      nextRunMs: prefs.getInt(_k('itbox_ab_next_run_ms', id)) ?? 0,
    );
  }
}

class AutoBackupService {
  static const String taskKey = 'com.ma.itbox.autoBackupTask';
  static const String channelId = 'itbox_backup';

  static String _k(String base, String orgId) {
    if (orgId.isEmpty || orgId == 'default') {
      return base;
    }
    return '${base}_$orgId';
  }

  static String secretKeyForOrg(String orgId) => _k('itbox_ab_encryption_password', orgId);

  static String _orgPrefix(String orgId) {
    final clean = orgId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'itbox_auto_${clean.isEmpty ? 'default' : clean}_';
  }

  /// Computes next 02:00 local time.
  static DateTime nextRunAt(DateTime now, {int hour = 2}) {
    final today = DateTime(now.year, now.month, now.day, hour);
    return today.isAfter(now)
        ? today
        : DateTime(now.year, now.month, now.day + 1, hour);
  }

  static Future<AutoBackupState> loadState({String? orgId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return AutoBackupState.fromPrefs(prefs, orgId: orgId);
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final orgId = CompanyService().activeOrganizationId;
    await prefs.setBool(_k('itbox_ab_enabled', orgId), enabled);
    await scheduleNext(force: true);
  }

  static Future<bool> chooseFolder() async {
    final dir = await ItboxSaf.pickDirectory();
    if (dir == null) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final orgId = CompanyService().activeOrganizationId;
    await prefs.setString(_k('itbox_ab_tree_uri', orgId), dir.uri);
    await prefs.setString(_k('itbox_ab_folder_name', orgId), dir.name);
    await prefs.remove(_k('itbox_ab_last_error', orgId));
    return true;
  }

  static Future<void> setRetention(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final orgId = CompanyService().activeOrganizationId;
    await prefs.setInt(_k('itbox_ab_retention', orgId), count);
  }

  static Future<void> setEncryption({required bool on, String? password}) async {
    final prefs = await SharedPreferences.getInstance();
    final orgId = CompanyService().activeOrganizationId;
    final sKey = secretKeyForOrg(orgId);
    if (on) {
      if (password == null || password.isEmpty) {
        throw ArgumentError('Encryption password cannot be empty.');
      }
      final saved = await ItboxSaf.setSecret(sKey, password);
      if (!saved) {
        throw StateError('Unable to store encryption password in Android Keystore.');
      }
      await prefs.setBool(_k('itbox_ab_encrypted', orgId), true);
    } else {
      await ItboxSaf.clearSecret(sKey);
      await prefs.setBool(_k('itbox_ab_encrypted', orgId), false);
    }
  }

  static Future<void> scheduleNext({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final orgId = CompanyService().activeOrganizationId;
    final enabled = prefs.getBool(_k('itbox_ab_enabled', orgId)) ?? false;
    final uniqueName = 'itbox_auto_backup_$orgId';

    if (!enabled) {
      try {
        await Workmanager().cancelByUniqueName(uniqueName);
      } catch (_) {}
      return;
    }

    final now = DateTime.now();
    final storedNextMs = prefs.getInt(_k('itbox_ab_next_run_ms', orgId)) ?? 0;
    final storedTzOffset = prefs.getInt(_k('itbox_ab_next_run_tz_offset_min', orgId)) ?? 0;
    final currentTzOffset = now.timeZoneOffset.inMinutes;

    if (!force &&
        storedNextMs > now.millisecondsSinceEpoch &&
        storedTzOffset == currentTzOffset) {
      return;
    }

    final next = nextRunAt(now);
    final delay = next.difference(now);

    try {
      await Workmanager().registerOneOffTask(
        uniqueName,
        taskKey,
        initialDelay: delay,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        inputData: {'orgId': orgId},
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
          requiresStorageNotLow: true,
        ),
        backoffPolicy: BackoffPolicy.exponential,
      );

      await prefs.setInt(_k('itbox_ab_next_run_ms', orgId), next.millisecondsSinceEpoch);
      await prefs.setInt(_k('itbox_ab_next_run_tz_offset_min', orgId), currentTzOffset);
    } catch (e) {
      debugPrint('Workmanager scheduleNext error: $e');
    }
  }

  static Future<AutoBackupResult> runNow(BackupTrigger trigger, {String? targetOrgId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final orgId = (targetOrgId != null && targetOrgId.isNotEmpty)
        ? targetOrgId
        : CompanyService().activeOrganizationId;

    final enabled = prefs.getBool(_k('itbox_ab_enabled', orgId)) ?? false;
    if (!enabled && trigger != BackupTrigger.manual) {
      return const AutoBackupResult(success: false, skipped: true, error: 'disabled');
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lockKey = _k('itbox_ab_running_since_ms', orgId);
    final runningSince = prefs.getInt(lockKey) ?? 0;
    if (runningSince > 0 && (nowMs - runningSince) < 600000) {
      return const AutoBackupResult(success: false, skipped: true, error: 'already_running');
    }
    await prefs.setInt(lockKey, nowMs);
    await prefs.setInt(_k('itbox_ab_last_attempt_ms', orgId), nowMs);

    try {
      final lastSuccessMs = prefs.getInt(_k('itbox_ab_last_success_ms', orgId)) ?? 0;
      if (trigger != BackupTrigger.manual &&
          lastSuccessMs > 0 &&
          (nowMs - lastSuccessMs) < 72000000) {
        await prefs.remove(lockKey);
        return const AutoBackupResult(success: true, skipped: true, error: 'recently_completed');
      }

      final treeUri = prefs.getString(_k('itbox_ab_tree_uri', orgId)) ?? '';
      if (treeUri.isEmpty) {
        await _recordError(prefs, orgId, 'No backup folder selected', notify: true);
        return const AutoBackupResult(success: false, error: 'No backup folder selected');
      }

      final access = await ItboxSaf.checkAccess(treeUri);
      if (!access.ok) {
        await _recordError(prefs, orgId, access.reason, notify: true);
        return AutoBackupResult(success: false, error: access.reason);
      }

      final encrypted = prefs.getBool(_k('itbox_ab_encrypted', orgId)) ?? false;
      String? password;
      if (encrypted) {
        password = await ItboxSaf.getSecret(secretKeyForOrg(orgId));
        if (password == null || password.isEmpty) {
          await _recordError(prefs, orgId, 'Encryption password missing from Keystore', notify: true);
          return const AutoBackupResult(success: false, error: 'Encryption password missing');
        }
      }

      final jsonStr = await DatabaseHelper().exportJson(
        passphrase: password,
        includeVaultBinaries: true,
        organizationId: orgId,
      );

      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final ext = encrypted ? 'itbox.enc' : 'json';
      final prefix = _orgPrefix(orgId);
      final fileName = '$prefix$dateStr.$ext';
      final mime = encrypted ? 'application/octet-stream' : 'application/json';
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final writeResult = await ItboxSaf.writeFile(
        treeUri: treeUri,
        name: fileName,
        mime: mime,
        bytes: bytes,
      );

      final retention = prefs.getInt(_k('itbox_ab_retention', orgId)) ?? 7;
      final files = await ItboxSaf.listFiles(treeUri: treeUri, prefix: prefix);
      files.sort((a, b) => b.name.compareTo(a.name));
      if (files.length > retention) {
        for (final file in files.sublist(retention)) {
          try {
            await ItboxSaf.deleteFile(file.uri);
          } catch (_) {}
        }
      }

      await prefs.setInt(_k('itbox_ab_last_success_ms', orgId), DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_k('itbox_ab_last_file', orgId), fileName);
      await prefs.setInt(_k('itbox_ab_last_size', orgId), writeResult.size);
      await prefs.remove(_k('itbox_ab_last_error', orgId));

      return AutoBackupResult(
        success: true,
        fileName: fileName,
        size: writeResult.size,
      );
    } catch (e, stack) {
      debugPrint('AutoBackupService execution failed: $e\n$stack');
      await _recordError(prefs, orgId, e.toString(), notify: true);
      return AutoBackupResult(success: false, error: e.toString());
    } finally {
      await prefs.remove(lockKey);
      if (trigger == BackupTrigger.scheduled) {
        await scheduleNext(force: true);
      }
    }
  }

  static Future<void> runCatchUpIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final orgId = CompanyService().activeOrganizationId;
    final enabled = prefs.getBool(_k('itbox_ab_enabled', orgId)) ?? false;
    if (!enabled) {
      return;
    }

    final now = DateTime.now();
    final today2am = DateTime(now.year, now.month, now.day, 2);

    if (now.isAfter(today2am)) {
      final lastSuccessMs = prefs.getInt(_k('itbox_ab_last_success_ms', orgId)) ?? 0;
      if (lastSuccessMs < today2am.millisecondsSinceEpoch) {
        runNow(BackupTrigger.catchUp);
      }
    }

    scheduleNext(force: false);
  }

  static Future<void> _recordError(
    SharedPreferences prefs,
    String orgId,
    String error, {
    bool notify = false,
  }) async {
    await prefs.setString(_k('itbox_ab_last_error', orgId), error);
    if (notify) {
      await _showFailureNotification(error);
    }
  }

  static Future<void> _showFailureNotification(String error) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await plugin.initialize(
        settings: const InitializationSettings(android: androidSettings),
      );
      const androidDetails = AndroidNotificationDetails(
        channelId,
        'Automatic Backup Alerts',
        channelDescription: 'Notifications for automated backup status and error alerts',
        importance: Importance.high,
        priority: Priority.high,
      );
      await plugin.show(
        id: 99201,
        title: 'IT Box Auto-Backup Failed',
        body: 'Scheduled backup could not complete: $error',
        notificationDetails: const NotificationDetails(android: androidDetails),
      );
    } catch (_) {}
  }
}
