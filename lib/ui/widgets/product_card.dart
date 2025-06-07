import 'dart:io';
import 'package:compras/ui/widgets/category_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/product.dart';
import '../../core/providers/app_providers.dart';

class ProductCard extends ConsumerWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({Key? key, required this.product, this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_ES',
      symbol: 'Bs.',
    );

    return Dismissible(
      key: Key(product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete_sweep_rounded,
          color: theme.colorScheme.onErrorContainer,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) => _showDeleteConfirmation(context, product),
      onDismissed: (direction) {
        ref.read(productProvider.notifier).removeProduct(product.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} eliminado'),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () {
                ref.read(productProvider.notifier).addProduct(product);
              },
            ),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap:
              onTap ??
              () {
                Navigator.pushNamed(context, '/add', arguments: product);
              },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      product.imagePath == null
                          ? CategoryUtils.getCategoryColor(product.category)
                          : theme.colorScheme.surfaceVariant,
                  backgroundImage:
                      product.imagePath != null &&
                              File(product.imagePath!).existsSync()
                          ? FileImage(File(product.imagePath!))
                          : null,
                  child:
                      product.imagePath == null ||
                              (product.imagePath != null &&
                                  !File(product.imagePath!).existsSync())
                          ? Icon(
                            CategoryUtils.getCategoryIcon(product.category),
                            color: Colors.white,
                            size: 26,
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration:
                              product.isBought
                                  ? TextDecoration.lineThrough
                                  : null,
                          color:
                              product.isBought
                                  ? theme.colorScheme.onSurface.withOpacity(0.5)
                                  : theme.colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Chip(
                            label: Text(
                              product.category,
                              style: theme.chipTheme.labelStyle,
                            ),
                            padding: theme.chipTheme.padding,
                            backgroundColor:
                                product.isBought
                                    ? theme.chipTheme.backgroundColor
                                        ?.withOpacity(0.5)
                                    : CategoryUtils.getCategoryColor(
                                      product.category,
                                    ).withOpacity(0.15),
                            side: BorderSide.none,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cant: ${product.quantity}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  product.isBought
                                      ? theme.colorScheme.onSurface.withOpacity(
                                        0.5,
                                      )
                                      : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (product.isBought && product.cost != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Costo: ${currencyFormatter.format(product.cost! * product.quantity)} ${product.quantity > 1 ? "(${currencyFormatter.format(product.cost)} c/u)" : ""}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: product.isBought,
                  onChanged: (bool? value) {
                    ref
                        .read(productProvider.notifier)
                        .toggleBought(product.id, context);
                  },
                  activeColor: theme.colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, Product product) {
    return showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Confirmar Eliminación'),
            content: Text(
              '¿Estás seguro de que quieres eliminar "${product.name}"? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }
}
