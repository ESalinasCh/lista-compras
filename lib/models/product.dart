import 'package:hive/hive.dart';

part 'product.g.dart';

@HiveType(typeId: 0)
class Product extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int quantity;

  @HiveField(3)
  final String category;

  @HiveField(4)
  bool isBought;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  DateTime? boughtAt;

  @HiveField(7)
  String? imagePath;

  @HiveField(8) // New field for cost
  double? cost;

  Product({
    required this.id,
    required this.name,
    required this.quantity,
    required this.category,
    this.isBought = false,
    DateTime? createdAt,
    this.boughtAt,
    this.imagePath,
    this.cost, // Add to constructor
  }) : createdAt = createdAt ?? DateTime.now();

  Product copyWith({
    String? id,
    String? name,
    int? quantity,
    String? category,
    bool? isBought,
    DateTime? createdAt,
    DateTime? boughtAt,
    String? imagePath,
    double? cost, // Add to copyWith
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      isBought: isBought ?? this.isBought,
      createdAt: createdAt ?? this.createdAt,
      boughtAt: boughtAt ?? this.boughtAt,
      imagePath: imagePath ?? this.imagePath,
      cost: cost ?? this.cost, // Add to copyWith
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'category': category,
    'isBought': isBought,
    'createdAt': createdAt.toIso8601String(),
    'boughtAt': boughtAt?.toIso8601String(),
    'imagePath': imagePath,
    'cost': cost,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'],
    name: json['name'],
    quantity: json['quantity'],
    category: json['category'],
    isBought: json['isBought'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
    boughtAt:
        json['boughtAt'] != null ? DateTime.parse(json['boughtAt']) : null,
    imagePath: json['imagePath'],
    cost: (json['cost'] as num?)?.toDouble(), // Ensure correct parsing
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
