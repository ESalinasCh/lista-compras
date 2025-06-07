import 'package:compras/ui/widgets/category_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';

class CategoryFilter extends ConsumerWidget {
  const CategoryFilter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(categoryFilterProvider);
    final theme = Theme.of(context);

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('Todos'),
                selected: selectedCategory == null,
                onSelected: (selected) {
                  ref.read(categoryFilterProvider.notifier).state = null;
                },
                selectedColor: theme.colorScheme.primaryContainer,
                checkmarkColor: theme.colorScheme.onPrimaryContainer,
              ),
            );
          }

          final category = categories[index - 1];
          final isSelected = selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                ref.read(categoryFilterProvider.notifier).state =
                    selected ? category : null;
              },
              avatar: Icon(
                CategoryUtils.getCategoryIcon(category),
                size: 18,
                color:
                    isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : CategoryUtils.getCategoryColor(category),
              ),
              selectedColor: CategoryUtils.getCategoryColor(
                category,
              ).withOpacity(0.3),
              checkmarkColor: CategoryUtils.getCategoryColor(category),
              labelStyle: TextStyle(
                color: isSelected ? theme.colorScheme.onPrimaryContainer : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
