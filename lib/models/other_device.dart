class OtherDevice {
  final int? id;
  final String deviceType;
  final String deviceName;
  final String model;
  final String notes;
  final String? createdAt;

  const OtherDevice({
    this.id,
    required this.deviceType,
    required this.deviceName,
    this.model = '',
    this.notes = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'device_type': deviceType,
        'device_name': deviceName,
        'model': model,
        'notes': notes,
        if (createdAt != null) 'created_at': createdAt,
      };

  factory OtherDevice.fromMap(Map<String, dynamic> m) => OtherDevice(
        id: m['id'] as int?,
        deviceType: (m['device_type'] ?? '') as String,
        deviceName: (m['device_name'] ?? '') as String,
        model: (m['model'] ?? '') as String,
        notes: (m['notes'] ?? '') as String,
        createdAt: m['created_at'] as String?,
      );

  OtherDevice copyWith({
    int? id,
    String? deviceType,
    String? deviceName,
    String? model,
    String? notes,
    String? createdAt,
  }) =>
      OtherDevice(
        id: id ?? this.id,
        deviceType: deviceType ?? this.deviceType,
        deviceName: deviceName ?? this.deviceName,
        model: model ?? this.model,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
      );
}
