import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/unit.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';

class ProductAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final Function(Product?)? onProductSelected;
  final Function(String)? onChanged;
  final String labelText;
  final String? hintText;
  final Category? initialCategory;
  final bool enabled;

  const ProductAutocompleteField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onProductSelected,
    this.onChanged,
    this.labelText = 'Produto',
    this.hintText,
    this.initialCategory,
    this.enabled = true,
  });

  @override
  State<ProductAutocompleteField> createState() => _ProductAutocompleteFieldState();
}

class _ProductAutocompleteFieldState extends State<ProductAutocompleteField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<Product> _suggestions = [];
  bool _showSuggestions = false;
  Product? _selectedProduct;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _showSuggestions = false;
  }

  void _showOverlay(BuildContext context) {
    if (_overlayEntry != null) return;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildOverlay(context),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
    _showSuggestions = true;
  }

  Widget _buildOverlay(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    
    return Positioned(
      left: offset.dx,
      top: offset.dy + size.height + 4,
      width: size.width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: Offset(0, size.height + 4),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: _suggestions.isEmpty
                ? _buildEmptyState(provider)
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final product = _suggestions[index];
                      return _buildSuggestionTile(product);
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nenhum produto encontrado',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              _removeOverlay();
              _navigateToAddProduct();
            },
            icon: const Icon(Icons.add),
            label: const Text('Cadastrar novo produto'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(Product product) {
    return ListTile(
      dense: true,
      leading: Icon(
        product.category.icon,
        color: Theme.of(context).colorScheme.primary,
        size: 20,
      ),
      title: Text(
        product.name,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: Text(
        product.category.label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: product.isEssential
          ? Icon(
              Icons.star,
              color: Colors.amber,
              size: 18,
            )
          : null,
      onTap: () => _selectProduct(product),
    );
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    final results = await provider.searchProducts(query);
    
    if (mounted) {
      setState(() {
        _suggestions = results;
      });
      
      if (_suggestions.isNotEmpty && !_showSuggestions) {
        _showOverlay(context);
      } else if (_suggestions.isEmpty && _showSuggestions) {
        _showOverlay(context);
      }
    }
  }

  void _selectProduct(Product product) {
    _selectedProduct = product;
    widget.controller.text = product.name;
    _removeOverlay();
    widget.onProductSelected?.call(product);
    widget.focusNode?.unfocus();
  }

  void _navigateToAddProduct() {
    final name = widget.controller.text.trim();
    if (name.isEmpty) return;

    // Cadastra o produto digitado e já o seleciona (categoria padrão: Despensa / Básico)
    final provider = Provider.of<AppProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    provider
        .addProduct(Product(name: name, category: Category.pantryBasics))
        .then((_) async {
      final created = await provider.getProductByName(name);
      if (!mounted) return;
      if (created != null) {
        _selectProduct(created);
        messenger.showSnackBar(
          SnackBar(content: Text('Produto "$name" cadastrado. Ajuste a categoria na aba Produtos, se quiser.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText ?? 'Digite o nome do produto...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _selectedProduct != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    widget.controller.clear();
                    _selectedProduct = null;
                    widget.onProductSelected?.call(null);
                    setState(() {});
                  },
                )
              : null,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          _selectedProduct = null;
          widget.onChanged?.call(value);
          _searchProducts(value);
        },
        onTap: () {
          if (widget.controller.text.isNotEmpty) {
            _searchProducts(widget.controller.text);
          }
        },
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Informe o nome do produto';
          }
          return null;
        },
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  final Category category;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(
        category.icon,
        size: 18,
        color: selected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.primary,
      ),
      label: Text(category.label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: selected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
      ),
      showCheckmark: false,
    );
  }
}

class UnitSelector extends StatelessWidget {
  final Unit selectedUnit;
  final ValueChanged<Unit> onChanged;

  const UnitSelector({
    super.key,
    required this.selectedUnit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Unit>(
      key: ValueKey(selectedUnit),
      initialValue: selectedUnit,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Unidade',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      // No campo fechado mostra só a abreviatura (un, kg, g, L, ml) para caber na linha
      selectedItemBuilder: (context) => Unit.values.map((unit) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(unit.shortName, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      items: Unit.values.map((unit) {
        return DropdownMenuItem(
          value: unit,
          child: Text(unit.fullName),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class PriceComparisonWidget extends StatelessWidget {
  final double currentPricePerBaseUnit;
  final double? lastPricePerBaseUnit;
  final String baseUnitLabel;

  const PriceComparisonWidget({
    super.key,
    required this.currentPricePerBaseUnit,
    this.lastPricePerBaseUnit,
    required this.baseUnitLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (lastPricePerBaseUnit == null || lastPricePerBaseUnit! <= 0) {
      return const SizedBox.shrink();
    }

    final difference = currentPricePerBaseUnit - lastPricePerBaseUnit!;
    final percentChange = (difference / lastPricePerBaseUnit!) * 100;
    final isIncrease = difference > 0;
    final isDecrease = difference < 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isIncrease
            ? Theme.of(context).colorScheme.errorContainer
            : isDecrease
                ? Theme.of(context).colorScheme.tertiaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isIncrease
                ? Icons.trending_up
                : isDecrease
                    ? Icons.trending_down
                    : Icons.remove,
            color: isIncrease
                ? Theme.of(context).colorScheme.error
                : isDecrease
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Último preço: ${CurrencyFormatter.format(lastPricePerBaseUnit!)}/$baseUnitLabel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${isIncrease ? 'Subiu' : isDecrease ? 'Caiu' : 'Igual'} ${NumberFormatter.formatPercent(percentChange.abs() / 100)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isIncrease
                        ? Theme.of(context).colorScheme.error
                        : isDecrease
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );

    // Em áreas pequenas (ex.: tela de Nova compra) o conteúdo rola em vez de estourar.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return Center(child: content);
        }
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (message != null) ...[
                        const SizedBox(height: 16),
                        Text(message!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class CurrencyInputField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;

  const CurrencyInputField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText ?? '0,00',
        prefixText: 'R\$ ',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Informe o valor';
            }
            final parsed = double.tryParse(value.replaceAll(',', '.'));
            if (parsed == null || parsed < 0) {
              return 'Valor inválido';
            }
            return null;
          },
    );
  }
}

class QuantityInputField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;

  const QuantityInputField({
    super.key,
    required this.controller,
    this.labelText = 'Quantidade',
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: '0',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Informe a quantidade';
            }
            final parsed = double.tryParse(value.replaceAll(',', '.'));
            if (parsed == null || parsed <= 0) {
              return 'Quantidade inválida';
            }
            return null;
          },
    );
  }
}