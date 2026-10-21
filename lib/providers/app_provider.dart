import 'package:flutter/foundation.dart' hide Category;

import '../models/category.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../models/budget.dart';
import '../database/firestore_database_helper.dart';

class AppProvider extends ChangeNotifier {
  final FirestoreDatabaseHelper _db = FirestoreDatabaseHelper();

  // Products
  List<Product> _products = [];
  List<Product> _essentialProducts = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = '';

  // Purchases
  List<Purchase> _purchases = [];
  List<Purchase> _currentMonthPurchases = [];
  Purchase? _currentPurchase;

  // Budget
  MonthlyBudget? _currentMonthBudget;
  double _currentMonthSpent = 0.0;

  // Loading states
  bool _isLoading = false;
  String? _error;

  // Produtos adicionados manualmente à lista de compras (ex.: pela tela inicial)
  final List<Product> _shoppingListAdditions = [];

  // Getters
  List<Product> get products =>
      _filteredProducts.isEmpty ? _products : _filteredProducts;
  List<Product> get allProducts => _products;
  List<Product> get essentialProducts => _essentialProducts;
  List<Purchase> get purchases => _purchases;
  List<Purchase> get currentMonthPurchases => _currentMonthPurchases;
  Purchase? get currentPurchase => _currentPurchase;
  MonthlyBudget? get currentMonthBudget => _currentMonthBudget;
  double get currentMonthSpent => _currentMonthSpent;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  List<Product> get shoppingListAdditions =>
      List.unmodifiable(_shoppingListAdditions);

  /// Adiciona um produto à lista de compras. Retorna false se já estava na lista.
  bool addProductToShoppingList(Product product) {
    if (_shoppingListAdditions.any((p) => p.id == product.id)) return false;
    _shoppingListAdditions.add(product);
    notifyListeners();
    return true;
  }

  void removeFromShoppingListAdditions(Product product) {
    _shoppingListAdditions.removeWhere((p) => p.id == product.id);
  }

  // Initialize
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _loadProducts();
      await _loadPurchases();
      await _loadCurrentMonthData();
      _setError(null);
    } catch (e) {
      _setError('Erro ao inicializar: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // ==================== PRODUCTS ====================

  Future<void> _loadProducts() async {
    _products = await _db.getAllProducts();
    _essentialProducts = _products.where((p) => p.isEssential).toList();
    _applyFilter();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredProducts = [];
    } else {
      _filteredProducts = _products
          .where(
            (p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilter();
  }

  Future<Product?> getProductByName(String name) async {
    return await _db.getProductByName(name);
  }

  Future<List<Product>> searchProducts(String query) async {
    return await _db.searchProducts(query);
  }

  Future<void> addProduct(Product product) async {
    _setLoading(true);
    try {
      final id = await _db.insertProduct(product);
      final newProduct = product.copyWith(id: id);
      _products.add(newProduct);
      if (newProduct.isEssential) {
        _essentialProducts.add(newProduct);
      }
      _products.sort((a, b) => a.name.compareTo(b.name));
      _applyFilter();
      _setError(null);
    } catch (e) {
      _setError('Erro ao adicionar produto: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProduct(Product product) async {
    _setLoading(true);
    try {
      await _db.updateProduct(product);
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        _products.sort((a, b) => a.name.compareTo(b.name));
      }
      _essentialProducts = _products.where((p) => p.isEssential).toList();
      _applyFilter();
      _setError(null);
    } catch (e) {
      _setError('Erro ao atualizar produto: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteProduct(int id) async {
    _setLoading(true);
    try {
      await _db.deleteProduct(id);
      _products.removeWhere((p) => p.id == id);
      _essentialProducts.removeWhere((p) => p.id == id);
      _applyFilter();
      _setError(null);
    } catch (e) {
      _setError('Erro ao deletar produto: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleEssential(int productId) async {
    final product = _products.firstWhere((p) => p.id == productId);
    final updated = product.copyWith(isEssential: !product.isEssential);
    await updateProduct(updated);
  }

  // ==================== PURCHASES ====================

  Future<void> _loadPurchases() async {
    _purchases = await _db.getAllPurchases();
    notifyListeners();
  }

  Future<void> _loadCurrentMonthData() async {
    final now = DateTime.now();
    _currentMonthPurchases = await _db.getPurchasesByMonth(now.year, now.month);
    _currentMonthBudget = await _db.getBudget(now.year, now.month);
    _currentMonthSpent = await _db.getTotalSpentInMonth(now.year, now.month);
    notifyListeners();
  }

  void startNewPurchase({DateTime? date, String location = 'Mercado'}) {
    _currentPurchase = Purchase(
      date: date ?? DateTime.now(),
      location: location,
      items: [],
    );
    notifyListeners();
  }

  void updateCurrentPurchaseDetails({
    required DateTime date,
    required String location,
  }) {
    if (_currentPurchase == null) return;

    _currentPurchase = _currentPurchase!.copyWith(
      date: date,
      location: location.trim(),
    );

    notifyListeners();
  }

  void addItemToCurrentPurchase(PurchaseItem item) {
    if (_currentPurchase != null) {
      _currentPurchase = _currentPurchase!.copyWith(
        items: [..._currentPurchase!.items, item],
      );
      notifyListeners();
    }
  }

  void removeItemFromCurrentPurchase(int index) {
    if (_currentPurchase != null &&
        index >= 0 &&
        index < _currentPurchase!.items.length) {
      final items = List<PurchaseItem>.from(_currentPurchase!.items);
      items.removeAt(index);
      _currentPurchase = _currentPurchase!.copyWith(items: items);
      notifyListeners();
    }
  }

  void updateItemInCurrentPurchase(int index, PurchaseItem item) {
    if (_currentPurchase != null &&
        index >= 0 &&
        index < _currentPurchase!.items.length) {
      final items = List<PurchaseItem>.from(_currentPurchase!.items);
      items[index] = item;
      _currentPurchase = _currentPurchase!.copyWith(items: items);
      notifyListeners();
    }
  }

  Future<void> saveCurrentPurchase() async {
    if (_currentPurchase == null || _currentPurchase!.items.isEmpty) {
      _setError('Adicione pelo menos um item à compra');
      return;
    }

    _setLoading(true);
    try {
      final id = await _db.insertPurchase(_currentPurchase!);
      final savedPurchase = _currentPurchase!.copyWith(id: id);
      _purchases.insert(0, savedPurchase);

      // Recarregar dados do mês atual
      await _loadCurrentMonthData();

      _currentPurchase = null;
      _setError(null);
    } catch (e) {
      _setError('Erro ao salvar compra: $e');
    } finally {
      _setLoading(false);
    }
  }

  void cancelCurrentPurchase() {
    _currentPurchase = null;
    notifyListeners();
  }

  Future<void> deletePurchase(int id) async {
    _setLoading(true);
    try {
      await _db.deletePurchase(id);
      _purchases.removeWhere((p) => p.id == id);
      await _loadCurrentMonthData();
      _setError(null);
    } catch (e) {
      _setError('Erro ao deletar compra: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<PurchaseItem?> getLastPriceForProduct(int productId) async {
    return await _db.getLastPurchaseItemByProduct(productId);
  }

  Future<Map<String, dynamic>> getPriceHistoryForProduct(int productId) async {
    return await _db.getPriceHistoryForProduct(productId);
  }

  // ==================== BUDGET ====================

  Future<void> setBudget(double amount) async {
    final now = DateTime.now();
    final budget = MonthlyBudget(
      year: now.year,
      month: now.month,
      amount: amount,
    );

    _setLoading(true);
    try {
      await _db.insertOrUpdateBudget(budget);
      _currentMonthBudget = budget;
      _setError(null);
    } catch (e) {
      _setError('Erro ao definir orçamento: $e');
    } finally {
      _setLoading(false);
    }
  }

  double get budgetProgress {
    if (_currentMonthBudget == null || _currentMonthBudget!.amount <= 0) {
      return 0.0;
    }
    return (_currentMonthSpent / _currentMonthBudget!.amount).clamp(0.0, 1.0);
  }

  bool get isOverBudget {
    if (_currentMonthBudget == null) return false;
    return _currentMonthSpent > _currentMonthBudget!.amount;
  }

  // ==================== REPORTS ====================

  Future<Map<Category, double>> getCategoryTotalsForMonth(
    int year,
    int month,
  ) async {
    return await _db.getTotalByCategoryInMonth(year, month);
  }

  Future<List<Map<String, dynamic>>> getTopProductsForMonth(
    int year,
    int month, {
    int limit = 10,
  }) async {
    return await _db.getTopProducts(year, month, limit: limit);
  }

  Future<List<Map<String, dynamic>>> getMonthlyTotals({int limit = 12}) async {
    return await _db.getMonthlyTotals(limit: limit);
  }

  // ==================== BACKUP ====================

  Future<Map<String, dynamic>> exportData() async {
    return await _db.exportAllData();
  }

  Future<void> importData(Map<String, dynamic> data) async {
    _setLoading(true);
    try {
      await _db.importAllData(data);
      await initialize();
      _setError(null);
    } catch (e) {
      _setError('Erro ao importar dados: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ==================== ESSENTIALS ====================

  List<Product> getMissingEssentialsForCurrentMonth() {
    final purchasedProductIds = <int>{};

    for (final purchase in _currentMonthPurchases) {
      for (final item in purchase.items) {
        purchasedProductIds.add(item.productId);
      }
    }

    return _essentialProducts
        .where((p) => !purchasedProductIds.contains(p.id))
        .toList();
  }

  List<Product> getMostPurchasedProducts({int limit = 20}) {
    final productCounts = <int, int>{};

    for (final purchase in _purchases) {
      for (final item in purchase.items) {
        productCounts[item.productId] =
            (productCounts[item.productId] ?? 0) + 1;
      }
    }

    final sortedProducts = _products
        .where((p) => productCounts[p.id!] != null)
        .toList();
    sortedProducts.sort(
      (a, b) =>
          (productCounts[b.id!] ?? 0).compareTo(productCounts[a.id!] ?? 0),
    );

    return sortedProducts.take(limit).toList();
  }
}
