import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final _searchController = TextEditingController();
  Category? _filterCategory;
  bool _showOnlyEssentials = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        var products = provider.allProducts;

        // Aplicar filtros
        if (_searchController.text.isNotEmpty) {
          products = products
              .where((p) => p.name.toLowerCase().contains(_searchController.text.toLowerCase()))
              .toList();
        }
        if (_filterCategory != null) {
          products = products.where((p) => p.category == _filterCategory).toList();
        }
        if (_showOnlyEssentials) {
          products = products.where((p) => p.isEssential).toList();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Produtos'),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterDialog,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showAddProductDialog(context),
              ),
            ],
          ),
          body: Column(
            children: [
              // Barra de busca
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar produtos',
                    hintText: 'Digite o nome...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              
              // Chips de filtro ativos
              if (_filterCategory != null || _showOnlyEssentials)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_filterCategory != null)
                        InputChip(
                          label: Text(_filterCategory!.label),
                          avatar: Icon(_filterCategory!.icon, size: 18),
                          onDeleted: () {
                            setState(() => _filterCategory = null);
                          },
                        ),
                      if (_showOnlyEssentials)
                        InputChip(
                          label: const Text('Apenas Essenciais'),
                          avatar: const Icon(Icons.star, size: 18, color: Colors.amber),
                          onDeleted: () {
                            setState(() => _showOnlyEssentials = false);
                          },
                        ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // Lista de produtos
              Expanded(
                child: products.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.inventory_2_outlined,
                        title: _searchController.text.isNotEmpty || _filterCategory != null || _showOnlyEssentials
                            ? 'Nenhum produto encontrado'
                            : 'Nenhum produto cadastrado',
                        message: _searchController.text.isNotEmpty || _filterCategory != null || _showOnlyEssentials
                            ? 'Tente alterar os filtros de busca'
                            : 'Adicione seu primeiro produto',
                        action: FilledButton.icon(
                          onPressed: () => _showAddProductDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar Produto'),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _buildProductCard(product, provider);
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddProductDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Product product, AppProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            product.category.icon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (product.isEssential)
              Icon(
                Icons.star,
                color: Colors.amber,
                size: 20,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    product.category.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Criado em ${DateFormatter.formatShortDate(product.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditProductDialog(context, product);
                break;
              case 'toggle_essential':
                provider.toggleEssential(product.id!);
                break;
              case 'delete':
                _confirmDeleteProduct(context, product, provider);
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
            PopupMenuItem(
              value: 'toggle_essential',
              child: Row(
                children: [
                  Icon(
                    product.isEssential ? Icons.star : Icons.star_border,
                    size: 20,
                    color: product.isEssential ? Colors.amber : null,
                  ),
                  const SizedBox(width: 8),
                  Text(product.isEssential ? 'Remover de Essenciais' : 'Marcar como Essencial'),
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
        onTap: () => _showProductDetails(context, product),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtros'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('Apenas Essenciais'),
              trailing: Switch(
                value: _showOnlyEssentials,
                onChanged: (value) {
                  setState(() => _showOnlyEssentials = value);
                  Navigator.pop(context);
                },
              ),
            ),
            const Divider(),
            const Text('Categoria:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Todas'),
                  selected: _filterCategory == null,
                  onSelected: (_) => setState(() => _filterCategory = null),
                ),
                ...Category.values.map((cat) => FilterChip(
                  label: Text(cat.label),
                  avatar: Icon(cat.icon, size: 16),
                  selected: _filterCategory == cat,
                  onSelected: (_) {
                    setState(() => _filterCategory = cat);
                    Navigator.pop(context);
                  },
                )),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filterCategory = null;
                _showOnlyEssentials = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Limpar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    final nameController = TextEditingController();
    Category selectedCategory = Category.pantryBasics;
    bool isEssential = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Novo Produto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome *',
                    hintText: 'Ex: Arroz, Leite Integral, Tomate...',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Text('Categoria', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: Category.values.map((cat) {
                    return CategoryChip(
                      category: cat,
                      selected: selectedCategory == cat,
                      onTap: () => setState(() => selectedCategory = cat),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Essencial (não pode faltar)'),
                  subtitle: const Text('Aparecerá na lista de essenciais faltando'),
                  value: isEssential,
                  onChanged: (value) => setState(() => isEssential = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                
                final provider = context.read<AppProvider>();
                final navigator = Navigator.of(context);
                final product = Product(
                  name: nameController.text.trim(),
                  category: selectedCategory,
                  isEssential: isEssential,
                );
                await provider.addProduct(product);
                navigator.pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, Product product) {
    final nameController = TextEditingController(text: product.name);
    Category selectedCategory = product.category;
    bool isEssential = product.isEssential;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar Produto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Categoria', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: Category.values.map((cat) {
                    return CategoryChip(
                      category: cat,
                      selected: selectedCategory == cat,
                      onTap: () => setState(() => selectedCategory = cat),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Essencial (não pode faltar)'),
                  value: isEssential,
                  onChanged: (value) => setState(() => isEssential = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                
                final provider = context.read<AppProvider>();
                final navigator = Navigator.of(context);
                final updated = product.copyWith(
                  name: nameController.text.trim(),
                  category: selectedCategory,
                  isEssential: isEssential,
                );
                await provider.updateProduct(updated);
                navigator.pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, Product product, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Produto'),
        content: Text('Tem certeza que deseja excluir "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await provider.deleteProduct(product.id!);
              navigator.pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _showProductDetails(BuildContext context, Product product) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Categoria', product.category.label, product.category.icon),
              _buildDetailRow('Essencial', product.isEssential ? 'Sim' : 'Não', product.isEssential ? Icons.star : Icons.star_border),
              _buildDetailRow('Criado em', DateFormatter.formatDateTime(product.createdAt), Icons.calendar_today),
              _buildDetailRow('Atualizado em', DateFormatter.formatDateTime(product.updatedAt), Icons.update),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Histórico de Preços',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: provider.getPriceHistoryForProduct(product.id!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || (snapshot.data!['history'] as List).isEmpty) {
                      return const Center(
                        child: Text('Nenhum histórico de preços'),
                      );
                    }
                    final history = snapshot.data!['history'] as List;
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final h = history[index];
                        return ListTile(
                          dense: true,
                          leading: Text(h['date']),
                          title: Text('${CurrencyFormatter.format(h['avgPricePerBaseUnit'])}/${product.category.label}'),
                          subtitle: Text('Qtd: ${NumberFormatter.format(h['totalQuantity'])} • ${h['count']} compra(s)'),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
}
