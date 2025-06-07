import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';

class ProductNotifier extends Notifier<List<Product>> {
  @override
  List<Product> build() {
    return [];
  }

  void addProduct(Product product) {
    state = [...state, product];
  }

  void toggleBought(String id) {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(isBought: !p.isBought) else p,
    ];
  }

  void removeProduct(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void clearBought() {
    state = state.where((p) => !p.isBought).toList();
  }
}

final productProvider = NotifierProvider<ProductNotifier, List<Product>>(() {
  return ProductNotifier();
});
