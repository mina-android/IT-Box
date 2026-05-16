class Expense {
  final int? id;
  final String date;   // yyyy-MM-dd
  final String item;
  final double price;
  final String details;

  const Expense({
    this.id,
    required this.date,
    required this.item,
    required this.price,
    this.details = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'date': date,
    'item': item,
    'price': price,
    'details': details,
  };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
    id: m['id'] as int?,
    date: (m['date'] ?? '') as String,
    item: (m['item'] ?? '') as String,
    price: ((m['price'] ?? 0.0) as num).toDouble(),
    details: (m['details'] ?? '') as String,
  );

  Expense copyWith({int? id, String? date, String? item, double? price, String? details}) =>
    Expense(
      id: id ?? this.id,
      date: date ?? this.date,
      item: item ?? this.item,
      price: price ?? this.price,
      details: details ?? this.details,
    );
}
