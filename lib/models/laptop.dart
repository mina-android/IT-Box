class Laptop {
  final int? id;
  final String laptopNumber;
  final String model;
  final String cpu;
  final String gpu;
  final String ram;
  final String storage;
  final String condition;
  final String user;
  final String password;
  final String notes;
  final DateTime? createdAt;

  const Laptop({
    this.id,
    required this.laptopNumber,
    required this.model,
    this.cpu = '',
    this.gpu = '',
    this.ram = '',
    this.storage = '',
    this.condition = 'Good',
    this.user = '',
    this.password = '',
    this.notes = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'laptop_number': laptopNumber,
    'model': model,
    'cpu': cpu,
    'gpu': gpu,
    'ram': ram,
    'storage': storage,
    'condition': condition,
    'user': user,
    'password': password,
    'notes': notes,
    'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
  };

  factory Laptop.fromMap(Map<String, dynamic> m) => Laptop(
    id: m['id'] as int?,
    laptopNumber: (m['laptop_number'] ?? '') as String,
    model: (m['model'] ?? '') as String,
    cpu: (m['cpu'] ?? '') as String,
    gpu: (m['gpu'] ?? '') as String,
    ram: (m['ram'] ?? '') as String,
    storage: (m['storage'] ?? '') as String,
    condition: (m['condition'] ?? 'Good') as String,
    user: (m['user'] ?? '') as String,
    password: (m['password'] ?? '') as String,
    notes: (m['notes'] ?? '') as String,
    createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null,
  );

  Laptop copyWith({
    int? id, String? laptopNumber, String? model, String? cpu, String? gpu,
    String? ram, String? storage, String? condition, String? user, String? password,
    String? notes,
  }) => Laptop(
    id: id ?? this.id,
    laptopNumber: laptopNumber ?? this.laptopNumber,
    model: model ?? this.model,
    cpu: cpu ?? this.cpu,
    gpu: gpu ?? this.gpu,
    ram: ram ?? this.ram,
    storage: storage ?? this.storage,
    condition: condition ?? this.condition,
    user: user ?? this.user,
    password: password ?? this.password,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );
}
