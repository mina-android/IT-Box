// lib/services/workmanager_service.dart
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../database/app_database.dart';
import '../database/database_helper.dart';
import 'auto_backup_service.dart';
import 'company_service.dart';
import 'theme_service.dart';
import 'ticket_reminder_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == AutoBackupService.taskKey) {
        await Future.wait([
          CompanyService().load(),
          ThemeService().load(),
          TicketReminderService().load(),
        ]);
        final targetOrgId = inputData?['orgId'] as String?;
        if (targetOrgId != null && targetOrgId.isNotEmpty) {
          final targetOrg = CompanyService().organizations
              .where((o) => o.id == targetOrgId)
              .firstOrNull;
          if (targetOrg != null &&
              targetOrg.id != CompanyService().activeOrganizationId) {
            await AppDatabase.switchDatabaseInstance(targetOrg.dbFileName);
          }
        }
        await DatabaseHelper().init();
        final res = await AutoBackupService.runNow(
          BackupTrigger.scheduled,
          targetOrgId: targetOrgId,
        );
        return res.success || res.skipped;
      }
      return true;
    } catch (e, stack) {
      debugPrint('Workmanager task $task failed: $e\n$stack');
      return false;
    }
  });
}

class WorkmanagerService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    try {
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
      _initialized = true;
    } catch (e) {
      debugPrint('Workmanager initialization warning: $e');
    }
  }
}
