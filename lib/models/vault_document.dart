// lib/models/vault_document.dart
import 'package:flutter/material.dart';

class VaultDocument {
  final int? id;
  final String title;
  final String category;
  final String filePath;
  final String fileType; // 'pdf' or 'image'
  final int fileSizeBytes;
  final int pageCount;
  final String linkedEmployeeName;
  final String linkedAssetType;
  final String linkedAssetLabel;
  final String notes;
  final String? createdAt;

  static const List<String> categories = [
    'Contract',
    'Invoice',
    'Warranty',
    'Signed Custody',
    'ID/Compliance',
    'Other',
  ];

  const VaultDocument({
    this.id,
    required this.title,
    required this.category,
    required this.filePath,
    required this.fileType,
    this.fileSizeBytes = 0,
    this.pageCount = 1,
    this.linkedEmployeeName = '',
    this.linkedAssetType = '',
    this.linkedAssetLabel = '',
    this.notes = '',
    this.createdAt,
  });

  bool get isPdf => fileType.toLowerCase() == 'pdf';

  String get formattedSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    }
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  static Color colorForCategory(String category) {
    switch (category) {
      case 'Contract':
        return const Color(0xFF6366F1);
      case 'Invoice':
        return const Color(0xFF10B981);
      case 'Warranty':
        return const Color(0xFFF59E0B);
      case 'Signed Custody':
        return const Color(0xFF0EA5E9);
      case 'ID/Compliance':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF64748B);
    }
  }

  static IconData iconForCategory(String category) {
    switch (category) {
      case 'Contract':
        return Icons.handshake_rounded;
      case 'Invoice':
        return Icons.receipt_long_rounded;
      case 'Warranty':
        return Icons.verified_user_rounded;
      case 'Signed Custody':
        return Icons.assignment_turned_in_rounded;
      case 'ID/Compliance':
        return Icons.badge_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  VaultDocument copyWith({
    int? id,
    String? title,
    String? category,
    String? filePath,
    String? fileType,
    int? fileSizeBytes,
    int? pageCount,
    String? linkedEmployeeName,
    String? linkedAssetType,
    String? linkedAssetLabel,
    String? notes,
    String? createdAt,
  }) {
    return VaultDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      pageCount: pageCount ?? this.pageCount,
      linkedEmployeeName: linkedEmployeeName ?? this.linkedEmployeeName,
      linkedAssetType: linkedAssetType ?? this.linkedAssetType,
      linkedAssetLabel: linkedAssetLabel ?? this.linkedAssetLabel,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
