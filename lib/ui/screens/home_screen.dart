import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/providers/app_providers.dart';
import '../../models/product_filter.dart';
import '../widgets/product_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/search_bar.dart' as custom_search_bar;
import '../widgets/category_filter.dart';

class HomeScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription? _accelerometerSubscription;
  DateTime? _lastShakeTime;

  @override
  void initState() {
    super.initState();
    _initShakeDetection();
  }

  void _initShakeDetection() {
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(
      (AccelerometerEvent event) {
        const double shakeThreshold = 15.0;
        if (event.x.abs() > shakeThreshold ||
            event.y.abs() > shakeThreshold ||
            event.z.abs() > shakeThreshold) {
          final now = DateTime.now();
          if (_lastShakeTime == null ||
              now.difference(_lastShakeTime!).inSeconds > 2) {
            _lastShakeTime = now;
            if (mounted) {
              _showClearCompletedDialog(context, ref, fromShake: true);
            }
          }
        }
      },
      onError: (error) {
        print('Error listening to accelerometer: $error');
      },
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productProvider);
    final filteredProducts = ref.watch(filteredProductsProvider);
    final stats = ref.watch(shoppingStatsProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Compras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart_rounded),
            tooltip: 'Gráficos de Estadísticas',
            onPressed: () => Navigator.pushNamed(context, '/charts-stats'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Reporte Detallado',
            onPressed: () => Navigator.pushNamed(context, '/detailed-stats'),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list_rounded),
            tooltip: 'Filtrar y Opciones',
            onSelected: (value) {
              switch (value) {
                case 'clear_completed':
                  _showClearCompletedDialog(context, ref);
                  break;
                case 'show_all':
                  ref.read(statusFilterProvider.notifier).state =
                      ProductFilter.all;
                  break;
                case 'show_pending':
                  ref.read(statusFilterProvider.notifier).state =
                      ProductFilter.pending;
                  break;
                case 'show_completed':
                  ref.read(statusFilterProvider.notifier).state =
                      ProductFilter.completed;
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'clear_completed',
                    child: ListTile(
                      leading: Icon(Icons.cleaning_services_outlined),
                      title: Text('Limpiar completados'),
                    ),
                  ),
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem(
                    value: 'show_all',
                    checked: statusFilter == ProductFilter.all,
                    child: const Text('Mostrar todos'),
                  ),
                  CheckedPopupMenuItem(
                    value: 'show_pending',
                    checked: statusFilter == ProductFilter.pending,
                    child: const Text('Solo pendientes'),
                  ),
                  CheckedPopupMenuItem(
                    value: 'show_completed',
                    checked: statusFilter == ProductFilter.completed,
                    child: const Text('Solo completados'),
                  ),
                ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(productProvider);
          await ref.read(productProvider.future);
        },
        color: theme.colorScheme.primary,
        child: productsAsync.when(
          data:
              (allProducts) => Column(
                children: [
                  if (allProducts.isNotEmpty) ...[
                    const custom_search_bar.SearchBar(),
                    const CategoryFilter(),
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      thickness: 0.5,
                    ),
                  ],
                  if (stats.totalItems > 0 && allProducts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: stats.completionRate / 100,
                              backgroundColor: theme.colorScheme.surfaceVariant
                                  .withOpacity(0.7),
                              color: theme.colorScheme.primary,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${stats.completedItems}/${stats.totalItems} (${stats.completionRate.toStringAsFixed(0)}%)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child:
                        filteredProducts.isEmpty
                            ? LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  physics: AlwaysScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight:
                                          constraints.maxHeight -
                                          (allProducts.isNotEmpty ? 120 : 0),
                                    ),
                                    child: EmptyState(
                                      title:
                                          allProducts.isEmpty
                                              ? 'Tu lista está vacía'
                                              : 'Sin Resultados',
                                      message:
                                          allProducts.isEmpty
                                              ? 'Pulsa el botón "+" para agregar tu primer producto.'
                                              : 'No se encontraron productos con los filtros aplicados. Intenta cambiarlos o limpiar la búsqueda.',
                                      icon:
                                          allProducts.isEmpty
                                              ? Icons.add_shopping_cart_rounded
                                              : Icons.search_off_rounded,
                                      onAction:
                                          allProducts.isEmpty
                                              ? () => Navigator.pushNamed(
                                                context,
                                                '/add',
                                              )
                                              : () {
                                                ref
                                                    .read(
                                                      searchQueryProvider
                                                          .notifier,
                                                    )
                                                    .state = '';
                                                ref
                                                    .read(
                                                      categoryFilterProvider
                                                          .notifier,
                                                    )
                                                    .state = null;
                                                ref
                                                    .read(
                                                      statusFilterProvider
                                                          .notifier,
                                                    )
                                                    .state = ProductFilter.all;
                                              },
                                      actionText:
                                          allProducts.isEmpty
                                              ? 'Agregar Producto'
                                              : 'Limpiar Filtros',
                                    ),
                                  ),
                                );
                              },
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                return ProductCard(
                                  product: product,
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/add',
                                      arguments: product,
                                    );
                                  },
                                );
                              },
                            ),
                  ),
                ],
              ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 64,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al Cargar Productos',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: Icon(Icons.refresh_rounded),
                        onPressed: () => ref.invalidate(productProvider),
                        label: const Text('Reintentar'),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Producto'),
        tooltip: 'Agregar nuevo producto',
      ),
    );
  }

  void _showClearCompletedDialog(
    BuildContext context,
    WidgetRef ref, {
    bool fromShake = false,
  }) {
    final stats = ref.read(shoppingStatsProvider);
    if (stats.completedItems == 0) {
      if (fromShake && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay productos completados para limpiar.'),
          ),
        );
      } else if (!fromShake &&
          mounted &&
          ModalRoute.of(context)?.isCurrent == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay productos completados para limpiar.'),
          ),
        );
      }
      return;
    }
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              fromShake
                  ? 'Limpiar Completados (Agitado)'
                  : 'Limpiar Completados',
            ),
            content: Text(
              '¿Estás seguro de que quieres eliminar ${stats.completedItems} productos completados? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  ref.read(productProvider.notifier).clearCompleted();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${stats.completedItems} productos completados eliminados.',
                        ),
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Limpiar'),
              ),
            ],
          ),
    );
  }
}
