// lib/models/custody_document.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';

class CustodyItem {
  final String deviceType;
  final String deviceName;
  final String deviceNumber;
  final String serialNumber;
  final String condition;
  final Map<String, String> extraSpecs;

  const CustodyItem({
    required this.deviceType,
    required this.deviceName,
    this.deviceNumber = '',
    this.serialNumber = '',
    this.condition = 'Good / Verified',
    this.extraSpecs = const {},
  });

  Map<String, dynamic> toJson() => {
        'deviceType': deviceType,
        'deviceName': deviceName,
        'deviceNumber': deviceNumber,
        'serialNumber': serialNumber,
        'condition': condition,
        'extraSpecs': extraSpecs,
      };

  factory CustodyItem.fromJson(Map<String, dynamic> json) {
    final rawSpecs = json['extraSpecs'];
    final specs = <String, String>{};
    if (rawSpecs is Map) {
      for (final entry in rawSpecs.entries) {
        final key = entry.key.toString();
        final val = entry.value?.toString() ?? '';
        if (key.isNotEmpty && val.isNotEmpty) {
          specs[key] = val;
        }
      }
    }
    return CustodyItem(
      deviceType: json['deviceType']?.toString() ?? 'Device',
      deviceName: json['deviceName']?.toString() ?? '',
      deviceNumber: json['deviceNumber']?.toString() ?? '',
      serialNumber: json['serialNumber']?.toString() ?? '',
      condition: json['condition']?.toString() ?? 'Good / Verified',
      extraSpecs: specs,
    );
  }
}

class CustodyDocument {
  final int? id;
  final String documentNumber;
  final String title;
  final String sourceType; // 'borrow', 'laptop', 'custom'
  final int? sourceId;
  final String employeeName;
  final String employeePhone;
  final String employeeEmail;
  final String handoverDate;
  final String dueDate;
  final String itemsJson;
  final String agreementText;
  final String adminNotes;
  final String signatureBase64;
  final String pdfPath;
  final String? createdAt;

  static const String defaultAgreementText =
      'The recipient hereby acknowledges receipt of the above IT hardware/equipment in good working condition. '
      'The equipment remains sole property of the organization and must be returned upon termination of employment, '
      'project completion, or IT audit request. The recipient assumes responsibility for reasonable care and security '
      'and agrees to report any loss, theft, or damage immediately to the IT Department.';

  const CustodyDocument({
    this.id,
    required this.documentNumber,
    this.title = 'Equipment Custody Receipt',
    required this.sourceType,
    this.sourceId,
    required this.employeeName,
    this.employeePhone = '',
    this.employeeEmail = '',
    required this.handoverDate,
    this.dueDate = '',
    required this.itemsJson,
    this.agreementText = defaultAgreementText,
    this.adminNotes = '',
    this.signatureBase64 = '',
    this.pdfPath = '',
    this.createdAt,
  });

  List<CustodyItem> get items {
    if (itemsJson.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) => CustodyItem.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Uint8List? get signatureBytes {
    if (signatureBase64.trim().isEmpty) {
      return null;
    }
    try {
      return base64Decode(signatureBase64);
    } catch (_) {
      return null;
    }
  }

  static String encodeItems(List<CustodyItem> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }

  static String generateDocumentNumber({DateTime? now}) {
    final dt = now ?? DateTime.now();
    final datePart = DateFormat('yyyyMMdd').format(dt);
    final seqPart = (dt.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
    return 'CUS-$datePart-$seqPart';
  }

  CustodyDocument copyWith({
    int? id,
    String? documentNumber,
    String? title,
    String? sourceType,
    int? sourceId,
    String? employeeName,
    String? employeePhone,
    String? employeeEmail,
    String? handoverDate,
    String? dueDate,
    String? itemsJson,
    String? agreementText,
    String? adminNotes,
    String? signatureBase64,
    String? pdfPath,
    String? createdAt,
  }) {
    return CustodyDocument(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      title: title ?? this.title,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      employeeName: employeeName ?? this.employeeName,
      employeePhone: employeePhone ?? this.employeePhone,
      employeeEmail: employeeEmail ?? this.employeeEmail,
      handoverDate: handoverDate ?? this.handoverDate,
      dueDate: dueDate ?? this.dueDate,
      itemsJson: itemsJson ?? this.itemsJson,
      agreementText: agreementText ?? this.agreementText,
      adminNotes: adminNotes ?? this.adminNotes,
      signatureBase64: signatureBase64 ?? this.signatureBase64,
      pdfPath: pdfPath ?? this.pdfPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
