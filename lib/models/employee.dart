class Employee {
  final int? id;
  final String name;
  final String phoneNumber;

  const Employee({
    this.id,
    required this.name,
    this.phoneNumber = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'phone_number': phoneNumber,
  };

  factory Employee.fromMap(Map<String, dynamic> m) => Employee(
    id: m['id'] as int?,
    name: (m['name'] ?? '') as String,
    phoneNumber: (m['phone_number'] ?? '') as String,
  );

  Employee copyWith({int? id, String? name, String? phoneNumber}) =>
    Employee(id: id ?? this.id, name: name ?? this.name, phoneNumber: phoneNumber ?? this.phoneNumber);
}
