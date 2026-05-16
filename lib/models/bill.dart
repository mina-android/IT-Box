class Bill {
  final int? id;
  final String person;
  final String number;
  final String category;
  final double price;
  final String notes;

  const Bill({
    this.id,
    this.person = '',
    required this.number,
    required this.category,
    required this.price,
    this.notes = '',
  });

  static const List<String> categories = [
    'MiFis',
    '4G Internet',
    'Landline Internet',
    'Landline Phone',
    'Mobile Phone',
  ];

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'person': person,
    'number': number,
    'category': category,
    'price': price,
    'notes': notes,
  };

  factory Bill.fromMap(Map<String, dynamic> m) => Bill(
    id: m['id'] as int?,
    person: (m['person'] ?? '') as String,
    number: (m['number'] ?? '') as String,
    category: (m['category'] ?? Bill.categories.first) as String,
    price: ((m['price'] ?? 0.0) as num).toDouble(),
    notes: (m['notes'] ?? '') as String,
  );

  Bill copyWith({int? id, String? person, String? number,
      String? category, double? price, String? notes}) => Bill(
    id: id ?? this.id,
    person: person ?? this.person,
    number: number ?? this.number,
    category: category ?? this.category,
    price: price ?? this.price,
    notes: notes ?? this.notes,
  );
}
