import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/unit.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<ShoppingListItem> _items = [];
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  Category _selectedCategory = Category.pantryBasics;
  Unit _selectedUnit = Unit.unit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadShoppingList();
    });
  }

  @override
  void dispose() {
    _productController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _loadShoppingList() {
    final provider = context.read<AppProvider>();
    final missingEssentials = provider.getMissingEssentialsForCurrentMonth();
    final mostPurchased = provider.getMostPurchasedProducts(limit: 10);
    
    final Set<int> addedIds = {};
    final List<ShoppingListItem> items = [];
    
    // Adicionar essenciais faltando primeiro
    for (final product in missingEssentials) {
      items.add(ShoppingListItem(
        product: product,
        quantity: 1,
        unit: Unit.unit,
        isEssential: true,
        isChecked: false,
      ));
      addedIds.add(product.id!);
    }
    
    // Adicionar mais comprados que não são essenciais
    for (final product in mostPurchased) {
      if (!addedIds.contains(product.id)) {
        items.add(ShoppingListItem(
          product: product,
          quantity: 1,
          unit: Unit.unit,
          isEssential: false,
          isChecked: false,
        ));
        addedIds.add(product.id!);
      }
    }
    
    // Adicionar produtos incluídos manualmente (ex.: pela tela inicial)
    for (final product in provider.shoppingListAdditions) {
      if (product.id != null && addedIds.contains(product.id)) continue;
      items.add(ShoppingListItem(
        product: product,
        quantity: 1,
        unit: Unit.unit,
        isEssential: product.isEssential,
        isChecked: false,
      ));
      if (product.id != null) addedIds.add(product.id!);
    }

    setState(() {
      _items = items;
    });
  }

  void _toggleItem(int index) {
    setState(() {
      _items[index] = _items[index].copyWith(isChecked: !_items[index].isChecked);
    });
  }

  void _removeItem(int index) {
    context.read<AppProvider>().removeFromShoppingListAdditions(_items[index].product);
    setState(() {
      _items.removeAt(index);
    });
  }

  void _addCustomItem() {
    if (_productController.text.trim().isEmpty) return;
    
    setState(() {
      _items.insert(0, ShoppingListItem(
        product: Product(
          name: _productController.text.trim(),
          category: _selectedCategory,
        ),
        quantity: double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1,
        unit: _selectedUnit,
        isEssential: false,
        isChecked: false,
      ));
      _productController.clear();
      _quantityController.clear();
    });
  }

  void _clearCheckedItems() {
    final provider = context.read<AppProvider>();
    for (final item in _items.where((i) => i.isChecked)) {
      provider.removeFromShoppingListAdditions(item.product);
    }
    setState(() {
      _items.removeWhere((item) => item.isChecked);
    });
  }

  void _checkAll() {
    setState(() {
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(isChecked: true);
      }
    });
  }

  void _uncheckAll() {
    setState(() {
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(isChecked: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkedCount = _items.where((i) => i.isChecked).length;
    final totalCount = _items.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Compras'),
        actions: [
          if (totalCount > 0) ...[
            TextButton.icon(
              onPressed: checkedCount > 0 ? _clearCheckedItems : null,
              icon: const Icon(Icons.delete_sweep),
              label: Text('Limpar ($checkedCount)'),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'check_all':
                    _checkAll();
                    break;
                  case 'uncheck_all':
                    _uncheckAll();
                    break;
                  case 'reload':
                    _loadShoppingList();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'check_all',
                  child: Row(
                    children: [
                      Icon(Icons.check_box, size: 20),
                      SizedBox(width: 8),
                      Text('Marcar todos'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'uncheck_all',
                  child: Row(
                    children: [
                      Icon(Icons.check_box_outline_blank, size: 20),
                      SizedBox(width: 8),
                      Text('Desmarcar todos'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reload',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Recarregar sugestões'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Progresso
          if (totalCount > 0)
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progresso: $checkedCount de $totalCount',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${((checkedCount / totalCount) * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: totalCount > 0 ? checkedCount / totalCount : 0,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),
          
          // Lista de itens
          Expanded(
            child: _items.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.checklist,
                    title: 'Lista vazia',
                    message: 'Toque em "+" para adicionar itens ou recarregue para ver sugestões baseadas nos seus essenciais e produtos mais comprados.',
                    action: FilledButton.icon(
                      onPressed: _loadShoppingList,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Carregar Sugestões'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildItemCard(item, index);
                    },
                  ),
          ),
          
          // Adicionar item personalizado
          _buildAddItemForm(),
        ],
      ),
    );
  }

  Widget _buildItemCard(ShoppingListItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: item.isChecked,
        onChanged: (_) => _toggleItem(index),
        title: Text(
          item.product.name,
          style: TextStyle(
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
            color: item.isChecked
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.product.category.icon,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(item.product.category.label),
                if (item.isEssential) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ESSENCIAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (item.quantity > 0)
              Text(
                'Qtd: ${NumberFormatter.format(item.quantity)} ${item.unit.shortName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        secondary: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _removeItem(index),
          tooltip: 'Remover',
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildAddItemForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adicionar Item',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _productController,
              decoration: const InputDecoration(
                labelText: 'Nome do produto',
                hintText: 'Ex: Arroz, Leite, Tomate...',
                prefixIcon: Icon(Icons.add),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onFieldSubmitted: (_) => _addCustomItem(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: QuantityInputField(
                    controller: _quantityController,
                    labelText: 'Quantidade',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: UnitSelector(
                    selectedUnit: _selectedUnit,
                    onChanged: (unit) => setState(() => _selectedUnit = unit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Category>(
              key: ValueKey(_selectedCategory),
              initialValue: _selectedCategory,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: Category.values.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(cat.icon, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(cat.label, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (cat) {
                if (cat != null) setState(() => _selectedCategory = cat);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addCustomItem,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar à Lista'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShoppingListItem {
  final Product product;
  final double quantity;
  final Unit unit;
  final bool isEssential;
  final bool isChecked;

  ShoppingListItem({
    required this.product,
    required this.quantity,
    required this.unit,
    required this.isEssential,
    required this.isChecked,
  });

  ShoppingListItem copyWith({
    Product? product,
    double? quantity,
    Unit? unit,
    bool? isEssential,
    bool? isChecked,
  }) {
    return ShoppingListItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isEssential: isEssential ?? this.isEssential,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}