enum ProductFilter { all, pending, completed }

class ProductFilterData {
  final ProductFilter filter;
  final String? category;
  final String searchQuery;

  ProductFilterData({
    this.filter = ProductFilter.all,
    this.category,
    this.searchQuery = '',
  });

  ProductFilterData copyWith({
    ProductFilter? filter,
    String? category,
    String? searchQuery,
  }) {
    return ProductFilterData(
      filter: filter ?? this.filter,
      category: category ?? this.category,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
