import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itbox/database/app_database.dart';
import 'package:itbox/database/database_helper.dart';
import 'package:itbox/models/custody_document.dart';
import 'package:itbox/models/expense.dart';
import 'package:itbox/models/vault_document.dart';
import 'package:itbox/models/vendor_contact.dart';
import 'package:itbox/services/audit_export_service.dart';
import 'package:itbox/services/backup_crypto_service.dart';
import 'package:itbox/services/custody_pdf_service.dart';
import 'package:itbox/services/excel_import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDocsDir;
  late AppDatabase db;
  late DatabaseHelper helper;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDocsDir = await Directory.systemTemp.createTemp('itbox_test_docs_');

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDocsDir.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async => 'dev.fluttercommunity.plus/share/success',
    );

    db = AppDatabase(NativeDatabase.memory());
    AppDatabase.testInstance = db;
    helper = DatabaseHelper();
  });

  tearDown(() async {
    await db.close();
    AppDatabase.testInstance = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      null,
    );
    if (await tempDocsDir.exists()) {
      await tempDocsDir.delete(recursive: true);
    }
  });

  group('Schema v16 Custody Documents & Documents Vault', () {
    test('CustodyDocument multi-item CRUD, reactive stream, and PDF generation',
        () async {
      final emitted = <List<CustodyDocument>>[];
      final sub = helper.watchCustodyDocuments().listen(emitted.add);
      await pumpEventQueue();
      expect(emitted.last, isEmpty);

      final items = const [
        CustodyItem(
          deviceType: 'Laptop',
          deviceName: 'ThinkPad X1 Carbon Gen 12',
          deviceNumber: 'IT-L-042',
          serialNumber: 'PF4X9988',
          condition: 'New',
          extraSpecs: {'RAM': '32GB', 'Storage': '1TB NVMe'},
        ),
        CustodyItem(
          deviceType: 'MiFi',
          deviceName: 'Huawei 5G Mobile WiFi',
          deviceNumber: 'IT-M-011',
          serialNumber: 'HW991122',
          condition: 'Good / Verified',
        ),
      ];

      final doc = CustodyDocument(
        documentNumber: 'CUS-2026-0001',
        title: 'Engineering Onboarding Kit',
        sourceType: 'custom',
        employeeName: 'Omar Hassan',
        employeePhone: '+201000000001',
        employeeEmail: 'omar@company.com',
        handoverDate: '2026-11-24',
        dueDate: '2026-12-24',
        itemsJson: CustodyDocument.encodeItems(items),
        agreementText: 'Standard IT custody terms.',
        adminNotes: 'Includes USB-C dock and sleeve.',
      );

      final id = await helper.insertCustodyDocument(doc);
      await pumpEventQueue();
      expect(id, greaterThan(0));
      expect(emitted.last.length, 1);
      expect(emitted.last.first.items.length, 2);
      expect(emitted.last.first.items.first.extraSpecs['RAM'], '32GB');
      expect(emitted.last.first.adminNotes, 'Includes USB-C dock and sleeve.');

      final singleFile = await CustodyPdfService.generateAndSaveCustodyDocumentPdf(
        emitted.last.first,
      );
      expect(await singleFile.exists(), isTrue);
      final singleBytes = await singleFile.readAsBytes();
      expect(String.fromCharCodes(singleBytes.take(4)), '%PDF');

      final bulkFile = await CustodyPdfService.generateBulkCustodyDocumentsPdf([
        emitted.last.first,
        emitted.last.first.copyWith(
          documentNumber: 'CUS-2026-0002',
          title: 'Second Kit',
        ),
      ]);
      expect(await bulkFile.exists(), isTrue);
      final bulkBytes = await bulkFile.readAsBytes();
      expect(String.fromCharCodes(bulkBytes.take(4)), '%PDF');

      await helper.deleteCustodyDocument(id);
      await pumpEventQueue();
      expect(emitted.last, isEmpty);
      await sub.cancel();
    });

    test('VaultDocument CRUD and Expense receiptPath / Vendor slaTier',
        () async {
      final sampleFile = File('${tempDocsDir.path}/sample_contract.pdf');
      await sampleFile.writeAsBytes(utf8.encode('%PDF-1.4\n%test\n'));

      final vId = await helper.insertVaultDocument(VaultDocument(
        title: 'ISP Fiber SLA Contract',
        category: 'Contract',
        filePath: sampleFile.path,
        fileType: 'pdf',
        pageCount: 3,
        linkedEmployeeName: 'Omar Hassan',
        linkedAssetType: 'Router',
        linkedAssetLabel: 'RTR-CORE-01',
        notes: 'Annual renewal in Q4',
      ));
      expect(vId, greaterThan(0));

      final vaultDocs = await helper.getVaultDocuments();
      expect(vaultDocs.length, 1);
      expect(vaultDocs.first.category, 'Contract');
      expect(vaultDocs.first.linkedAssetLabel, 'RTR-CORE-01');

      final expId = await helper.insertExpense(Expense(
        item: 'NVMe SSD upgrade',
        price: 4500.0,
        details: 'Hardware',
        date: '2026-11-24',
        receiptPath: sampleFile.path,
      ));
      final expenses = await helper.getExpenses();
      expect(
        expenses.firstWhere((e) => e.id == expId).receiptPath,
        sampleFile.path,
      );

      final vcId = await helper.insertVendorContact(VendorContact(
        contactType: 'ISP',
        name: 'Orange Business',
        slaTier: 'Business Gold (4h)',
      ));
      final vendors = await helper.getVendorContacts();
      expect(
        vendors.firstWhere((v) => v.id == vcId).slaTier,
        'Business Gold (4h)',
      );
    });
  });

  group('BackupCryptoService & Base64 Vault/Receipt Backup Restore', () {
    test('BackupCryptoService uses Random.secure() salt & round-trips AES-256-GCM',
        () async {
      const payload = '{"schema_version":16,"test":"ok"}';
      final crypto = BackupCryptoService();
      final enc1 = await crypto.encryptBackup(payload, 'StrongPass123!');
      final enc2 = await crypto.encryptBackup(payload, 'StrongPass123!');
      expect(enc1, isNot(equals(enc2)));

      final dec1 = await crypto.decryptBackup(enc1, 'StrongPass123!');
      expect(dec1, payload);
    });

    test('Full JSON backup embeds and restores Vault & Receipt files', () async {
      final vaultSrc = File('${tempDocsDir.path}/vault_doc.pdf');
      await vaultSrc.writeAsBytes([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31]);
      final receiptSrc = File('${tempDocsDir.path}/receipt.png');
      await receiptSrc.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);

      await helper.insertVaultDocument(VaultDocument(
        title: 'Warranty Card',
        category: 'Warranty',
        filePath: vaultSrc.path,
        fileType: 'pdf',
      ));
      await helper.insertExpense(Expense(
        item: 'Cat6 patch pack',
        price: 250.0,
        details: 'Cables',
        date: '2026-11-24',
        receiptPath: receiptSrc.path,
      ));

      final backupJson = await helper.exportJson(includeVaultBinaries: true);
      final map = jsonDecode(backupJson) as Map<String, dynamic>;
      expect((map['vault_files'] as Map).isNotEmpty, isTrue);
      expect((map['receipt_files'] as Map).isNotEmpty, isTrue);

      await vaultSrc.delete();
      await receiptSrc.delete();
      await helper.importJson(backupJson);

      final restoredVault = await helper.getVaultDocuments();
      expect(restoredVault.length, 1);
      expect(await File(restoredVault.first.filePath).exists(), isTrue);

      final restoredExpenses = await helper.getExpenses();
      expect(restoredExpenses.length, 1);
      expect(await File(restoredExpenses.first.receiptPath).exists(), isTrue);
    });
  });

  group('Excel Import & Audit Export Verification', () {
    test('ExcelImportService imports VendorContacts, WifiNetworks, AccountPasswords, StaticIps',
        () async {
      final vExcel = Excel.createExcel();
      final vSheet = vExcel['Vendors'];
      vSheet.appendRow([
        TextCellValue('#'),
        TextCellValue('Type'),
        TextCellValue('Name'),
        TextCellValue('Company'),
        TextCellValue('Role'),
        TextCellValue('Phone'),
        TextCellValue('Email'),
        TextCellValue('Portal'),
        TextCellValue('Account'),
        TextCellValue('SLA'),
        TextCellValue('Notes'),
      ]);
      vSheet.appendRow([
        IntCellValue(1),
        TextCellValue('Vendor'),
        TextCellValue('Dell ProSupport'),
        TextCellValue('Dell'),
        TextCellValue('Support'),
        TextCellValue('19999'),
        TextCellValue('support@dell.com'),
        TextCellValue('https://dell.com'),
        TextCellValue('ACC-1'),
        TextCellValue('Next Business Day'),
        TextCellValue('Server coverage'),
      ]);

      final wExcel = Excel.createExcel();
      final wSheet = wExcel['WiFi'];
      wSheet.appendRow([
        TextCellValue('#'),
        TextCellValue('Network'),
        TextCellValue('Password'),
        TextCellValue('Phone'),
        TextCellValue('Location'),
        TextCellValue('AdminUser'),
        TextCellValue('AdminPass'),
        TextCellValue('Notes'),
      ]);
      wSheet.appendRow([
        IntCellValue(1),
        TextCellValue('Corp-Secure'),
        TextCellValue('WifiSecret!23'),
        TextCellValue(''),
        TextCellValue('HQ Floor 2'),
        TextCellValue('admin'),
        TextCellValue('adm123'),
        TextCellValue(''),
      ]);

      final aExcel = Excel.createExcel();
      final aSheet = aExcel['Accounts'];
      aSheet.appendRow([
        TextCellValue('#'),
        TextCellValue('Platform'),
        TextCellValue('Email/User'),
        TextCellValue('Password'),
      ]);
      aSheet.appendRow([
        IntCellValue(1),
        TextCellValue('Cloudflare'),
        TextCellValue('it@company.com'),
        TextCellValue('CfPassword!99'),
      ]);

      final iExcel = Excel.createExcel();
      final iSheet = iExcel['StaticIPs'];
      iSheet.appendRow([
        TextCellValue('#'),
        TextCellValue('IP'),
        TextCellValue('Subnet'),
        TextCellValue('Gateway'),
        TextCellValue('DNS1'),
        TextCellValue('DNS2'),
        TextCellValue('Device'),
        TextCellValue('MAC'),
        TextCellValue('VLAN'),
        TextCellValue('Notes'),
      ]);
      iSheet.appendRow([
        IntCellValue(1),
        TextCellValue('10.0.10.50'),
        TextCellValue('255.255.255.0'),
        TextCellValue('10.0.10.1'),
        TextCellValue('1.1.1.1'),
        TextCellValue('8.8.8.8'),
        TextCellValue('Core Switch'),
        TextCellValue('AA:BB:CC:DD:EE:FF'),
        TextCellValue('10'),
        TextCellValue('Mgmt'),
      ]);

      final vRes = await ExcelImportService.importVendorContacts(vExcel, replace: true);
      final wRes = await ExcelImportService.importWifiNetworks(wExcel, replace: true);
      final aRes = await ExcelImportService.importAccountPasswords(aExcel, replace: true);
      final iRes = await ExcelImportService.importStaticIps(iExcel, replace: true);

      expect(vRes.inserted, 1);
      expect(wRes.inserted, 1);
      expect(aRes.inserted, 1);
      expect(iRes.inserted, 1);
    });

    test('AuditExportService writes non-blank Action and Entity columns to CSV & PDF',
        () async {
      await helper.logAuditActivity(
        'CREATE',
        'Vendor',
        entityId: 1,
        description: 'Created Audit Test Vendor',
      );
      final logs = await helper.getAuditActivities(limit: 10);
      expect(logs, isNotEmpty);

      final svc = AuditExportService();
      final csvFile = await svc.exportAuditCsv();
      final csvText = await csvFile.readAsString();
      expect(csvText, contains('CREATE'));
      expect(csvText, contains('Vendor'));

      final pdfFile = await svc.exportAuditPdf();
      expect(await pdfFile.exists(), isTrue);
      final pdfBytes = await pdfFile.readAsBytes();
      expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
    });
  });
}
