import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/category.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Relatórios'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Mês Atual'),
                Tab(text: 'Comparação Mensal'),
                Tab(text: 'Top Produtos'),
              ],
              isScrollable: true,
            ),
            actions: [
              PopupMenuButton<int>(
                onSelected: (year) {
                  setState(() => _selectedYear = year);
                },
                itemBuilder: (context) => List.generate(5, (index) {
                  final year = DateTime.now().year - index;
                  return PopupMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    children: [
                      Text(_selectedYear.toString()),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildCurrentMonthTab(provider),
              _buildMonthlyComparisonTab(provider),
              _buildTopProductsTab(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentMonthTab(AppProvider provider) {
    return FutureBuilder<Map<Category, double>>(
      future: provider.getCategoryTotalsForMonth(_selectedYear, _selectedMonth),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final categoryTotals = snapshot.data ?? {};
        final total = categoryTotals.values.fold(0.0, (a, b) => a + b);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Seletor de mês
              _buildMonthSelector(),
              const SizedBox(height: 16),
              
              // Total do mês
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Total Gasto em ${_getMonthName(_selectedMonth)}/$_selectedYear',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        CurrencyFormatter.format(total),
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Gráfico de pizza por categoria
              if (categoryTotals.isNotEmpty) ...[
                Text(
                  'Por Categoria',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 300,
                      child: _buildPieChart(categoryTotals, total),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Lista de categorias ordenadas por porcentagem (maior para menor)
                                ...(() {
                                  final sortedCategories = categoryTotals.entries.toList()
                                    ..sort((a, b) {
                                      final percentA = total > 0 ? (a.value / total) * 100 : 0;
                                      final percentB = total > 0 ? (b.value / total) * 100 : 0;
                                      return percentB.compareTo(percentA);
                                    });
                  
                                  return sortedCategories.map((entry) {
                                    final percent = total > 0 ? (entry.value / total) * 100 : 0;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                          child: Icon(
                                            entry.key.icon,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                        title: Text(entry.key.label),
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              CurrencyFormatter.format(entry.value),
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            Text(
                                              '${percent.toStringAsFixed(1)}%',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList();
                                }()),
              ] else ...[
                EmptyStateWidget(
                  icon: Icons.receipt_long_outlined,
                  title: 'Nenhum dado',
                  message: 'Não há compras registradas para este mês',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthlyComparisonTab(AppProvider provider) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: provider.getMonthlyTotals(limit: 12),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final monthlyData = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comparação dos Últimos 12 Meses',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              if (monthlyData.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 300,
                      child: _buildMonthlyBarChart(monthlyData),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Tabela de meses
                Card(
                  child: Column(
                    children: monthlyData.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      final monthStr = data['month'] as String;
                      final total = (data['total'] as num).toDouble();
                      final parts = monthStr.split('-');
                      final year = int.parse(parts[0]);
                      final month = int.parse(parts[1]);
                      
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: index == 0
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: index == 0
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        title: Text('${_getMonthName(month)}/$year'),
                        trailing: Text(
                          CurrencyFormatter.format(total),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ] else ...[
                EmptyStateWidget(
                  icon: Icons.bar_chart_outlined,
                  title: 'Nenhum dado',
                  message: 'Registre compras para ver a comparação mensal',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopProductsTab(AppProvider provider) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: provider.getTopProductsForMonth(_selectedYear, _selectedMonth, limit: 10),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final topProducts = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthSelector(),
              const SizedBox(height: 16),
              
              Text(
                'Top 10 Produtos Mais Comprados',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ordenado por frequência de compra',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              
              if (topProducts.isNotEmpty) ...[
                Card(
                  child: Column(
                    children: topProducts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final product = entry.value;
                      final name = product['productName'] as String;
                      final categoryStr = product['category'] as String;
                      final category = Category.fromString(categoryStr);
                      final totalQty = (product['totalQuantity'] as num).toDouble();
                      final unit = product['unit'] as String;
                      final purchaseCount = product['purchaseCount'] as int;
                      final totalSpent = (product['totalSpent'] as num).toDouble();
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: index < 3
                              ? [Colors.amber, Colors.grey.shade400, Colors.brown.shade300][index].withValues(alpha: 0.3)
                              : Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: index < 3
                                  ? [Colors.amber, Colors.grey.shade400, Colors.brown.shade300][index]
                                  : Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Wrap  (
                              children: [
                                Icon(category.icon, size: 14),
                                const SizedBox(width: 4),
                                Text(category.label),
                                const SizedBox(width: 12),
                                Text('$purchaseCount compra${purchaseCount != 1 ? 's' : ''}'),
                              ],
                            ),
                            Text(
                              'Total: ${NumberFormatter.format(totalQty)} $unit • ${CurrencyFormatter.format(totalSpent)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: Text(
                          CurrencyFormatter.format(totalSpent / purchaseCount),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ] else ...[
                EmptyStateWidget(
                  icon: Icons.inventory_outlined,
                  title: 'Nenhum produto',
                  message: 'Não há produtos comprados neste mês',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('month-$_selectedMonth'),
                initialValue: _selectedMonth,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Mês',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: List.generate(12, (i) => i + 1).map((month) {
                  return DropdownMenuItem(
                    value: month,
                    child: Text(_getMonthName(month)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedMonth = value);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('year-$_selectedYear'),
                initialValue: _selectedYear,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Ano',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: List.generate(5, (i) => DateTime.now().year - i).map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedYear = value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<Category, double> data, double total) {
    final colors = [
      Colors.green,
      Colors.orange,
      Colors.blue,
      Colors.red,
      Colors.purple,
      Colors.teal,
    ];

    final sections = data.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value.key;
      final value = entry.value.value;
      final percent = total > 0 ? (value / total) * 100 : 0;
      
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: value,
        title: '${percent.toStringAsFixed(1)}%',
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: _buildBadge(category.label, colors[index % colors.length]),
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        startDegreeOffset: -90,
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMonthlyBarChart(List<Map<String, dynamic>> data) {
    final reversedData = data.reversed.toList();
    final maxValue = reversedData.map((d) => (d['total'] as num).toDouble()).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final monthData = reversedData[group.x.toInt()];
              final monthStr = monthData['month'] as String;
              final parts = monthStr.split('-');
              final month = int.parse(parts[1]);
              final year = int.parse(parts[0]);
              return BarTooltipItem(
                '${_getMonthName(month)}/$year\n${CurrencyFormatter.format(rod.toY)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < reversedData.length) {
                  final monthData = reversedData[value.toInt()];
                  final monthStr = monthData['month'] as String;
                  final parts = monthStr.split('-');
                  final month = int.parse(parts[1]);
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      _getShortMonthName(month),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    CurrencyFormatter.formatCompact(value),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
              reservedSize: 50,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade300,
            strokeWidth: 0.5,
          ),
        ),
        barGroups: reversedData.asMap().entries.map((entry) {
          final index = entry.key;
          final monthData = entry.value;
          final total = (monthData['total'] as num).toDouble();
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: total,
                color: Theme.of(context).colorScheme.primary,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return months[month - 1];
  }

  String _getShortMonthName(int month) {
    const months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return months[month - 1];
  }
}