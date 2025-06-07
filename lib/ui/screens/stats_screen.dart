import 'package:compras/models/shoppings_stats.dart';
import 'package:compras/ui/widgets/category_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(shoppingStatsProvider);
    final detailedStatsAsync = ref.watch(detailedStatsProvider);
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_ES',
      symbol: 'Bs.',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas Generales'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.insights_rounded,
              color: theme.appBarTheme.iconTheme?.color,
            ),
            tooltip: "Estadísticas Detalladas (Reporte)",
            onPressed: () => Navigator.pushNamed(context, '/detailed-stats'),
          ),
          IconButton(
            icon: Icon(
              Icons.show_chart_rounded,
              color: theme.appBarTheme.iconTheme?.color,
            ),
            tooltip: "Gráficos de Estadísticas",
            onPressed: () => Navigator.pushNamed(context, '/charts-stats'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(shoppingStatsProvider);
          ref.invalidate(detailedStatsProvider);
          await ref.read(detailedStatsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard(context, stats, theme),
            const SizedBox(height: 16),
            _buildProgressCard(context, stats, theme),
            const SizedBox(height: 16),
            detailedStatsAsync.when(
              data: (details) {
                if (details.totalProductsBoughtAllTime == 0 &&
                    details.totalLifetimeSpending == 0) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Aún no hay gastos registrados.",
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  );
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Gasto Total (Vida)",
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormatter.format(
                            details.totalLifetimeSpending,
                          ),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${details.totalProductsBoughtAllTime} productos comprados en total.",
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading:
                  () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              error:
                  (err, st) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error al cargar gasto total: ${err.toString()}',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
            ),
            const SizedBox(height: 16),
            _buildCategoryCard(context, stats, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    ShoppingStats stats,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen General',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _StatItem(
                    title: 'Total',
                    value: stats.totalItems.toString(),
                    icon: Icons.list_alt_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    title: 'Pendientes',
                    value: stats.pendingItems.toString(),
                    icon: Icons.pending_actions_rounded,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    title: 'Completados',
                    value: stats.completedItems.toString(),
                    icon: Icons.check_circle_outline_rounded,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    ShoppingStats stats,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progreso de Compras',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (stats.totalItems > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: stats.completionRate / 100,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      color: theme.colorScheme.primary,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${stats.completionRate.toStringAsFixed(1)}%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Has completado ${stats.completedItems} de ${stats.totalItems} productos.',
                style: theme.textTheme.bodyMedium,
              ),
            ] else
              Text(
                'Agrega productos a tu lista para ver tu progreso.',
                style: theme.textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    ShoppingStats stats,
    ThemeData theme,
  ) {
    if (stats.categoryStats.isEmpty && stats.totalItems == 0) {
      return SizedBox.shrink();
    }
    if (stats.categoryStats.isEmpty && stats.totalItems > 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No hay categorías para mostrar.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final sortedCategories =
        stats.categoryStats.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Productos por Categoría',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...sortedCategories.map((entry) {
              final category = entry.key;
              final count = entry.value;
              final percentage =
                  stats.totalItems > 0 ? (count / stats.totalItems) * 100 : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      CategoryUtils.getCategoryIcon(category),
                      color: CategoryUtils.getCategoryColor(category),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                category,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '$count ${count == 1 ? "producto" : "productos"}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (stats.totalItems > 0)
                            LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              color: CategoryUtils.getCategoryColor(category),
                              minHeight: 5,
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
