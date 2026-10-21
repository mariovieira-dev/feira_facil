import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/budget.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/purchase.dart';

class FirestoreDatabaseHelper {
  FirestoreDatabaseHelper({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> get _userDocument {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('É necessário estar autenticado para acessar os dados.');
    }
    return _firestore.collection('users').doc(user.uid);
  }

  CollectionReference<Map<String, dynamic>> get _products =>
      _userDocument.collection('products');
  CollectionReference<Map<String, dynamic>> get _purchases =>
      _userDocument.collection('purchases');
  CollectionReference<Map<String, dynamic>> get _budgets =>
      _userDocument.collection('budgets');

  Future<int> _nextId(String name) async {
    final counter = _userDocument.collection('metadata').doc('counters');
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counter);
      final next = ((snapshot.data()?[name] as num?)?.toInt() ?? 0) + 1;
      transaction.set(counter, {name: next}, SetOptions(merge: true));
      return next;
    });
  }

  Future<void> _writeInChunks(
    List<void Function(WriteBatch)> operations,
  ) async {
    for (var start = 0; start < operations.length; start += 450) {
      final batch = _firestore.batch();
      final end = (start + 450).clamp(0, operations.length);
      for (final operation in operations.sublist(start, end)) {
        operation(batch);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection.get();
    final operations = snapshot.docs
        .map<void Function(WriteBatch)>(
          (document) => (batch) {
            batch.delete(document.reference);
          },
        )
        .toList();
    await _writeInChunks(operations);
  }

  Future<int> insertProduct(Product product) async {
    final id = await _nextId('product');
    await _products.doc('$id').set(product.copyWith(id: id).toMap());
    return id;
  }

  Future<int> updateProduct(Product product) async {
    final id = product.id;
    if (id == null) throw ArgumentError('O produto precisa ter um id.');
    await _products
        .doc('$id')
        .update(product.copyWith(updatedAt: DateTime.now()).toMap());
    return 1;
  }

  Future<int> deleteProduct(int id) async {
    await _products.doc('$id').delete();
    return 1;
  }

  Future<List<Product>> getAllProducts() async {
    final snapshot = await _products.get();
    final products = snapshot.docs
        .map((doc) => Product.fromMap(doc.data()))
        .toList();
    products.sort((a, b) => a.name.compareTo(b.name));
    return products;
  }

  Future<List<Product>> getProductsByCategory(Category category) async {
    return (await getAllProducts())
        .where((product) => product.category == category)
        .toList();
  }

  Future<List<Product>> getEssentialProducts() async {
    return (await getAllProducts())
        .where((product) => product.isEssential)
        .toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final normalizedQuery = query.toLowerCase();
    return (await getAllProducts())
        .where(
          (product) => product.name.toLowerCase().contains(normalizedQuery),
        )
        .take(10)
        .toList();
  }

  Future<Product?> getProductById(int id) async {
    final snapshot = await _products.doc('$id').get();
    final data = snapshot.data();
    return data == null ? null : Product.fromMap(data);
  }

  Future<Product?> getProductByName(String name) async {
    final normalizedName = name.toLowerCase();
    for (final product in await getAllProducts()) {
      if (product.name.toLowerCase() == normalizedName) return product;
    }
    return null;
  }

  Future<int> insertPurchase(Purchase purchase) async {
    final id = await _nextId('purchase');
    final purchaseRef = _purchases.doc('$id');
    final itemOperations = <void Function(WriteBatch)>[
      (batch) => batch.set(purchaseRef, purchase.copyWith(id: id).toMap()),
    ];
    var itemId = 0;
    for (final item in purchase.items) {
      itemId++;
      final itemRef = purchaseRef.collection('items').doc('$itemId');
      itemOperations.add(
        (batch) => batch.set(
          itemRef,
          item.copyWith(id: itemId, purchaseId: id).toMap(),
        ),
      );
    }
    await _writeInChunks(itemOperations);
    return id;
  }

  Future<int> updatePurchase(Purchase purchase) async {
    final id = purchase.id;
    if (id == null) throw ArgumentError('A compra precisa ter um id.');
    final purchaseRef = _purchases.doc('$id');
    final itemCollection = purchaseRef.collection('items');
    final oldItems = await itemCollection.get();
    final operations = <void Function(WriteBatch)>[
      (batch) => batch.set(
        purchaseRef,
        purchase.copyWith(updatedAt: DateTime.now()).toMap(),
      ),
      ...oldItems.docs.map<void Function(WriteBatch)>(
        (document) => (batch) {
          batch.delete(document.reference);
        },
      ),
    ];
    for (var index = 0; index < purchase.items.length; index++) {
      final item = purchase.items[index];
      final itemId = index + 1;
      operations.add(
        (batch) => batch.set(
          itemCollection.doc('$itemId'),
          item.copyWith(id: itemId, purchaseId: id).toMap(),
        ),
      );
    }
    await _writeInChunks(operations);
    return id;
  }

  Future<int> deletePurchase(int id) async {
    final purchase = _purchases.doc('$id');
    await _deleteCollection(purchase.collection('items'));
    await purchase.delete();
    return 1;
  }

  Future<List<Purchase>> _getPurchases() async {
    final snapshot = await _purchases.get();
    final purchases = await Future.wait(
      snapshot.docs.map((doc) async {
        final purchase = Purchase.fromMap(doc.data());
        final itemSnapshot = await doc.reference
            .collection('items')
            .orderBy('createdAt')
            .get();
        final items = itemSnapshot.docs
            .map((item) => PurchaseItem.fromMap(item.data()))
            .toList();
        return purchase.copyWith(items: items);
      }),
    );
    purchases.sort((a, b) => b.date.compareTo(a.date));
    return purchases;
  }

  Future<List<Purchase>> getAllPurchases() => _getPurchases();

  Future<List<Purchase>> getPurchasesByMonth(int year, int month) async {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    return (await _getPurchases())
        .where(
          (purchase) =>
              !purchase.date.isBefore(start) && purchase.date.isBefore(end),
        )
        .toList();
  }

  Future<Purchase?> getPurchaseById(int id) async {
    final snapshot = await _purchases.doc('$id').get();
    final data = snapshot.data();
    if (data == null) return null;
    final items = await snapshot.reference
        .collection('items')
        .orderBy('createdAt')
        .get();
    return Purchase.fromMap(data).copyWith(
      items: items.docs.map((doc) => PurchaseItem.fromMap(doc.data())).toList(),
    );
  }

  Future<List<PurchaseItem>> getPurchaseItemsByProduct(int productId) async {
    final items = (await _getPurchases())
        .expand((purchase) => purchase.items)
        .where((item) => item.productId == productId)
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<PurchaseItem?> getLastPurchaseItemByProduct(int productId) async {
    final items = await getPurchaseItemsByProduct(productId);
    return items.isEmpty ? null : items.first;
  }

  Future<List<PurchaseItem>> getAllPurchaseItems() async {
    final items = (await _getPurchases())
        .expand((purchase) => purchase.items)
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<Map<String, dynamic>> getPriceHistoryForProduct(int productId) async {
    final items = await getPurchaseItemsByProduct(productId);
    final grouped = <String, List<PurchaseItem>>{};
    for (final item in items) {
      final date = item.createdAt.toIso8601String().split('T')[0];
      grouped.putIfAbsent(date, () => []).add(item);
    }
    final history = grouped.entries.map((entry) {
      final dayItems = entry.value;
      return {
        'date': entry.key,
        'avgPricePerBaseUnit':
            dayItems.fold(0.0, (total, item) => total + item.pricePerBaseUnit) /
            dayItems.length,
        'totalQuantity': dayItems.fold(
          0.0,
          (total, item) => total + item.unit.toBaseUnit(item.quantity),
        ),
        'count': dayItems.length,
      };
    }).toList();
    history.sort(
      (a, b) => (a['date'] as String).compareTo(b['date'] as String),
    );
    return {'productId': productId, 'history': history};
  }

  Future<int> insertOrUpdateBudget(MonthlyBudget budget) async {
    final id = budget.id ?? budget.year * 100 + budget.month;
    await _budgets
        .doc('${budget.year}-${budget.month}')
        .set(budget.copyWith(id: id, updatedAt: DateTime.now()).toMap());
    return id;
  }

  Future<MonthlyBudget?> getBudget(int year, int month) async {
    final snapshot = await _budgets.doc('$year-$month').get();
    final data = snapshot.data();
    return data == null ? null : MonthlyBudget.fromMap(data);
  }

  Future<List<MonthlyBudget>> getAllBudgets() async {
    final snapshot = await _budgets.get();
    final budgets = snapshot.docs
        .map((doc) => MonthlyBudget.fromMap(doc.data()))
        .toList();
    budgets.sort((a, b) {
      final yearOrder = b.year.compareTo(a.year);
      return yearOrder != 0 ? yearOrder : b.month.compareTo(a.month);
    });
    return budgets;
  }

  Future<int> deleteBudget(int year, int month) async {
    await _budgets.doc('$year-$month').delete();
    return 1;
  }

  Future<double> getTotalSpentInMonth(int year, int month) async {
    return (await getPurchasesByMonth(
      year,
      month,
    )).fold<double>(0.0, (total, purchase) => total + purchase.totalAmount);
  }

  Future<Map<Category, double>> getTotalByCategoryInMonth(
    int year,
    int month,
  ) async {
    final totals = <Category, double>{};
    for (final purchase in await getPurchasesByMonth(year, month)) {
      for (final item in purchase.items) {
        totals[item.category] = (totals[item.category] ?? 0) + item.pricePaid;
      }
    }
    return totals;
  }

  Future<List<Map<String, dynamic>>> getTopProducts(
    int year,
    int month, {
    int limit = 10,
  }) async {
    final grouped = <String, Map<String, dynamic>>{};
    for (final purchase in await getPurchasesByMonth(year, month)) {
      for (final item in purchase.items) {
        final key =
            '${item.productName}|${item.category.name}|${item.unit.name}';
        final product = grouped.putIfAbsent(
          key,
          () => {
            'productName': item.productName,
            'category': item.category.name,
            'totalQuantity': 0.0,
            'unit': item.unit.name,
            'purchaseCount': 0,
            'totalSpent': 0.0,
          },
        );
        product['totalQuantity'] =
            (product['totalQuantity'] as double) + item.quantity;
        product['purchaseCount'] = (product['purchaseCount'] as int) + 1;
        product['totalSpent'] =
            (product['totalSpent'] as double) + item.pricePaid;
      }
    }
    final results = grouped.values.toList()
      ..sort((a, b) {
        final countOrder = (b['purchaseCount'] as int).compareTo(
          a['purchaseCount'] as int,
        );
        if (countOrder != 0) return countOrder;
        return (b['totalQuantity'] as double).compareTo(
          a['totalQuantity'] as double,
        );
      });
    return results.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> getMonthlyTotals({int limit = 12}) async {
    final totals = <String, double>{};
    for (final purchase in await _getPurchases()) {
      final month =
          '${purchase.date.year}-${purchase.date.month.toString().padLeft(2, '0')}';
      totals[month] = (totals[month] ?? 0) + purchase.totalAmount;
    }
    final results =
        totals.entries
            .map((entry) => {'month': entry.key, 'total': entry.value})
            .toList()
          ..sort(
            (a, b) => (b['month'] as String).compareTo(a['month'] as String),
          );
    return results.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> getCategoryTotalsByMonth(
    int year,
    int month,
  ) async {
    final totals = await getTotalByCategoryInMonth(year, month);
    final results =
        totals.entries
            .map((entry) => {'category': entry.key.name, 'total': entry.value})
            .toList()
          ..sort(
            (a, b) => (b['total'] as double).compareTo(a['total'] as double),
          );
    return results;
  }

  Future<Map<String, dynamic>> exportAllData() async {
    final products = await getAllProducts();
    final purchases = await getAllPurchases();
    final budgets = await getAllBudgets();
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'products': products.map((product) => product.toMap()).toList(),
      'purchases': purchases
          .map(
            (purchase) => {
              ...purchase.toMap(),
              'items': purchase.items.map((item) => item.toMap()).toList(),
            },
          )
          .toList(),
      'budgets': budgets.map((budget) => budget.toMap()).toList(),
    };
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    if (data['products'] is! List || data['purchases'] is! List) {
      throw const FormatException('Arquivo de backup inválido.');
    }
    final products = (data['products'] as List).map((raw) {
      final product = Product.fromMap(Map<String, dynamic>.from(raw as Map));
      if (product.id == null) {
        throw const FormatException('Produto sem id no backup.');
      }
      return product;
    }).toList();
    final purchases = <Purchase>[];
    final itemsByPurchase = <int, List<PurchaseItem>>{};
    for (final raw in data['purchases'] as List) {
      final purchaseData = Map<String, dynamic>.from(raw as Map);
      final rawItems = purchaseData.remove('items');
      if (rawItems is! List) {
        throw const FormatException('Itens da compra inválidos no backup.');
      }
      final purchase = Purchase.fromMap(purchaseData);
      final purchaseId = purchase.id;
      if (purchaseId == null) {
        throw const FormatException('Compra sem id no backup.');
      }
      purchases.add(purchase);
      itemsByPurchase[purchaseId] = rawItems
          .map(
            (item) =>
                PurchaseItem.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    }
    final budgets = (data['budgets'] as List? ?? const [])
        .map(
          (raw) => MonthlyBudget.fromMap(Map<String, dynamic>.from(raw as Map)),
        )
        .toList();

    final user = _userDocument;
    final purchaseSnapshots = await _purchases.get();
    final deleteOperations = <void Function(WriteBatch)>[];
    for (final purchase in purchaseSnapshots.docs) {
      final items = await purchase.reference.collection('items').get();
      deleteOperations.addAll(
        items.docs.map<void Function(WriteBatch)>(
          (item) => (batch) {
            batch.delete(item.reference);
          },
        ),
      );
      deleteOperations.add((batch) => batch.delete(purchase.reference));
    }
    final productsSnapshot = await _products.get();
    deleteOperations.addAll(
      productsSnapshot.docs.map<void Function(WriteBatch)>(
        (doc) => (batch) {
          batch.delete(doc.reference);
        },
      ),
    );
    final budgetsSnapshot = await _budgets.get();
    deleteOperations.addAll(
      budgetsSnapshot.docs.map<void Function(WriteBatch)>(
        (doc) => (batch) {
          batch.delete(doc.reference);
        },
      ),
    );
    await _writeInChunks(deleteOperations);

    final writeOperations = <void Function(WriteBatch)>[];
    var maxProductId = 0;
    for (final product in products) {
      final id = product.id!;
      if (id > maxProductId) maxProductId = id;
      writeOperations.add((batch) {
        batch.set(_products.doc('$id'), product.toMap());
      });
    }

    var maxPurchaseId = 0;
    for (final purchase in purchases) {
      final id = purchase.id!;
      if (id > maxPurchaseId) maxPurchaseId = id;
      writeOperations.add((batch) {
        batch.set(_purchases.doc('$id'), purchase.toMap());
      });
      final items = itemsByPurchase[id]!;
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final itemId = item.id ?? index + 1;
        writeOperations.add((batch) {
          batch.set(
            _purchases.doc('$id').collection('items').doc('$itemId'),
            item.copyWith(id: itemId, purchaseId: id).toMap(),
          );
        });
      }
    }

    for (final budget in budgets) {
      writeOperations.add((batch) {
        batch.set(
          _budgets.doc('${budget.year}-${budget.month}'),
          budget.toMap(),
        );
      });
    }

    await _writeInChunks(writeOperations);
    await user.collection('metadata').doc('counters').set({
      'product': maxProductId,
      'purchase': maxPurchaseId,
    }, SetOptions(merge: true));
  }

  Future<void> close() async {}
}
