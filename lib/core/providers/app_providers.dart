import 'package:compras/models/shoppings_stats.dart';
import 'package:compras/respositories/product_respository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/product.dart';
import '../../models/product_filter.dart';
import '../../models/detailed_stats_models.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return HiveProductRepository();
});

final productProvider = AsyncNotifierProvider<ProductNotifier, List<Product>>(
  () {
    return ProductNotifier();
  },
);

final purchaseHistoryProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getPurchaseHistory();
});

final allBoughtProductsProvider = FutureProvider<List<Product>>((ref) async {
  final activeProducts = await ref.watch(productProvider.future);
  final archivedProducts = await ref.watch(purchaseHistoryProvider.future);

  final activeBoughtProducts = activeProducts.where((p) => p.isBought).toList();

  final allProductsMap = <String, Product>{};
  for (var p in activeBoughtProducts) {
    allProductsMap['${p.id}_${p.boughtAt?.millisecondsSinceEpoch}'] = p;
  }
  for (var p in archivedProducts) {
    allProductsMap['${p.id}_${p.boughtAt?.millisecondsSinceEpoch}'] = p;
  }

  return allProductsMap.values.toList();
});

final categoriesProvider = Provider<List<String>>(
  (ref) => [
    'General',
    'Frutas y Verduras',
    'Lácteos',
    'Carnes',
    'Limpieza',
    'Bebidas',
    'Panadería',
    'Congelados',
    'Otros',
  ],
);

final searchQueryProvider = StateProvider<String>((ref) => '');
final categoryFilterProvider = StateProvider<String?>((ref) => null);
final statusFilterProvider = StateProvider<ProductFilter>(
  (ref) => ProductFilter.all,
);

final filteredProductsProvider = Provider<List<Product>>((ref) {
  final productsAsync = ref.watch(productProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();
  final categoryFilter = ref.watch(categoryFilterProvider);
  final statusFilter = ref.watch(statusFilterProvider);

  return productsAsync.when(
    data: (products) {
      var filtered = products;
      if (searchQuery.isNotEmpty) {
        filtered =
            filtered
                .where(
                  (p) =>
                      p.name.toLowerCase().contains(searchQuery) ||
                      p.category.toLowerCase().contains(searchQuery),
                )
                .toList();
      }
      if (categoryFilter != null) {
        filtered = filtered.where((p) => p.category == categoryFilter).toList();
      }
      switch (statusFilter) {
        case ProductFilter.pending:
          filtered = filtered.where((p) => !p.isBought).toList();
          break;
        case ProductFilter.completed:
          filtered = filtered.where((p) => p.isBought).toList();
          break;
        case ProductFilter.all:
          break;
      }
      filtered.sort((a, b) {
        if (a.isBought && !b.isBought) return 1;
        if (!a.isBought && b.isBought) return -1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return filtered;
    },
    loading: () => <Product>[],
    error: (_, __) => <Product>[],
  );
});

final shoppingStatsProvider = Provider<ShoppingStats>((ref) {
  final productsAsync = ref.watch(productProvider);
  return productsAsync.when(
    data: (products) => ShoppingStats.fromProducts(products),
    loading: () => ShoppingStats.fromProducts([]),
    error: (_, __) => ShoppingStats.fromProducts([]),
  );
});

class ProductNotifier extends AsyncNotifier<List<Product>> {
  ProductRepository get _repository => ref.read(productRepositoryProvider);

  @override
  Future<List<Product>> build() async {
    final products = await _repository.getProducts();
    products.sort((a, b) {
      if (a.isBought && !b.isBought) return 1;
      if (!a.isBought && b.isBought) return -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return products;
  }

  Future<void> _reloadData() async {
    ref.invalidate(purchaseHistoryProvider);
    state = const AsyncValue.loading();
    final products = await _repository.getProducts();
    products.sort((a, b) {
      if (a.isBought && !b.isBought) return 1;
      if (!a.isBought && b.isBought) return -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    state = AsyncValue.data(products);
  }

  Future<void> addProduct(Product product) async {
    await _repository.addProduct(product);
    await _reloadData();
  }

  Future<double?> _showEnterCostDialog(
    BuildContext context,
    Product product,
  ) async {
    final costController = TextEditingController(
      text: product.cost?.toStringAsFixed(2) ?? '',
    );
    final formKey = GlobalKey<FormState>();

    return await showDialog<double?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Ingresar Costo para ${product.name}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: costController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Costo Total',
                prefixText: 'Bs. ',
                hintText: 'Ej: 15.50',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa un costo.';
                }
                final cost = double.tryParse(value.replaceAll(',', '.'));
                if (cost == null) {
                  return 'Ingresa un número válido.';
                }
                if (cost < 0) {
                  return 'El costo no puede ser negativo.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(
                    dialogContext,
                    double.parse(costController.text.replaceAll(',', '.')),
                  );
                }
              },
              child: Text('Guardar Costo'),
            ),
          ],
        );
      },
    );
  }

  Future<void> toggleBought(String id, BuildContext context) async {
    final previousState = state;
    try {
      final currentProducts = List<Product>.from(state.value ?? []);
      final productIndex = currentProducts.indexWhere((p) => p.id == id);

      if (productIndex != -1) {
        Product product = currentProducts[productIndex];
        bool newBoughtState = !product.isBought;
        double? finalCost = product.cost;

        if (newBoughtState == true) {
          final enteredCost = await _showEnterCostDialog(context, product);
          if (enteredCost == null && product.cost == null) {
            return;
          }
          finalCost = enteredCost ?? product.cost;
        }

        final updatedProduct = product.copyWith(
          isBought: newBoughtState,
          boughtAt: newBoughtState ? DateTime.now() : null,
          cost: finalCost,
        );

        await _repository.updateProduct(updatedProduct);
        await _reloadData();
      } else {
        await _reloadData();
      }
    } catch (error, stackTrace) {
      state = previousState;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar producto: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> removeProduct(String id) async {
    await _repository.removeProduct(id);
    await _reloadData();
  }

  Future<void> clearCompleted() async {
    await _repository.clearCompletedProducts();
    await _reloadData();
  }

  Future<void> updateProduct(Product product) async {
    await _repository.updateProduct(product);
    await _reloadData();
  }
}

final detailedStatsTimePeriodFilterProvider = StateProvider<StatsTimePeriod>(
  (ref) => StatsTimePeriod.monthly,
);

String getPeriodLabel(StatsTimePeriod period, {bool forTitle = false}) {
  if (forTitle) {
    switch (period) {
      case StatsTimePeriod.daily:
        return "Reporte Diario";
      case StatsTimePeriod.weekly:
        return "Reporte Semanal";
      case StatsTimePeriod.monthly:
        return "Reporte Mensual";
      case StatsTimePeriod.yearly:
        return "Reporte Anual";
      case StatsTimePeriod.lifetime:
        return "Reporte Total";
    }
  } else {
    switch (period) {
      case StatsTimePeriod.daily:
        return "Día";
      case StatsTimePeriod.weekly:
        return "Semana";
      case StatsTimePeriod.monthly:
        return "Mes";
      case StatsTimePeriod.yearly:
        return "Año";
      case StatsTimePeriod.lifetime:
        return "Total";
    }
  }
}

final detailedStatsProvider = FutureProvider<AppDetailedStats>((ref) async {
  final allBoughtProducts = await ref.watch(allBoughtProductsProvider.future);
  final selectedPeriod = ref.watch(detailedStatsTimePeriodFilterProvider);

  List<Product> periodFilteredBoughtProducts;
  DateTime now = DateTime.now();

  switch (selectedPeriod) {
    case StatsTimePeriod.daily:
      final startOfPeriod = DateTime(now.year, now.month, now.day);
      periodFilteredBoughtProducts =
          allBoughtProducts
              .where(
                (p) => p.boughtAt!.isAfter(
                  startOfPeriod.subtract(Duration(microseconds: 1)),
                ),
              )
              .toList();
      break;
    case StatsTimePeriod.weekly:
      final startOfPeriod = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      periodFilteredBoughtProducts =
          allBoughtProducts
              .where(
                (p) => p.boughtAt!.isAfter(
                  startOfPeriod.subtract(Duration(microseconds: 1)),
                ),
              )
              .toList();
      break;
    case StatsTimePeriod.monthly:
      final startOfPeriod = DateTime(now.year, now.month, 1);
      periodFilteredBoughtProducts =
          allBoughtProducts
              .where(
                (p) => p.boughtAt!.isAfter(
                  startOfPeriod.subtract(Duration(microseconds: 1)),
                ),
              )
              .toList();
      break;
    case StatsTimePeriod.yearly:
      periodFilteredBoughtProducts =
          allBoughtProducts.where((p) => p.boughtAt!.year == now.year).toList();
      break;
    case StatsTimePeriod.lifetime:
    default:
      periodFilteredBoughtProducts = allBoughtProducts;
      break;
  }

  final String periodTypeLabel = getPeriodLabel(selectedPeriod, forTitle: true);

  if (allBoughtProducts.isEmpty) {
    return AppDetailedStats.empty(periodTypeLabel: periodTypeLabel);
  }

  final spendingByPeriod = <String, double>{};
  DateFormat periodKeyFormatter;

  switch (selectedPeriod) {
    case StatsTimePeriod.daily:
      periodKeyFormatter = DateFormat('yyyy-MM-dd (EEEE)', 'es_ES');
      final groupedByDay = groupBy(
        allBoughtProducts,
        (Product p) => periodKeyFormatter.format(p.boughtAt!),
      );
      groupedByDay.forEach((key, prods) {
        spendingByPeriod[key] = prods.fold(
          0.0,
          (sum, p) => sum + (p.cost! * p.quantity),
        );
      });
      break;
    case StatsTimePeriod.weekly:
      final groupedByWeek = groupBy(allBoughtProducts, (Product p) {
        final day = p.boughtAt!;
        final mondayOfWeek = day.subtract(Duration(days: day.weekday - 1));
        return DateFormat('yyyy-MM-dd', 'es_ES').format(mondayOfWeek);
      });
      groupedByWeek.forEach((key, prods) {
        spendingByPeriod[key] = prods.fold(
          0.0,
          (sum, p) => sum + (p.cost! * p.quantity),
        );
      });
      break;
    case StatsTimePeriod.monthly:
      periodKeyFormatter = DateFormat('yyyy-MM (MMMM)', 'es_ES');
      final groupedByMonth = groupBy(
        allBoughtProducts,
        (Product p) => periodKeyFormatter.format(p.boughtAt!),
      );
      groupedByMonth.forEach((key, prods) {
        spendingByPeriod[key] = prods.fold(
          0.0,
          (sum, p) => sum + (p.cost! * p.quantity),
        );
      });
      break;
    case StatsTimePeriod.yearly:
      periodKeyFormatter = DateFormat('yyyy', 'es_ES');
      final groupedByYear = groupBy(
        allBoughtProducts,
        (Product p) => periodKeyFormatter.format(p.boughtAt!),
      );
      groupedByYear.forEach((key, prods) {
        spendingByPeriod[key] = prods.fold(
          0.0,
          (sum, p) => sum + (p.cost! * p.quantity),
        );
      });
      break;
    case StatsTimePeriod.lifetime:
    default:
      periodKeyFormatter = DateFormat('yyyy-MM (MMMM)', 'es_ES');
      final groupedByMonthLifetime = groupBy(
        allBoughtProducts,
        (Product p) => periodKeyFormatter.format(p.boughtAt!),
      );
      groupedByMonthLifetime.forEach((key, prods) {
        spendingByPeriod[key] = prods.fold(
          0.0,
          (sum, p) => sum + (p.cost! * p.quantity),
        );
      });
      break;
  }

  ProductPopularity? mostBoughtProductForPeriod;
  if (periodFilteredBoughtProducts.isNotEmpty) {
    final productCounts = <String, List<Product>>{};
    for (var p in periodFilteredBoughtProducts) {
      productCounts.putIfAbsent(p.name, () => []).add(p);
    }

    final popularities =
        productCounts.entries.map((entry) {
          final items = entry.value;
          return ProductPopularity(
            name: entry.key,
            timesBought: items.length,
            totalQuantityBought: items.fold(
              0,
              (sum, item) => sum + item.quantity,
            ),
            totalSpentOnProduct: items.fold(
              0.0,
              (sum, item) => sum + (item.cost! * item.quantity),
            ),
          );
        }).toList();
    popularities.sort((a, b) {
      int compare = b.timesBought.compareTo(a.timesBought);
      if (compare == 0)
        compare = b.totalQuantityBought.compareTo(a.totalQuantityBought);
      if (compare == 0)
        compare = b.totalSpentOnProduct.compareTo(a.totalSpentOnProduct);
      return compare;
    });
    mostBoughtProductForPeriod = popularities.firstOrNull;
  }

  DatedAmount? mostExpensiveProductInPeriod;
  if (periodFilteredBoughtProducts.isNotEmpty) {
    final sortedByCost = List<Product>.from(periodFilteredBoughtProducts)
      ..sort((a, b) => (b.cost! * b.quantity).compareTo(a.cost! * a.quantity));
    if (sortedByCost.isNotEmpty) {
      final mostExpensive = sortedByCost.first;
      mostExpensiveProductInPeriod = DatedAmount(
        date: mostExpensive.boughtAt!,
        amount: mostExpensive.cost! * mostExpensive.quantity,
        details: '${mostExpensive.name} (Cant: ${mostExpensive.quantity})',
      );
    }
  }

  final double totalSpendingForPeriod = periodFilteredBoughtProducts.fold(
    0.0,
    (sum, p) => sum + (p.cost! * p.quantity),
  );
  final int totalProductsBoughtInPeriod = periodFilteredBoughtProducts.fold(
    0,
    (sum, p) => sum + p.quantity,
  );

  final totalLifetimeSpending = allBoughtProducts.fold(
    0.0,
    (sum, p) => sum + (p.cost! * p.quantity),
  );
  final totalProductsBoughtAllTime = allBoughtProducts.fold(
    0,
    (sum, p) => sum + p.quantity,
  );

  return AppDetailedStats(
    spendingByPeriod: spendingByPeriod,
    periodTypeLabel: periodTypeLabel,
    mostBoughtProduct: mostBoughtProductForPeriod,
    mostExpensiveProductInstance: mostExpensiveProductInPeriod,
    totalLifetimeSpending: totalLifetimeSpending,
    totalProductsBoughtAllTime: totalProductsBoughtAllTime,
    totalSpendingForPeriod: totalSpendingForPeriod,
    totalProductsBoughtInPeriod: totalProductsBoughtInPeriod,
  );
});

class ProductChartData {
  final List<FlSpot> spendingOverTimeSpots;
  final List<String> spendingOverTimeLabels;
  final String timePeriodTitle;
  final Map<String, double> spendingByCategory;
  final Map<String, int> productPurchaseFrequency;

  ProductChartData({
    required this.spendingOverTimeSpots,
    required this.spendingOverTimeLabels,
    required this.timePeriodTitle,
    required this.spendingByCategory,
    required this.productPurchaseFrequency,
  });

  factory ProductChartData.empty() {
    return ProductChartData(
      spendingOverTimeSpots: [],
      spendingOverTimeLabels: [],
      timePeriodTitle: "Gasto a lo Largo del Tiempo",
      spendingByCategory: {},
      productPurchaseFrequency: {},
    );
  }
}

// New provider for chart time period filter
final chartTimePeriodProvider = StateProvider<StatsTimePeriod>(
  (ref) => StatsTimePeriod.monthly,
);

final productChartDataProvider = FutureProvider<ProductChartData>((ref) async {
  final boughtProducts = await ref.watch(allBoughtProductsProvider.future);
  final selectedPeriod = ref.watch(chartTimePeriodProvider);

  if (boughtProducts.isEmpty) {
    return ProductChartData.empty();
  }

  // Filter products based on selected period
  List<Product> periodFilteredBoughtProducts;
  DateTime now = DateTime.now();
  switch (selectedPeriod) {
    case StatsTimePeriod.daily:
      final startOfPeriod = now.subtract(Duration(days: 6)); // Last 7 days
      periodFilteredBoughtProducts =
          boughtProducts
              .where((p) => p.boughtAt!.isAfter(startOfPeriod))
              .toList();
      break;
    case StatsTimePeriod.weekly:
      final startOfPeriod = now.subtract(
        Duration(days: (8 * 7) - 1),
      ); // Last 8 weeks
      periodFilteredBoughtProducts =
          boughtProducts
              .where((p) => p.boughtAt!.isAfter(startOfPeriod))
              .toList();
      break;
    case StatsTimePeriod.monthly:
      final startOfPeriod = DateTime(
        now.year - 1,
        now.month,
        now.day,
      ); // Last 12 months
      periodFilteredBoughtProducts =
          boughtProducts
              .where((p) => p.boughtAt!.isAfter(startOfPeriod))
              .toList();
      break;
    case StatsTimePeriod.yearly:
      periodFilteredBoughtProducts = boughtProducts; // All years
      break;
    case StatsTimePeriod.lifetime:
    default:
      periodFilteredBoughtProducts = boughtProducts;
      break;
  }

  // --- Spending Over Time Chart ---
  List<FlSpot> spendingOverTimeSpots = [];
  List<String> spendingOverTimeLabels = [];
  String timePeriodTitle;

  final groupedData = <DateTime, double>{};

  switch (selectedPeriod) {
    case StatsTimePeriod.daily:
      timePeriodTitle = "Gasto Diario (Últimos 7 Días)";
      final dailyMap = groupBy(
        periodFilteredBoughtProducts,
        (Product p) =>
            DateTime(p.boughtAt!.year, p.boughtAt!.month, p.boughtAt!.day),
      );
      dailyMap.forEach((key, prods) {
        groupedData[key] = prods.fold(
          0.0,
          (sum, p) => sum + (p.cost! * p.quantity),
        );
      });
      break;
    case StatsTimePeriod.weekly:
      timePeriodTitle = "Gasto Semanal (8 Semanas)";
      final weeklyMap = groupBy(periodFilteredBoughtProducts, (Product p) {
        final day = p.boughtAt!;
        return day.subtract(
          Duration(days: day.weekday - 1),
        ); // Monday of the week
      });
      weeklyMap.forEach((key, prods) {
        groupedData[key] = prods.fold(
          0.0,
          (sum, p) => sum + (p.cost! * p.quantity),
        );
      });
      break;
    case StatsTimePeriod.yearly:
      timePeriodTitle = "Gasto Anual";
      final yearlyMap = groupBy(
        periodFilteredBoughtProducts,
        (Product p) => DateTime(p.boughtAt!.year),
      );
      yearlyMap.forEach((key, prods) {
        groupedData[key] = prods.fold(
          0.0,
          (sum, p) => sum + (p.cost! * p.quantity),
        );
      });
      break;
    case StatsTimePeriod.lifetime:
    case StatsTimePeriod.monthly:
    default:
      timePeriodTitle = "Gasto Mensual (12 Meses)";
      final monthlyMap = groupBy(
        periodFilteredBoughtProducts,
        (Product p) => DateTime(p.boughtAt!.year, p.boughtAt!.month),
      );
      monthlyMap.forEach((key, prods) {
        groupedData[key] = prods.fold(
          0.0,
          (sum, p) => sum + (p.cost! * p.quantity),
        );
      });
      break;
  }

  final sortedKeys = groupedData.keys.toList()..sort();
  for (int i = 0; i < sortedKeys.length; i++) {
    final key = sortedKeys[i];
    spendingOverTimeSpots.add(FlSpot(i.toDouble(), groupedData[key]!));
    // Adjust label format based on period
    String label;
    switch (selectedPeriod) {
      case StatsTimePeriod.daily:
        label = DateFormat('dd/MM', 'es_ES').format(key);
        break;
      case StatsTimePeriod.weekly:
        label = DateFormat('dd/MM', 'es_ES').format(key);
        break;
      case StatsTimePeriod.yearly:
        label = DateFormat('yyyy', 'es_ES').format(key);
        break;
      default:
        label = DateFormat('MMM yy', 'es_ES').format(key);
        break;
    }
    spendingOverTimeLabels.add(label);
  }

  // --- Other Charts (using the filtered data for the period) ---
  final spendingByCategory = <String, double>{};
  final groupedByCategory = groupBy(
    periodFilteredBoughtProducts,
    (Product p) => p.category,
  );
  groupedByCategory.forEach((category, prodsInCategory) {
    spendingByCategory[category] = prodsInCategory.fold(
      0.0,
      (sum, p) => sum + (p.cost! * p.quantity),
    );
  });

  final productPurchaseFrequency = <String, int>{};
  final groupedByName = groupBy(
    periodFilteredBoughtProducts,
    (Product p) => p.name,
  );
  groupedByName.forEach((name, prods) {
    productPurchaseFrequency[name] = prods.length;
  });

  var sortedFrequency =
      productPurchaseFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
  if (sortedFrequency.length > 7) {
    final otherCount = sortedFrequency
        .sublist(6)
        .fold(0, (sum, e) => sum + e.value);
    sortedFrequency = sortedFrequency.sublist(0, 6);
    if (otherCount > 0) {
      sortedFrequency.add(MapEntry('Otros', otherCount));
    }
  }
  final topProductFrequency = Map.fromEntries(sortedFrequency);

  return ProductChartData(
    spendingOverTimeSpots: spendingOverTimeSpots,
    spendingOverTimeLabels: spendingOverTimeLabels,
    timePeriodTitle: timePeriodTitle,
    spendingByCategory: spendingByCategory,
    productPurchaseFrequency: topProductFrequency,
  );
});
