import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../models/budget.dart';
import '../models/category.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'feira_facil.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        isEssential INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        location TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchaseId INTEGER NOT NULL,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        pricePaid REAL NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (purchaseId) REFERENCES purchases (id) ON DELETE CASCADE,
        FOREIGN KEY (productId) REFERENCES products (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE monthly_budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        amount REAL NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        UNIQUE(year, month)
      )
    ''');

    // Índices para performance
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db.execute('CREATE INDEX idx_products_category ON products(category)');
    await db.execute('CREATE INDEX idx_products_essential ON products(isEssential)');
    await db.execute('CREATE INDEX idx_purchases_date ON purchases(date)');
    await db.execute('CREATE INDEX idx_purchase_items_purchase ON purchase_items(purchaseId)');
    await db.execute('CREATE INDEX idx_purchase_items_product ON purchase_items(productId)');
    await db.execute('CREATE INDEX idx_purchase_items_category ON purchase_items(category)');
  }

  // ==================== PRODUCTS ====================

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'name ASC');
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<List<Product>> getProductsByCategory(Category category) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'category = ?',
      whereArgs: [category.name],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<List<Product>> getEssentialProducts() async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'isEssential = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
      limit: 10,
    );
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<Product?> getProductByName(String name) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  // ==================== PURCHASES ====================

  Future<int> insertPurchase(Purchase purchase) async {
    final db = await database;
    return await db.transaction((txn) async {
      final purchaseId = await txn.insert('purchases', purchase.toMap());
      
      for (final item in purchase.items) {
        await txn.insert('purchase_items', item.copyWith(purchaseId: purchaseId).toMap());
      }
      
      return purchaseId;
    });
  }

  Future<int> updatePurchase(Purchase purchase) async {
    final db = await database;
    return await db.transaction((txn) async {
      await txn.update(
        'purchases',
        purchase.copyWith(updatedAt: DateTime.now()).toMap(),
        where: 'id = ?',
        whereArgs: [purchase.id],
      );
      
      // Deletar itens antigos
      await txn.delete('purchase_items', where: 'purchaseId = ?', whereArgs: [purchase.id]);
      
      // Inserir novos itens
      for (final item in purchase.items) {
        await txn.insert('purchase_items', item.copyWith(purchaseId: purchase.id!).toMap());
      }
      
      return purchase.id!;
    });
  }

  Future<int> deletePurchase(int id) async {
    final db = await database;
    return await db.delete('purchases', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Purchase>> getAllPurchases() async {
    final db = await database;
    final purchaseMaps = await db.query('purchases', orderBy: 'date DESC');
    
    final purchases = <Purchase>[];
    for (final purchaseMap in purchaseMaps) {
      final purchase = Purchase.fromMap(purchaseMap);
      final itemMaps = await db.query(
        'purchase_items',
        where: 'purchaseId = ?',
        whereArgs: [purchase.id],
      );
      final items = itemMaps.map((map) => PurchaseItem.fromMap(map)).toList();
      purchases.add(purchase.copyWith(items: items));
    }
    
    return purchases;
  }

  Future<List<Purchase>> getPurchasesByMonth(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);
    
    final purchaseMaps = await db.query(
      'purchases',
      where: 'date >= ? AND date < ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date DESC',
    );
    
    final purchases = <Purchase>[];
    for (final purchaseMap in purchaseMaps) {
      final purchase = Purchase.fromMap(purchaseMap);
      final itemMaps = await db.query(
        'purchase_items',
        where: 'purchaseId = ?',
        whereArgs: [purchase.id],
      );
      final items = itemMaps.map((map) => PurchaseItem.fromMap(map)).toList();
      purchases.add(purchase.copyWith(items: items));
    }
    
    return purchases;
  }

  Future<Purchase?> getPurchaseById(int id) async {
    final db = await database;
    final purchaseMaps = await db.query(
      'purchases',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (purchaseMaps.isEmpty) return null;
    
    final purchase = Purchase.fromMap(purchaseMaps.first);
    final itemMaps = await db.query(
      'purchase_items',
      where: 'purchaseId = ?',
      whereArgs: [id],
    );
    final items = itemMaps.map((map) => PurchaseItem.fromMap(map)).toList();
    
    return purchase.copyWith(items: items);
  }

  // ==================== PURCHASE ITEMS ====================

  Future<List<PurchaseItem>> getPurchaseItemsByProduct(int productId) async {
    final db = await database;
    final maps = await db.query(
      'purchase_items',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => PurchaseItem.fromMap(map)).toList();
  }

  Future<PurchaseItem?> getLastPurchaseItemByProduct(int productId) async {
    final db = await database;
    final maps = await db.query(
      'purchase_items',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PurchaseItem.fromMap(maps.first);
  }

  Future<List<PurchaseItem>> getAllPurchaseItems() async {
    final db = await database;
    final maps = await db.query('purchase_items', orderBy: 'createdAt DESC');
    return maps.map((map) => PurchaseItem.fromMap(map)).toList();
  }

  Future<Map<String, dynamic>> getPriceHistoryForProduct(int productId) async {
    final db = await database;
    final maps = await db.query(
      'purchase_items',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'createdAt ASC',
    );
    
    final items = maps.map((map) => PurchaseItem.fromMap(map)).toList();
    
    // Agrupar por data (dia)
    final Map<String, List<PurchaseItem>> grouped = {};
    for (final item in items) {
      final dateKey = item.createdAt.toIso8601String().split('T')[0];
      grouped.putIfAbsent(dateKey, () => []).add(item);
    }
    
    // Calcular média por dia
    final List<Map<String, dynamic>> history = [];
    grouped.forEach((date, dayItems) {
      final avgPrice = dayItems.fold(0.0, (sum, item) => sum + item.pricePerBaseUnit) / dayItems.length;
      final totalQty = dayItems.fold(0.0, (sum, item) => sum + item.unit.toBaseUnit(item.quantity));
      history.add({
        'date': date,
        'avgPricePerBaseUnit': avgPrice,
        'totalQuantity': totalQty,
        'count': dayItems.length,
      });
    });
    
    return {
      'productId': productId,
      'history': history,
    };
  }

  // ==================== BUDGET ====================

  Future<int> insertOrUpdateBudget(MonthlyBudget budget) async {
    final db = await database;
    return await db.insert(
      'monthly_budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MonthlyBudget?> getBudget(int year, int month) async {
    final db = await database;
    final maps = await db.query(
      'monthly_budgets',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return MonthlyBudget.fromMap(maps.first);
  }

  Future<List<MonthlyBudget>> getAllBudgets() async {
    final db = await database;
    final maps = await db.query('monthly_budgets', orderBy: 'year DESC, month DESC');
    return maps.map((map) => MonthlyBudget.fromMap(map)).toList();
  }

  Future<int> deleteBudget(int year, int month) async {
    final db = await database;
    return await db.delete(
      'monthly_budgets',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
    );
  }

  // ==================== STATISTICS ====================

  Future<double> getTotalSpentInMonth(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);
    
    final result = await db.rawQuery('''
      SELECT SUM(pricePaid) as total
      FROM purchase_items pi
      JOIN purchases p ON pi.purchaseId = p.id
      WHERE p.date >= ? AND p.date < ?
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);
    
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<Category, double>> getTotalByCategoryInMonth(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);
    
    final results = await db.rawQuery('''
      SELECT category, SUM(pricePaid) as total
      FROM purchase_items pi
      JOIN purchases p ON pi.purchaseId = p.id
      WHERE p.date >= ? AND p.date < ?
      GROUP BY category
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);
    
    final map = <Category, double>{};
    for (final row in results) {
      map[Category.fromString(row['category'] as String)] = (row['total'] as num).toDouble();
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> getTopProducts(int year, int month, {int limit = 10}) async {
    final db = await database;
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);
    
    return await db.rawQuery('''
      SELECT productName, category, SUM(quantity) as totalQuantity, unit, COUNT(*) as purchaseCount, SUM(pricePaid) as totalSpent
      FROM purchase_items pi
      JOIN purchases p ON pi.purchaseId = p.id
      WHERE p.date >= ? AND p.date < ?
      GROUP BY productName, category, unit
      ORDER BY purchaseCount DESC, totalQuantity DESC
      LIMIT ?
    ''', [startDate.toIso8601String(), endDate.toIso8601String(), limit]);
  }

  Future<List<Map<String, dynamic>>> getMonthlyTotals({int limit = 12}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT strftime('%Y-%m', date) as month, SUM(pricePaid) as total
      FROM purchase_items pi
      JOIN purchases p ON pi.purchaseId = p.id
      GROUP BY strftime('%Y-%m', date)
      ORDER BY month DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<List<Map<String, dynamic>>> getCategoryTotalsByMonth(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);
    
    return await db.rawQuery('''
      SELECT category, SUM(pricePaid) as total
      FROM purchase_items pi
      JOIN purchases p ON pi.purchaseId = p.id
      WHERE p.date >= ? AND p.date < ?
      GROUP BY category
      ORDER BY total DESC
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);
  }

  // ==================== BACKUP/RESTORE ====================

  Future<Map<String, dynamic>> exportAllData() async {
    final products = await getAllProducts();
    final purchases = await getAllPurchases();
    final budgets = await getAllBudgets();
    
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'products': products.map((p) => p.toMap()).toList(),
      'purchases': purchases.map((p) => {
        ...p.toMap(),
        'items': p.items.map((i) => i.toMap()).toList(),
      }).toList(),
      'budgets': budgets.map((b) => b.toMap()).toList(),
    };
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      // Limpar dados existentes
      await txn.delete('purchase_items');
      await txn.delete('purchases');
      await txn.delete('products');
      await txn.delete('monthly_budgets');
      
      // Inserir produtos
      for (final productMap in data['products'] as List) {
        await txn.insert('products', productMap);
      }
      
      // Inserir compras e itens
      for (final purchaseMap in data['purchases'] as List) {
        final items = purchaseMap['items'] as List;
        purchaseMap.remove('items');
        final purchaseId = await txn.insert('purchases', purchaseMap);
        
        for (final itemMap in items) {
          await txn.insert('purchase_items', {
            ...itemMap,
            'purchaseId': purchaseId,
          });
        }
      }
      
      // Inserir orçamentos
      for (final budgetMap in data['budgets'] as List) {
        await txn.insert('monthly_budgets', budgetMap);
      }
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}