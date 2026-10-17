import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import 'new_purchase_screen.dart';
import 'product_management_screen.dart';
import '../main.dart'; // Para acessar _MainNavigationScreenState

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Feira Fácil'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showSettingsDialog(context),
              ),
            ],
          ),
          body: LoadingOverlay(
            isLoading: provider.isLoading,
            child: RefreshIndicator(
              onRefresh: () => provider.initialize(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Orçamento mensal
                    _buildBudgetCard(provider),
                    
                    const SizedBox(height: 16),
                    
                    // Essenciais faltando
                    _buildMissingEssentials(provider),
                    
                    const SizedBox(height: 16),
                    
                    // Últimas compras
                    _buildRecentPurchases(provider),
                    
                    const SizedBox(height: 16),
                    
                    // Ações rápidas
                    _buildQuickActions(context),
                  ],
                ),
              ),
            ),
          ),
          /*floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NewPurchaseScreen()),
            ),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Nova Compra'),
          ),*/
        );
      },
    );
  }

  Widget _buildBudgetCard(AppProvider provider) {
    final budget = provider.currentMonthBudget;
    final spent = provider.currentMonthSpent;
    final progress = provider.budgetProgress;
    final isOver = provider.isOverBudget;

    if (budget == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Orçamento Mensal',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Defina um orçamento para acompanhar seus gastos',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _showBudgetDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Definir Orçamento'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Orçamento ${DateFormatter.formatMonthYear(DateTime.now())}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _showBudgetDialog(context),
                  child: const Text('Alterar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gasto: ${CurrencyFormatter.format(spent)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isOver
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Limite: ${CurrencyFormatter.format(budget.amount)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toStringAsFixed(1)}% utilizado${isOver ? ' • Acima do orçamento!' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isOver
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingEssentials(AppProvider provider) {
    final missing = provider.getMissingEssentialsForCurrentMonth();
    
    if (missing.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.tertiary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Todos os essenciais comprados!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Parabéns! Não falta nada essencial este mês.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Essenciais Faltando (${missing.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _navigateToShoppingList(context),
                  child: const Text('Ver Lista'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: missing.length,
                itemBuilder: (context, index) {
                  final product = missing[index];
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    child: Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: InkWell(
                        onTap: () => _addToShoppingList(product),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                product.category.icon,
                                color: Theme.of(context).colorScheme.error,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                product.name,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Essencial',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPurchases(AppProvider provider) {
    final purchases = provider.purchases.take(5).toList();
    
    if (purchases.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Nenhuma compra registrada',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sua primeira compra aparecerá aqui',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Últimas Compras',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () => _navigateToReports(context),
              child: const Text('Ver Todas'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: purchases.length,
          itemBuilder: (context, index) {
            final purchase = purchases[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.store,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  purchase.location,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${DateFormatter.formatDate(purchase.date)} • ${purchase.items.length} itens',
                ),
                trailing: Text(
                  CurrencyFormatter.format(purchase.totalAmount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                onTap: () => _showPurchaseDetails(context, purchase),
                onLongPress: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Excluir lista de compra?'),
                      content: Text(
                        'Deseja excluir a compra de "${purchase.location}" '
                        'em ${DateFormatter.formatDate(purchase.date)}? '
                        'Essa ação não pode ser desfeita.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Excluir'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed != true || purchase.id == null || !context.mounted) {
                    return;
                  }

                  await context.read<AppProvider>().deletePurchase(purchase.id!);
                  if (!context.mounted) return;
                  final error = context.read<AppProvider>().error;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error == null
                            ? 'Lista de compra excluída.'
                            : 'Não foi possível excluir: $error',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ações Rápidas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildActionCard(
              context,
              'Nova Compra',
              Icons.add_shopping_cart,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewPurchaseScreen()),
              ),
            ),
            _buildActionCard(
              context,
              'Lista de Compras',
              Icons.list_alt,
              Colors.blue,
              () => _navigateToShoppingList(context),
            ),
            _buildActionCard(
              context,
              'Produtos',
              Icons.inventory,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductManagementScreen()),
              ),
            ),
            _buildActionCard(
              context,
              'Relatórios',
              Icons.bar_chart,
              Colors.purple,
              () => _navigateToReports(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBudgetDialog(BuildContext context) {
    final provider = context.read<AppProvider>();
    final controller = TextEditingController(
      text: provider.currentMonthBudget?.amount.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Orçamento Mensal'),
        content: TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor (R\$)',
            prefixText: 'R\$ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll(',', '.'));
              if (value != null && value > 0) {
                provider.setBudget(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurações'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Exportar Dados (JSON)'),
              onTap: () => _exportData(context),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Importar Dados (JSON)'),
              onTap: () => _importData(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AppProvider>();
    navigator.pop();

    try {
      final data = await provider.exportData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      final now = DateTime.now();
      final stamp = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';

      // Na versão 12+ do file_picker o próprio seletor grava o arquivo.
      final path = await FilePicker.saveFile(
        dialogTitle: 'Salvar backup',
        fileName: 'feira_facil_backup_$stamp.json',
        bytes: bytes,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(path == null ? 'Exportação cancelada' : 'Backup salvo com sucesso'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao exportar: $e')),
      );
    }
  }

  Future<void> _importData(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AppProvider>();
    navigator.pop();

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return;

      final Uint8List bytes = await file.readAsBytes();

      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['products'] is! List || decoded['purchases'] is! List) {
        throw const FormatException('Arquivo de backup inválido');
      }
      final data = Map<String, dynamic>.from(decoded);
      data['budgets'] ??= <dynamic>[];

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: this.context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Importar backup'),
          content: const Text(
            'Isso vai substituir TODOS os dados atuais do app pelos dados do arquivo. Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Importar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      await provider.importData(data);
      messenger.showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Dados importados com sucesso'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao importar: $e')),
      );
    }
  }

  void _navigateToShoppingList(BuildContext context) {
      // Navegar para aba Lista (índice 2) via estado pai
      final mainNavState = context.findAncestorStateOfType<MainNavigationScreenState>();
      if (mainNavState != null) {
        mainNavState.onDestinationSelected(2);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use a aba "Lista" na navegação inferior')),
        );
      }
    }

    void _navigateToReports(BuildContext context) {
      final mainNavState = context.findAncestorStateOfType<MainNavigationScreenState>();
      if (mainNavState != null) {
        mainNavState.onDestinationSelected(3);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use a aba "Relatórios" na navegação inferior')),
        );
      }
    }

  void _addToShoppingList(Product product) {
    final added = context.read<AppProvider>().addProductToShoppingList(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? '${product.name} adicionado à lista'
              : '${product.name} já está na lista',
        ),
      ),
    );
  }

  void _showPurchaseDetails(BuildContext context, Purchase purchase) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
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
                    'Detalhes da Compra',
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
              Text('Local: ${purchase.location}'),
              Text('Data: ${DateFormatter.formatDate(purchase.date)}'),
              Text('Total: ${CurrencyFormatter.format(purchase.totalAmount)}'),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Itens (${purchase.items.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: purchase.items.length,
                  itemBuilder: (context, index) {
                    final item = purchase.items[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(item.category.icon, size: 20),
                      title: Text(item.productName),
                      subtitle: Text(
                        '${NumberFormatter.format(item.quantity)} ${item.unit.shortName} × ${CurrencyFormatter.format(item.pricePerUnit)}/${item.unit.shortName}',
                      ),
                      trailing: Text(
                        CurrencyFormatter.format(item.pricePaid),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
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
}