class MonthlyBudget {
  final int? id;
  final int year;
  final int month;
  final double amount;
  final DateTime createdAt;
  final DateTime updatedAt;

  MonthlyBudget({
    this.id,
    required this.year,
    required this.month,
    required this.amount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  String get key => '$year-$month';

  MonthlyBudget copyWith({
    int? id,
    int? year,
    int? month,
    double? amount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MonthlyBudget(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'year': year,
      'month': month,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MonthlyBudget.fromMap(Map<String, dynamic> map) {
    return MonthlyBudget(
      id: map['id'],
      year: map['year'],
      month: map['month'],
      amount: map['amount'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  @override
  String toString() {
    return 'MonthlyBudget(id: $id, year: $year, month: $month, amount: $amount)';
  }
}