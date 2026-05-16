class Electronic {
  final int? id;
  final String deviceNumber;
  final String deviceName;
  final String details;
  final String status;

  const Electronic({
    this.id,
    required this.deviceNumber,
    required this.deviceName,
    this.details = '',
    this.status = 'Available',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'device_number': deviceNumber,
    'device_name': deviceName,
    'details': details,
    'status': status,
  };

  factory Electronic.fromMap(Map<String, dynamic> m) => Electronic(
    id: m['id'] as int?,
    deviceNumber: (m['device_number'] ?? '') as String,
    deviceName: (m['device_name'] ?? '') as String,
    details: (m['details'] ?? '') as String,
    status: (m['status'] ?? 'Available') as String,
  );

  Electronic copyWith({int? id, String? deviceNumber, String? deviceName, String? details, String? status}) =>
    Electronic(
      id: id ?? this.id,
      deviceNumber: deviceNumber ?? this.deviceNumber,
      deviceName: deviceName ?? this.deviceName,
      details: details ?? this.details,
      status: status ?? this.status,
    );
}
