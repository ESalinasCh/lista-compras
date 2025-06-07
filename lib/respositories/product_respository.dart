import 'package:compras/models/product.dart';
import 'package:hive/hive.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts();
  Future<List<Product>> getPurchaseHistory(); // New method
  Future<void> addProduct(Product product);
  Future<void> removeProduct(String id);
  Future<void> updateProduct(Product product);
  Future<void> clearCompletedProducts();
}

class HiveProductRepository implements ProductRepository {
  final Box<Product> _productBox;
  final Box<Product> _historyBox; // New box for history

  HiveProductRepository()
    : _productBox = Hive.box<Product>('products'),
      _historyBox = Hive.box<Product>('purchaseHistory');

  @override
  Future<List<Product>> getProducts() async {
    return _productBox.values.toList();
  }

  @override
  Future<List<Product>> getPurchaseHistory() async {
    return _historyBox.values.toList();
  }

  @override
  Future<void> addProduct(Product product) async {
    await _productBox.put(product.id, product);
  }

  @override
  Future<void> removeProduct(String id) async {
    await _productBox.delete(id);
  }

  @override
  Future<void> updateProduct(Product product) async {
    await _productBox.put(product.id, product);
  }

  @override
  Future<void> clearCompletedProducts() async {
    final List<Product> completedProducts =
        _productBox.values.where((p) => p.isBought).toList();
    if (completedProducts.isEmpty) return;

    // Create a map of NEW Product instances to move to the history box.
    final Map<String, Product> historyMap = {
      for (var product in completedProducts)
        // CRITICAL FIX: Use copyWith() to create a new, detached instance of the product.
        '${product.id}_${product.boughtAt?.millisecondsSinceEpoch}':
            product.copyWith(),
    };

    await _historyBox.putAll(historyMap);

    final List<dynamic> keysToDelete =
        completedProducts.map((p) => p.key).toList();

    await _productBox.deleteAll(keysToDelete);
  }
}
