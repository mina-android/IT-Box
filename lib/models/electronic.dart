class Electronic {
  final int? id;
  final String deviceNumber;
  final String deviceName;
  final String details;
  final String status;
  final bool excludeFromBorrowing;

  const Electronic({
    this.id,
    required this.deviceNumber,
    required this.deviceName,
    this.details = '',
    this.status = 'Available',
    this.excludeFromBorrowing = false,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'device_number': deviceNumber,
    'device_name': deviceName,
    'details': details,
    'status': status,
    'exclude_borrowing': excludeFromBorrowing ? 1 : 0,
  };

  factory Electronic.fromMap(Map<String, dynamic> m) => Electronic(
    id: m['id'] as int?,
    deviceNumber: (m['device_number'] ?? '') as String,
    deviceName: (m['device_name'] ?? '') as String,
    details: (m['details'] ?? '') as String,
    status: (m['status'] ?? 'Available') as String,
    excludeFromBorrowing: (m['exclude_borrowing'] ?? 0) == 1,
  );

  Electronic copyWith({int? id, String? deviceNumber, String? deviceName, String? details, String? status, bool? excludeFromBorrowing}) =>
    Electronic(
      id: id ?? this.id,
      deviceNumber: deviceNumber ?? this.deviceNumber,
      deviceName: deviceName ?? this.deviceName,
      details: details ?? this.details,
      status: status ?? this.status,
      excludeFromBorrowing: excludeFromBorrowing ?? this.excludeFromBorrowing,
    );
}
