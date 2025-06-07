import 'package:compras/models/product.dart';

class ShoppingStats {
  final int totalItems;
  final int completedItems;
  final int pendingItems;
  final int categoriesCount;
  final double completionRate;
  final Map<String, int> categoryStats;

  ShoppingStats({
    required this.totalItems,
    required this.completedItems,
    required this.pendingItems,
    required this.categoriesCount,
    required this.completionRate,
    required this.categoryStats,
  });

  factory ShoppingStats.fromProducts(List<Product> products) {
    final completed = products.where((p) => p.isBought).length;
    final total = products.length;
    final pending = total - completed;
    final categories = products.map((p) => p.category).toSet().length;
    final rate = total > 0 ? (completed / total) * 100 : 0.0;

    final categoryStats = <String, int>{};
    for (final product in products) {
      categoryStats[product.category] =
          (categoryStats[product.category] ?? 0) + 1;
    }

    return ShoppingStats(
      totalItems: total,
      completedItems: completed,
      pendingItems: pending,
      categoriesCount: categories,
      completionRate: rate,
      categoryStats: categoryStats,
    );
  }
}
