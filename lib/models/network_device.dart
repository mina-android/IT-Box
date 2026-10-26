class NetworkDevice {
  final int? id;
  final String deviceNumber;
  final String phoneNumber;
  final String deviceLocation;
  final String model;
  final String serviceProvider;
  final String wifiName;
  final String wifiPassword;
  final String gateway;
  final String adminPassword;
  final String status;
  final String notes;

  const NetworkDevice({
    this.id,
    required this.deviceNumber,
    required this.model,
    this.phoneNumber = '',
    this.deviceLocation = '',
    this.serviceProvider = '',
    this.wifiName = '',
    this.wifiPassword = '',
    this.gateway = '',
    this.adminPassword = '',
    this.status = 'Available',
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'device_number': deviceNumber,
    'phone_number': phoneNumber,
    'device_location': deviceLocation,
    'model': model,
    'service_provider': serviceProvider,
    'wifi_name': wifiName,
    'wifi_password': wifiPassword,
    'gateway': gateway,
    'admin_password': adminPassword,
    'status': status,
    'notes': notes,
  };

  factory NetworkDevice.fromMap(Map<String, dynamic> m) => NetworkDevice(
    id: m['id'] as int?,
    deviceNumber: (m['device_number'] ?? '') as String,
    phoneNumber: (m['phone_number'] ?? '') as String,
    deviceLocation: (m['device_location'] ?? '') as String,
    model: (m['model'] ?? '') as String,
    serviceProvider: (m['service_provider'] ?? '') as String,
    wifiName: (m['wifi_name'] ?? '') as String,
    wifiPassword: (m['wifi_password'] ?? '') as String,
    gateway: (m['gateway'] ?? '') as String,
    adminPassword: (m['admin_password'] ?? '') as String,
    status: (m['status'] ?? 'Available') as String,
    notes: (m['notes'] ?? '') as String,
  );

  NetworkDevice copyWith({
    int? id, String? deviceNumber, String? phoneNumber, String? deviceLocation,
    String? model, String? serviceProvider, String? wifiName, String? wifiPassword,
    String? gateway, String? adminPassword, String? status, String? notes,
  }) => NetworkDevice(
    id: id ?? this.id,
    deviceNumber: deviceNumber ?? this.deviceNumber,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    deviceLocation: deviceLocation ?? this.deviceLocation,
    model: model ?? this.model,
    serviceProvider: serviceProvider ?? this.serviceProvider,
    wifiName: wifiName ?? this.wifiName,
    wifiPassword: wifiPassword ?? this.wifiPassword,
    gateway: gateway ?? this.gateway,
    adminPassword: adminPassword ?? this.adminPassword,
    status: status ?? this.status,
    notes: notes ?? this.notes,
  );
}
