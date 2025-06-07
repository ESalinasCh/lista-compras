import 'package:flutter/material.dart';

class CategoryUtils {
  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'frutas y verduras':
        return Icons.eco_rounded;
      case 'lácteos':
        return Icons.icecream_rounded;
      case 'carnes':
        return Icons.kebab_dining_rounded;
      case 'limpieza':
        return Icons.cleaning_services_rounded;
      case 'bebidas':
        return Icons.local_bar_rounded;
      case 'panadería':
        return Icons.bakery_dining_rounded;
      case 'congelados':
        return Icons.ac_unit_rounded;
      case 'otros':
        return Icons.more_horiz_rounded;
      default:
        return Icons.shopping_basket_rounded;
    }
  }

  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'frutas y verduras':
        return Colors.green.shade600;
      case 'lácteos':
        return Colors.blue.shade400;
      case 'carnes':
        return Colors.red.shade400;
      case 'limpieza':
        return Colors.purple.shade400;
      case 'bebidas':
        return Colors.orange.shade600;
      case 'panadería':
        return Colors.brown.shade400;
      case 'congelados':
        return Colors.cyan.shade400;
      case 'otros':
        return Colors.teal.shade400;
      default:
        return Colors.grey.shade600;
    }
  }
}
