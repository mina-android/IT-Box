class Expense {
  final int? id;
  final String date; // yyyy-MM-dd
  final String item;
  final double price;
  final String details;
  final String receiptPath;

  const Expense({
    this.id,
    required this.date,
    required this.item,
    required this.price,
    this.details = '',
    this.receiptPath = '',
  });

  Expense copyWith({
    int? id,
    String? date,
    String? item,
    double? price,
    String? details,
    String? receiptPath,
  }) =>
      Expense(
        id: id ?? this.id,
        date: date ?? this.date,
        item: item ?? this.item,
        price: price ?? this.price,
        details: details ?? this.details,
        receiptPath: receiptPath ?? this.receiptPath,
      );
}
