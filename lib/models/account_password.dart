class AccountPassword {
  final int? id;
  final String platform;
  final String emailUsername;
  final String password;
  final String? createdAt;

  const AccountPassword({
    this.id,
    required this.platform,
    required this.emailUsername,
    required this.password,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'platform': platform,
        'email_username': emailUsername,
        'password': password,
        if (createdAt != null) 'created_at': createdAt,
      };

  factory AccountPassword.fromMap(Map<String, dynamic> m) => AccountPassword(
        id: m['id'] as int?,
        platform: (m['platform'] ?? '') as String,
        emailUsername: (m['email_username'] ?? '') as String,
        password: (m['password'] ?? '') as String,
        createdAt: m['created_at'] as String?,
      );

  AccountPassword copyWith({
    int? id,
    String? platform,
    String? emailUsername,
    String? password,
    String? createdAt,
  }) =>
      AccountPassword(
        id: id ?? this.id,
        platform: platform ?? this.platform,
        emailUsername: emailUsername ?? this.emailUsername,
        password: password ?? this.password,
        createdAt: createdAt ?? this.createdAt,
      );
}
