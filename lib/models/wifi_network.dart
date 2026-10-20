class WifiNetwork {
  final int? id;
  final String networkName;
  final String password;
  final String phoneNumber;
  final String locationDevice;
  final String adminUsername;
  final String adminPassword;
  final String notes;
  final String? createdAt;
  final bool isLinkedDevice;
  final String originType;

  const WifiNetwork({
    this.id,
    required this.networkName,
    this.password = '',
    this.phoneNumber = '',
    this.locationDevice = '',
    this.adminUsername = '',
    this.adminPassword = '',
    this.notes = '',
    this.createdAt,
    this.isLinkedDevice = false,
    this.originType = 'Standalone',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'network_name': networkName,
        'password': password,
        'phone_number': phoneNumber,
        'location_device': locationDevice,
        'admin_username': adminUsername,
        'admin_password': adminPassword,
        'notes': notes,
        if (createdAt != null) 'created_at': createdAt,
      };

  factory WifiNetwork.fromMap(Map<String, dynamic> m) => WifiNetwork(
        id: m['id'] as int?,
        networkName: (m['network_name'] ?? '') as String,
        password: (m['password'] ?? '') as String,
        phoneNumber: (m['phone_number'] ?? '') as String,
        locationDevice: (m['location_device'] ?? '') as String,
        adminUsername: (m['admin_username'] ?? '') as String,
        adminPassword: (m['admin_password'] ?? '') as String,
        notes: (m['notes'] ?? '') as String,
        createdAt: m['created_at'] as String?,
        isLinkedDevice: false,
        originType: 'Standalone',
      );

  WifiNetwork copyWith({
    int? id,
    String? networkName,
    String? password,
    String? phoneNumber,
    String? locationDevice,
    String? adminUsername,
    String? adminPassword,
    String? notes,
    String? createdAt,
    bool? isLinkedDevice,
    String? originType,
  }) =>
      WifiNetwork(
        id: id ?? this.id,
        networkName: networkName ?? this.networkName,
        password: password ?? this.password,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        locationDevice: locationDevice ?? this.locationDevice,
        adminUsername: adminUsername ?? this.adminUsername,
        adminPassword: adminPassword ?? this.adminPassword,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        isLinkedDevice: isLinkedDevice ?? this.isLinkedDevice,
        originType: originType ?? this.originType,
      );
}
