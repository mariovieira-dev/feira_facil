import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../models/category.dart';
import '../models/unit.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';


class NewPurchaseScreen extends StatefulWidget {
  final bool isTab;

  const NewPurchaseScreen({
    super.key,
    this.isTab = false,
  });

  @override
  State<NewPurchaseScreen> createState() =>
      _NewPurchaseScreenState();
}


class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController(text: 'Mercado');
  DateTime _selectedDate = DateTime.now();
  Category _selectedCategory = Category.pantryBasics;
  Unit _selectedUnit = Unit.unit;
  
  // Item form controllers
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _productFocusNode = FocusNode();
  
  Product? _selectedProduct;
  PurchaseItem? _editingItem;
  int _editingIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      if (provider.currentPurchase == null) {
        provider.startNewPurchase();
      }
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _productFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _onProductSelected(Product? product) {
    setState(() {
      _selectedProduct = product;
      if (product != null) {
        _selectedCategory = product.category;
        // Preencher com última unidade usada se disponível
      }
    });
  }

  void _onProductNameChanged(String name) {
    setState(() {
      _selectedProduct = null;
    });
  }

  Future<void> _addOrUpdateItem() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Buscar ou criar produto
    Product product;
    if (_selectedProduct != null) {
      product = _selectedProduct!;
    } else {
      // Verificar se já existe
      final existing = await provider.getProductByName(_productController.text.trim());
      if (existing != null) {
        product = existing;
      } else {
        // Criar novo produto
        final newProduct = Product(
          name: _productController.text.trim(),
          category: _selectedCategory,
        );
        await provider.addProduct(newProduct);

        // O objeto acima ainda não tem "id" (ele só existe depois de salvar no banco),
        // então buscamos o produto salvo para obter o id.
        final saved = await provider.getProductByName(newProduct.name);
        if (saved == null || saved.id == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.error ?? 'Não foi possível salvar o produto')),
          );
          return;
        }
        product = saved;
      }
    }

    final quantity = double.parse(_quantityController.text.replaceAll(',', '.'));
    final pricePaid = double.parse(_priceController.text.replaceAll(',', '.'));

    final item = PurchaseItem(
      purchaseId: 0, // Será definido ao salvar
      productId: product.id!,
      productName: product.name,
      category: _selectedCategory,
      quantity: quantity,
      unit: _selectedUnit,
      pricePaid: pricePaid,
    );

    if (_editingItem != null) {
      provider.updateItemInCurrentPurchase(_editingIndex, item);
      _cancelEditing();
    } else {
      provider.addItemToCurrentPurchase(item);
      _clearItemForm();
    }
  }

  void _clearItemForm() {
    _productController.clear();
    _quantityController.clear();
    _priceController.clear();
    _selectedProduct = null;
    _selectedCategory = Category.pantryBasics;
    _selectedUnit = Unit.unit;
    _productFocusNode.requestFocus();
  }

  void _startEditingItem(int index, PurchaseItem item) {
    setState(() {
      _editingItem = item;
      _editingIndex = index;
      _productController.text = item.productName;
      _quantityController.text = NumberFormatter.format(item.quantity);
      _priceController.text = NumberFormatter.format(item.pricePaid, decimals: 2);
      _selectedCategory = item.category;
      _selectedUnit = item.unit;
      _selectedProduct = null; // Não pré-selecionar para permitir mudança
    });
    _productFocusNode.requestFocus();
  }

  void _cancelEditing() {
    setState(() {
      _editingItem = null;
      _editingIndex = -1;
      _clearItemForm();
    });
  }

  void _removeItem(int index) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.removeItemFromCurrentPurchase(index);
  }

  /*Future<void> _savePurchase() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    if (provider.currentPurchase?.items.isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos um item à compra')),
      );
      return;
    }

    await provider.saveCurrentPurchase();
    
    if (mounted && provider.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compra salva com sucesso!')),
      );
      Navigator.pop(context);
    }
  }*/


Future<void> _savePurchase() async {
  final provider = Provider.of<AppProvider>(
    context,
    listen: false,
  );

  if (provider.currentPurchase?.items.isEmpty ?? true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Adicione pelo menos um item à compra'),
      ),
    );
    return;
  }

  // Salva a data e o local escolhidos.
  provider.updateCurrentPurchaseDetails(
    date: _selectedDate,
    location: _locationController.text.trim(),
  );

  await provider.saveCurrentPurchase();

  if (!mounted) return;

  if (provider.error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(provider.error!)),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Compra salva com sucesso!'),
    ),
  );

  if (widget.isTab) {
    // Reinicia o formulário sem fechar a navegação principal.
    setState(() {
      _selectedDate = DateTime.now();
      _locationController.text = 'Mercado';
      _selectedProduct = null;
      _editingItem = null;
      _editingIndex = -1;
      _clearItemForm();
    });

    provider.startNewPurchase();
  } else if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
}


  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final purchase = provider.currentPurchase;
        final items = purchase?.items ?? [];
        final total = purchase?.totalAmount ?? 0.0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nova Compra'),
            actions: [
              if (items.isNotEmpty)
                TextButton.icon(
                  onPressed: _savePurchase,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar'),
                ),
            ],
          ),
          body: LoadingOverlay(
            isLoading: provider.isLoading,
            message: 'Salvando...',
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header com data e local
                  _buildHeader(),
                  
                  // Lista de itens
                  Expanded(
                    flex: 2,
                    child: items.isEmpty
                        ? _buildEmptyState()
                        : _buildItemsList(items, total),
                  ),
                  
                  // Formulário de item (rola quando falta espaço, ex.: teclado aberto)
                  Flexible(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: _buildItemForm(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data da compra',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(DateFormatter.formatDate(_selectedDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Local (Mercado/Feira)',
                      prefixIcon: Icon(Icons.store),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o local';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.shopping_cart_outlined,
      title: 'Nenhum item adicionado',
      message: 'Adicione produtos usando o formulário abaixo',
      action: null,
    );
  }

  Widget _buildItemsList(List<PurchaseItem> items, double total) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildItemCard(item, index);
            },
          ),
        ),
        // Total
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${items.length} item${items.length != 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                CurrencyFormatter.format(total),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(PurchaseItem item, int index) {
    final pricePerUnit = item.pricePerUnit;
    final pricePerBaseUnit = item.pricePerBaseUnit;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            item.category.icon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          item.productName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${NumberFormatter.format(item.quantity)} ${item.unit.shortName} × ${CurrencyFormatter.format(pricePerUnit)}/${item.unit.shortName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (item.unit != item.unit.baseUnit)
              Text(
                '≈ ${CurrencyFormatter.format(pricePerBaseUnit)}/${item.unit.baseUnitLabel}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.format(item.pricePaid),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _startEditingItem(index, item);
                    break;
                  case 'delete':
                    _removeItem(index);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Excluir', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemForm() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _editingItem != null ? Icons.edit : Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _editingItem != null ? 'Editar Item' : 'Adicionar Item',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_editingItem != null) ...[
                  const Spacer(),
                  TextButton(
                    onPressed: _cancelEditing,
                    child: const Text('Cancelar'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            
            // Produto com autocomplete
            ProductAutocompleteField(
              controller: _productController,
              focusNode: _productFocusNode,
              onProductSelected: _onProductSelected,
              onChanged: _onProductNameChanged,
              labelText: 'Produto *',
              hintText: 'Digite o nome do produto...',
            ),
            
            const SizedBox(height: 12),
            
            // Categoria
            Text('Categoria', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Category.values.map((category) {
                return CategoryChip(
                  category: category,
                  selected: _selectedCategory == category,
                  onTap: () => setState(() => _selectedCategory = category),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 12),
            
            // Quantidade, Unidade e Preço
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: QuantityInputField(
                    controller: _quantityController,
                    onChanged: (_) => setState(() {}),
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
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: CurrencyInputField(
                    controller: _priceController,
                    labelText: 'Preço pago *',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            
            // Comparação de preço
            if (_selectedProduct != null) ...[
              const SizedBox(height: 12),
              FutureBuilder<PurchaseItem?>(
                future: provider.getLastPriceForProduct(_selectedProduct!.id!),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final lastItem = snapshot.data!;
                    final currentPricePerBase = _priceController.text.isNotEmpty
                        ? (double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0) / 
                          _selectedUnit.toBaseUnit(double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1)
                        : 0.0;
                    
                    if (currentPricePerBase > 0) {
                      return PriceComparisonWidget(
                        currentPricePerBaseUnit: currentPricePerBase,
                        lastPricePerBaseUnit: lastItem.pricePerBaseUnit,
                        baseUnitLabel: _selectedUnit.baseUnitLabel,
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Botão adicionar/atualizar
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addOrUpdateItem,
                icon: Icon(_editingItem != null ? Icons.update : Icons.add),
                label: Text(_editingItem != null ? 'Atualizar Item' : 'Adicionar Item'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}