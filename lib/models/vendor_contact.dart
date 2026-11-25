// lib/models/vendor_contact.dart

/// Represents an external vendor, ISP, hardware manufacturer, domain registrar,
/// or internal escalation contact for the IT runbook.
class VendorContact {
  final int? id;
  final String contactType; // 'ISP', 'Vendor', 'Domain/Registrar', 'Cloud/SaaS', 'Internal'
  final String name;
  final String company;
  final String role;
  final String phoneNumber;
  final String email;
  final String portalUrl;
  final String accountNumber;
  final String slaTier;
  final String notes;
  final String? createdAt;

  static const List<String> slaTiers = [
    '',
    '24/7 Critical (1h)',
    'Business Gold (4h)',
    'Next Business Day',
    'Best Effort',
  ];

  VendorContact({
    this.id,
    required this.contactType,
    required this.name,
    this.company = '',
    this.role = '',
    this.phoneNumber = '',
    this.email = '',
    this.portalUrl = '',
    this.accountNumber = '',
    this.slaTier = '',
    this.notes = '',
    this.createdAt,
  });
}
