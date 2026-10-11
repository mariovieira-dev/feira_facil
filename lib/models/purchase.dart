import 'unit.dart';
import 'category.dart';

class PurchaseItem {
  final int? id;
  final int purchaseId;
  final int productId;
  final String productName;
  final Category category;
  final double quantity;
  final Unit unit;
  final double pricePaid;
  final DateTime createdAt;

  PurchaseItem({
    this.id,
    required this.purchaseId,
    required this.productId,
    required this.productName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.pricePaid,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Preço por unidade base (para comparação)
  double get pricePerBaseUnit {
    final baseQuantity = unit.toBaseUnit(quantity);
    if (baseQuantity <= 0) return 0;
    return pricePaid / baseQuantity;
  }

  // Preço por unidade original
  double get pricePerUnit {
    if (quantity <= 0) return 0;
    return pricePaid / quantity;
  }

  double get totalPrice => pricePaid;

  PurchaseItem copyWith({
    int? id,
    int? purchaseId,
    int? productId,
    String? productName,
    Category? category,
    double? quantity,
    Unit? unit,
    double? pricePaid,
    DateTime? createdAt,
  }) {
    return PurchaseItem(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      pricePaid: pricePaid ?? this.pricePaid,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchaseId': purchaseId,
      'productId': productId,
      'productName': productName,
      'category': category.name,
      'quantity': quantity,
      'unit': unit.name,
      'pricePaid': pricePaid,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'],
      purchaseId: map['purchaseId'],
      productId: map['productId'],
      productName: map['productName'],
      category: Category.fromString(map['category']),
      quantity: map['quantity'],
      unit: Unit.fromString(map['unit']),
      pricePaid: map['pricePaid'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  @override
  String toString() {
    return 'PurchaseItem(id: $id, productName: $productName, quantity: $quantity ${unit.shortName}, pricePaid: $pricePaid)';
  }
}

class Purchase {
  final int? id;
  final DateTime date;
  final String location;
  final List<PurchaseItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  Purchase({
    this.id,
    required this.date,
    required this.location,
    this.items = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  double get totalAmount => items.fold(0.0, (sum, item) => sum + item.pricePaid);

  Map<Category, double> get totalByCategory {
    final map = <Category, double>{};
    for (final item in items) {
      map[item.category] = (map[item.category] ?? 0) + item.pricePaid;
    }
    return map;
  }

  Purchase copyWith({
    int? id,
    DateTime? date,
    String? location,
    List<PurchaseItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Purchase(
      id: id ?? this.id,
      date: date ?? this.date,
      location: location ?? this.location,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'location': location,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id'],
      date: DateTime.parse(map['date']),
      location: map['location'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  @override
  String toString() {
    return 'Purchase(id: $id, date: $date, location: $location, total: $totalAmount, items: ${items.length})';
  }


}

