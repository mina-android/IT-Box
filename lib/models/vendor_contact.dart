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
  final String notes;
  final String? createdAt;

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
    this.notes = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'contact_type': contactType,
        'name': name,
        'company': company,
        'role': role,
        'phone_number': phoneNumber,
        'email': email,
        'portal_url': portalUrl,
        'account_number': accountNumber,
        'notes': notes,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
      };

  factory VendorContact.fromMap(Map<String, dynamic> map) => VendorContact(
        id: map['id'] as int?,
        contactType: (map['contact_type'] ?? 'Vendor') as String,
        name: (map['name'] ?? '') as String,
        company: (map['company'] ?? '') as String,
        role: (map['role'] ?? '') as String,
        phoneNumber: (map['phone_number'] ?? '') as String,
        email: (map['email'] ?? '') as String,
        portalUrl: (map['portal_url'] ?? '') as String,
        accountNumber: (map['account_number'] ?? '') as String,
        notes: (map['notes'] ?? '') as String,
        createdAt: map['created_at'] as String?,
      );

  VendorContact copyWith({
    int? id,
    String? contactType,
    String? name,
    String? company,
    String? role,
    String? phoneNumber,
    String? email,
    String? portalUrl,
    String? accountNumber,
    String? notes,
    String? createdAt,
  }) =>
      VendorContact(
        id: id ?? this.id,
        contactType: contactType ?? this.contactType,
        name: name ?? this.name,
        company: company ?? this.company,
        role: role ?? this.role,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        email: email ?? this.email,
        portalUrl: portalUrl ?? this.portalUrl,
        accountNumber: accountNumber ?? this.accountNumber,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
      );
}
