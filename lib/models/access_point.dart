class AccessPoint {
  final int? id;
  final String deviceNumber;
  final String model;
  final String portNumber;
  final String location;

  const AccessPoint({
    this.id,
    required this.deviceNumber,
    required this.model,
    this.portNumber = '',
    this.location = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'device_number': deviceNumber,
    'model': model,
    'port_number': portNumber,
    'location': location,
  };

  factory AccessPoint.fromMap(Map<String, dynamic> m) => AccessPoint(
    id: m['id'] as int?,
    deviceNumber: (m['device_number'] ?? '') as String,
    model: (m['model'] ?? '') as String,
    portNumber: (m['port_number'] ?? '') as String,
    location: (m['location'] ?? '') as String,
  );

  AccessPoint copyWith({
    int? id, String? deviceNumber, String? model,
    String? portNumber, String? location,
  }) => AccessPoint(
    id: id ?? this.id,
    deviceNumber: deviceNumber ?? this.deviceNumber,
    model: model ?? this.model,
    portNumber: portNumber ?? this.portNumber,
    location: location ?? this.location,
  );
}
