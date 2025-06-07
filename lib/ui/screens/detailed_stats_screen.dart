import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../../core/providers/app_providers.dart';
import '../../models/detailed_stats_models.dart';
import '../widgets/empty_state.dart';

class DetailedStatsScreen extends ConsumerWidget {
  const DetailedStatsScreen({Key? key}) : super(key: key);

  String _formatPeriodKey(
    String key,
    StatsTimePeriod period,
    DateFormat dateFormatter,
    DateFormat monthYearFormatter,
    String Function(String) weekDisplayFormatter,
  ) {
    try {
      switch (period) {
        case StatsTimePeriod.daily:
          return DateFormat(
            'EEEE, dd MMM yy',
            'es_ES',
          ).format(DateFormat('yyyy-MM-dd (EEEE)', 'es_ES').parse(key));
        case StatsTimePeriod.weekly:
          return weekDisplayFormatter(key);
        case StatsTimePeriod.monthly:
          return DateFormat(
            'MMMM yyyy',
            'es_ES',
          ).format(DateFormat('yyyy-MM (MMMM)', 'es_ES').parse(key));
        case StatsTimePeriod.yearly:
          return key;
        case StatsTimePeriod.lifetime:
          return DateFormat(
            'MMMM yyyy',
            'es_ES',
          ).format(DateFormat('yyyy-MM (MMMM)', 'es_ES').parse(key));
      }
    } catch (e) {
      return key;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(detailedStatsProvider);
    final selectedPeriod = ref.watch(detailedStatsTimePeriodFilterProvider);
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_ES',
      symbol: 'Bs.',
    );
    final dateFormatter = DateFormat('dd MMM yyyy', 'es_ES');
    final monthYearFormatter = DateFormat('MMMM yyyy', 'es_ES');
    final weekDisplayFormatter = (String weekKey) {
      try {
        final date = DateFormat('yyyy-MM-dd').parse(weekKey);
        return "Semana del ${DateFormat('dd MMM', 'es_ES').format(date)}";
      } catch (e) {
        return weekKey;
      }
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Detallado'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.show_chart_rounded,
              color: theme.appBarTheme.iconTheme?.color,
            ),
            tooltip: 'Ver Gráficos',
            onPressed: () => Navigator.pushNamed(context, '/charts-stats'),
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(detailedStatsProvider);
              await ref.read(detailedStatsProvider.future);
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: SegmentedButton<StatsTimePeriod>(
                    showSelectedIcon: false, // <-- No checkmark icon
                    style: SegmentedButton.styleFrom(
                      // Make button a bit more compact
                      visualDensity: VisualDensity(horizontal: 0, vertical: -1),
                    ),
                    segments:
                        StatsTimePeriod.values.map((period) {
                          return ButtonSegment<StatsTimePeriod>(
                            value: period,
                            label: Text(
                              getPeriodLabel(period),
                            ), // Uses corrected label logic
                            tooltip: getPeriodLabel(period, forTitle: true),
                          );
                        }).toList(),
                    selected: {selectedPeriod},
                    onSelectionChanged: (newSelection) {
                      ref
                          .read(detailedStatsTimePeriodFilterProvider.notifier)
                          .state = newSelection.first;
                    },
                  ),
                ),
                Expanded(
                  child:
                      (stats.totalProductsBoughtAllTime == 0 &&
                                  selectedPeriod == StatsTimePeriod.lifetime) ||
                              (selectedPeriod != StatsTimePeriod.lifetime &&
                                  stats.totalProductsBoughtInPeriod == 0)
                          ? EmptyState(
                            title:
                                'Sin Datos para ${getPeriodLabel(selectedPeriod)}',
                            message:
                                'No hay productos comprados con costo en el período seleccionado.',
                            icon: Icons.sentiment_very_dissatisfied_rounded,
                          )
                          : ListView(
                            padding: const EdgeInsets.fromLTRB(
                              16.0,
                              0,
                              16.0,
                              16.0,
                            ),
                            children: [
                              if (selectedPeriod !=
                                  StatsTimePeriod.lifetime) ...[
                                _buildStatCard(
                                  theme,
                                  title:
                                      'Gasto Total (${getPeriodLabel(selectedPeriod)})',
                                  content: Text(
                                    currencyFormatter.format(
                                      stats.totalSpendingForPeriod,
                                    ),
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  subtitle:
                                      '${stats.totalProductsBoughtInPeriod} productos comprados en este período.',
                                  icon: Icons.calculate_rounded,
                                ),
                              ] else ...[
                                _buildStatCard(
                                  theme,
                                  title: 'Gasto Total (Vida)',
                                  content: Text(
                                    currencyFormatter.format(
                                      stats.totalLifetimeSpending,
                                    ),
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  subtitle:
                                      '${stats.totalProductsBoughtAllTime} productos comprados en total.',
                                  icon: Icons.account_balance_wallet_rounded,
                                ),
                              ],

                              if (stats.mostExpensiveProductInstance != null)
                                _buildStatCard(
                                  theme,
                                  title:
                                      'Producto Más Costoso (${getPeriodLabel(selectedPeriod)})',
                                  content: Text(
                                    currencyFormatter.format(
                                      stats
                                          .mostExpensiveProductInstance!
                                          .amount,
                                    ),
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: theme.colorScheme.secondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  subtitle:
                                      "${stats.mostExpensiveProductInstance!.details}\nComprado el: ${dateFormatter.format(stats.mostExpensiveProductInstance!.date)}",
                                  icon: Icons.emoji_events_rounded,
                                ),
                              if (stats.mostBoughtProduct != null)
                                _buildStatCard(
                                  theme,
                                  title:
                                      'Producto Más Popular (${getPeriodLabel(selectedPeriod)})',
                                  content: Text(
                                    stats.mostBoughtProduct!.name,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle:
                                      "Comprado ${stats.mostBoughtProduct!.timesBought} veces (${stats.mostBoughtProduct!.totalQuantityBought} unids).\nGasto total en este producto: ${currencyFormatter.format(stats.mostBoughtProduct!.totalSpentOnProduct)}",
                                  icon: Icons.local_fire_department_rounded,
                                ),

                              _buildPeriodicSpendingCard(
                                theme,
                                title: stats.periodTypeLabel,
                                spendingData: stats.spendingByPeriod,
                                formatter: currencyFormatter,
                                keyFormatter:
                                    (key) => _formatPeriodKey(
                                      key,
                                      selectedPeriod,
                                      dateFormatter,
                                      monthYearFormatter,
                                      weekDisplayFormatter,
                                    ),
                                icon: Icons.wallet_travel_rounded,
                              ),
                            ],
                          ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al Cargar Estadísticas',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.refresh_rounded),
                      onPressed: () => ref.invalidate(detailedStatsProvider),
                      label: Text("Reintentar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.errorContainer,
                        foregroundColor: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required String title,
    required Widget content,
    String? subtitle,
    IconData? icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.only(left: icon != null ? 40 : 0),
              child: content,
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.only(left: icon != null ? 40 : 0),
                child: Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodicSpendingCard(
    ThemeData theme, {
    required String title,
    required Map<String, double> spendingData,
    required NumberFormat formatter,
    required String Function(String) keyFormatter,
    IconData? icon,
  }) {
    if (spendingData.isEmpty) {
      return _buildStatCard(
        theme,
        title: title,
        icon: icon,
        content: Text(
          "No hay datos de gasto para este período.",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final sortedKeys =
        spendingData.keys.toList()..sort((a, b) => b.compareTo(a));

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 250),
              child: ListView.separated(
                shrinkWrap: true,
                physics: BouncingScrollPhysics(),
                itemCount: sortedKeys.length,
                itemBuilder: (context, index) {
                  final key = sortedKeys[index];
                  final amount = spendingData[key]!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            keyFormatter(key),
                            style: theme.textTheme.bodyLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          formatter.format(amount),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder:
                    (_, __) => const Divider(height: 1, thickness: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
