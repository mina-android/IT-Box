class Printer {
  final int? id;
  final String printerNumber;
  final String model;
  final String condition;
  final String location;

  const Printer({
    this.id,
    required this.printerNumber,
    required this.model,
    this.condition = 'Good',
    this.location = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'printer_number': printerNumber,
    'model': model,
    'condition': condition,
    'location': location,
  };

  factory Printer.fromMap(Map<String, dynamic> m) => Printer(
    id: m['id'] as int?,
    printerNumber: (m['printer_number'] ?? '') as String,
    model: (m['model'] ?? '') as String,
    condition: (m['condition'] ?? 'Good') as String,
    location: (m['location'] ?? '') as String,
  );

  Printer copyWith({int? id, String? printerNumber, String? model, String? condition, String? location}) =>
    Printer(
      id: id ?? this.id,
      printerNumber: printerNumber ?? this.printerNumber,
      model: model ?? this.model,
      condition: condition ?? this.condition,
      location: location ?? this.location,
    );
}
