class Subscription {
  static const List<String> types = ['Monthly', 'Yearly', 'Weekly'];

  final int? id;
  final String service;
  final String type; // 'Monthly' | 'Yearly' | 'Weekly'
  final double price;
  final String renewalDate; // yyyy-MM-dd
  final String notes;

  const Subscription({
    this.id,
    required this.service,
    required this.type,
    this.price = 0.0,
    this.renewalDate = '',
    this.notes = '',
  });

  double get monthlyEquivalent {
    switch (type) {
      case 'Yearly':
        return price / 12.0;
      case 'Weekly':
        return price * 4.33333333;
      case 'Monthly':
      default:
        return price;
    }
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'service': service,
    'type': type,
    'price': price,
    'renewal_date': renewalDate,
    'notes': notes,
  };

  factory Subscription.fromMap(Map<String, dynamic> m) => Subscription(
    id: m['id'] as int?,
    service: (m['service'] ?? '') as String,
    type: (m['type'] ?? 'Monthly') as String,
    price: (m['price'] as num? ?? 0.0).toDouble(),
    renewalDate: (m['renewal_date'] ?? '') as String,
    notes: (m['notes'] ?? '') as String,
  );

  Subscription copyWith({
    int? id,
    String? service,
    String? type,
    double? price,
    String? renewalDate,
    String? notes,
  }) => Subscription(
    id: id ?? this.id,
    service: service ?? this.service,
    type: type ?? this.type,
    price: price ?? this.price,
    renewalDate: renewalDate ?? this.renewalDate,
    notes: notes ?? this.notes,
  );
}
