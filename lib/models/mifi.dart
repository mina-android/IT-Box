class MiFi {
  final int? id;
  final String deviceNumber;
  final String model;
  final String phoneNumber;
  final String wifiName;
  final String wifiPassword;
  final String quota;
  final String serviceProvider;
  final String gateway;
  final String adminPassword;
  final String status; // 'Available' | 'Borrowed'

  const MiFi({
    this.id,
    required this.deviceNumber,
    required this.model,
    this.phoneNumber = '',
    this.wifiName = '',
    this.wifiPassword = '',
    this.quota = '',
    this.serviceProvider = '',
    this.gateway = '',
    this.adminPassword = '',
    this.status = 'Available',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'device_number': deviceNumber,
    'model': model,
    'phone_number': phoneNumber,
    'wifi_name': wifiName,
    'wifi_password': wifiPassword,
    'quota': quota,
    'service_provider': serviceProvider,
    'gateway': gateway,
    'admin_password': adminPassword,
    'status': status,
  };

  factory MiFi.fromMap(Map<String, dynamic> m) => MiFi(
    id: m['id'] as int?,
    deviceNumber: (m['device_number'] ?? '') as String,
    model: (m['model'] ?? '') as String,
    phoneNumber: (m['phone_number'] ?? '') as String,
    wifiName: (m['wifi_name'] ?? '') as String,
    wifiPassword: (m['wifi_password'] ?? '') as String,
    quota: (m['quota'] ?? '') as String,
    serviceProvider: (m['service_provider'] ?? '') as String,
    gateway: (m['gateway'] ?? '') as String,
    adminPassword: (m['admin_password'] ?? '') as String,
    status: (m['status'] ?? 'Available') as String,
  );

  MiFi copyWith({
    int? id, String? deviceNumber, String? model, String? phoneNumber,
    String? wifiName, String? wifiPassword, String? quota,
    String? serviceProvider, String? gateway, String? adminPassword, String? status,
  }) => MiFi(
    id: id ?? this.id,
    deviceNumber: deviceNumber ?? this.deviceNumber,
    model: model ?? this.model,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    wifiName: wifiName ?? this.wifiName,
    wifiPassword: wifiPassword ?? this.wifiPassword,
    quota: quota ?? this.quota,
    serviceProvider: serviceProvider ?? this.serviceProvider,
    gateway: gateway ?? this.gateway,
    adminPassword: adminPassword ?? this.adminPassword,
    status: status ?? this.status,
  );
}
