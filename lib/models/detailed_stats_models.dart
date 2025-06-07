enum StatsTimePeriod { daily, weekly, monthly, yearly, lifetime }

class DatedAmount {
  final DateTime date;
  final double amount;
  final String? details;

  DatedAmount({required this.date, required this.amount, this.details});
}

class ProductPopularity {
  final String name;
  final int
  timesBought; // How many separate purchase entries for this product name
  final int totalQuantityBought; // Sum of quantities for this product name
  final double totalSpentOnProduct;

  ProductPopularity({
    required this.name,
    required this.timesBought,
    required this.totalQuantityBought,
    required this.totalSpentOnProduct,
  });
}

class AppDetailedStats {
  final Map<String, double> spendingByPeriod;
  final String periodTypeLabel;
  final ProductPopularity? mostBoughtProduct;
  final DatedAmount? mostExpensiveProductInstance;
  final double
  totalLifetimeSpending; // This will always be lifetime, regardless of period filter
  final int totalProductsBoughtAllTime; // This will also be lifetime

  // Stats specific to the selected period
  final double totalSpendingForPeriod;
  final int totalProductsBoughtInPeriod;

  AppDetailedStats({
    required this.spendingByPeriod,
    required this.periodTypeLabel,
    this.mostBoughtProduct, // This will be filtered by selected period
    this.mostExpensiveProductInstance, // This will be filtered by selected period
    required this.totalLifetimeSpending,
    required this.totalProductsBoughtAllTime,
    required this.totalSpendingForPeriod,
    required this.totalProductsBoughtInPeriod,
  });

  factory AppDetailedStats.empty({required String periodTypeLabel}) {
    return AppDetailedStats(
      spendingByPeriod: {},
      periodTypeLabel: periodTypeLabel,
      mostBoughtProduct: null,
      mostExpensiveProductInstance: null,
      totalLifetimeSpending: 0.0,
      totalProductsBoughtAllTime: 0,
      totalSpendingForPeriod: 0.0,
      totalProductsBoughtInPeriod: 0,
    );
  }
}
