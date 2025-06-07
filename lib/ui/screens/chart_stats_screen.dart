import 'package:compras/ui/widgets/category_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import '../../core/providers/app_providers.dart';
import '../../models/detailed_stats_models.dart';
import '../widgets/empty_state.dart';

class ChartsStatsScreen extends ConsumerWidget {
  const ChartsStatsScreen({Key? key}) : super(key: key);

  List<PieChartSectionData> _generatePieSections(
    Map<String, num> dataMap,
    BuildContext context, {
    bool useCategoryColor = false,
  }) {
    final theme = Theme.of(context);
    final List<Color> defaultColors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.teal.shade400,
      Colors.red.shade300,
    ];

    double totalValue = dataMap.values.fold(0, (sum, item) => sum + item);
    if (totalValue == 0) return [];

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;

    dataMap.forEach((key, value) {
      final percentage = (value / totalValue) * 100;
      sections.add(
        PieChartSectionData(
          color:
              useCategoryColor
                  ? CategoryUtils.getCategoryColor(key)
                  : defaultColors[colorIndex % defaultColors.length],
          value: value.toDouble(),
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 80,
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 2),
            ],
          ),
          badgeWidget: _Badge(
            key,
            borderColor:
                useCategoryColor
                    ? CategoryUtils.getCategoryColor(key)
                    : defaultColors[colorIndex % defaultColors.length],
          ),
          badgePositionPercentageOffset: .98,
        ),
      );
      colorIndex++;
    });
    return sections;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartDataAsync = ref.watch(productChartDataProvider);
    final selectedPeriod = ref.watch(chartTimePeriodProvider);
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_ES',
      symbol: 'Bs.',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Gráficos de Estadísticas')),
      body: chartDataAsync.when(
        data: (data) {
          final bool noDataForPeriod =
              data.spendingByCategory.isEmpty &&
              data.productPurchaseFrequency.isEmpty;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(productChartDataProvider);
              await ref.read(productChartDataProvider.future);
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: SegmentedButton<StatsTimePeriod>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity(horizontal: 0, vertical: -1),
                    ),
                    segments:
                        StatsTimePeriod.values.map((period) {
                          return ButtonSegment<StatsTimePeriod>(
                            value: period,
                            label: Text(getPeriodLabel(period)),
                            tooltip: getPeriodLabel(period, forTitle: true),
                          );
                        }).toList(),
                    selected: {selectedPeriod},
                    onSelectionChanged: (newSelection) {
                      ref.read(chartTimePeriodProvider.notifier).state =
                          newSelection.first;
                    },
                  ),
                ),
                Expanded(
                  child:
                      noDataForPeriod
                          ? EmptyState(
                            title: 'Sin Datos para Gráficos',
                            message:
                                'No hay compras registradas con costo en el período de "${getPeriodLabel(selectedPeriod)}".',
                            icon: Icons.analytics_outlined,
                          )
                          : ListView(
                            padding: const EdgeInsets.all(16.0),
                            children: [
                              if (data.spendingOverTimeSpots.isNotEmpty)
                                _buildChartCard(
                                  theme,
                                  title: data.timePeriodTitle,
                                  icon: Icons.timeline_rounded,
                                  chartHeight: 250,
                                  chart: LineChart(
                                    LineChartData(
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: true,
                                        horizontalInterval:
                                            data.spendingOverTimeSpots
                                                .map((s) => s.y)
                                                .reduce(max) /
                                            4,
                                        verticalInterval: 1,
                                        getDrawingHorizontalLine:
                                            (value) => FlLine(
                                              color: theme.dividerColor
                                                  .withOpacity(0.5),
                                              strokeWidth: 0.5,
                                            ),
                                        getDrawingVerticalLine:
                                            (value) => FlLine(
                                              color: theme.dividerColor
                                                  .withOpacity(0.5),
                                              strokeWidth: 0.5,
                                            ),
                                      ),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 30,
                                            interval: 1,
                                            getTitlesWidget: (value, meta) {
                                              final index = value.toInt();
                                              if (index >= 0 &&
                                                  index <
                                                      data
                                                          .spendingOverTimeLabels
                                                          .length) {
                                                return SideTitleWidget(
                                                  axisSide: meta.axisSide,
                                                  space: 8,
                                                  child: Text(
                                                    data.spendingOverTimeLabels[index],
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return Text('');
                                            },
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 50,
                                            getTitlesWidget:
                                                (value, meta) => Text(
                                                  NumberFormat.compactCurrency(
                                                    symbol: '',
                                                    locale: 'es_ES',
                                                  ).format(value),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(
                                        show: true,
                                        border: Border.all(
                                          color: theme.dividerColor,
                                        ),
                                      ),
                                      minX: 0,
                                      maxX:
                                          (data.spendingOverTimeSpots.length -
                                                  1)
                                              .toDouble(),
                                      minY: 0,
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: data.spendingOverTimeSpots,
                                          isCurved: true,
                                          gradient: LinearGradient(
                                            colors: [
                                              theme.colorScheme.primary,
                                              theme.colorScheme.secondary,
                                            ],
                                          ),
                                          barWidth: 3,
                                          isStrokeCapRound: true,
                                          dotData: const FlDotData(show: false),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            gradient: LinearGradient(
                                              colors: [
                                                theme.colorScheme.primary
                                                    .withOpacity(0.3),
                                                theme.colorScheme.secondary
                                                    .withOpacity(0.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              if (data.spendingByCategory.isNotEmpty)
                                _buildChartCard(
                                  theme,
                                  title:
                                      'Gasto por Categoría (${getPeriodLabel(selectedPeriod)})',
                                  icon: Icons.pie_chart_outline_rounded,
                                  chartHeight: 280,
                                  chart: PieChart(
                                    PieChartData(
                                      sections: _generatePieSections(
                                        data.spendingByCategory,
                                        context,
                                        useCategoryColor: true,
                                      ),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 60,
                                      pieTouchData: PieTouchData(
                                        touchCallback:
                                            (
                                              FlTouchEvent event,
                                              pieTouchResponse,
                                            ) {},
                                      ),
                                    ),
                                  ),
                                ),

                              if (data.productPurchaseFrequency.isNotEmpty)
                                _buildChartCard(
                                  theme,
                                  title:
                                      'Frecuencia de Compra (${getPeriodLabel(selectedPeriod)})',
                                  icon: Icons.donut_small_rounded,
                                  chartHeight: 280,
                                  chart: PieChart(
                                    PieChartData(
                                      sections: _generatePieSections(
                                        data.productPurchaseFrequency,
                                        context,
                                      ),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 60,
                                      pieTouchData: PieTouchData(
                                        touchCallback:
                                            (
                                              FlTouchEvent event,
                                              pieTouchResponse,
                                            ) {},
                                      ),
                                    ),
                                  ),
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
                      'Error al Cargar Gráficos',
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
                      onPressed: () => ref.invalidate(productChartDataProvider),
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

  Widget _buildChartCard(
    ThemeData theme, {
    required String title,
    required Widget chart,
    IconData? icon,
    double chartHeight = 200,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 10),
                ],
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: chartHeight, child: chart),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color borderColor;

  const _Badge(this.text, {required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 3,
            offset: Offset(1, 1),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
