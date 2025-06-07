import 'dart:io';
import 'package:compras/ui/widgets/category_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../models/product.dart';
import '../../core/providers/app_providers.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final Product? productToEdit;
  const AddProductScreen({Key? key, this.productToEdit}) : super(key: key);

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _costController;
  String _selectedCategory = 'General';
  bool _isLoading = false;
  File? _imageFile;
  String? _existingImagePath;

  bool get _isEditing => widget.productToEdit != null;

  @override
  void initState() {
    super.initState();
    final categories = ref.read(categoriesProvider);
    _selectedCategory =
        categories.contains('General')
            ? 'General'
            : (categories.isNotEmpty ? categories.first : 'General');

    _nameController = TextEditingController(
      text: widget.productToEdit?.name ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.productToEdit?.quantity.toString() ?? '1',
    );
    final initialCostText =
        widget.productToEdit?.cost != null
            ? widget.productToEdit!.cost!.toStringAsFixed(2)
            : '';
    _costController = TextEditingController(text: initialCostText);

    if (_isEditing) {
      _selectedCategory = widget.productToEdit!.category;
      _existingImagePath = widget.productToEdit!.imagePath;
      if (_existingImagePath != null &&
          File(_existingImagePath!).existsSync()) {
        _imageFile = File(_existingImagePath!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _existingImagePath = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('Seleccionar de Galería'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text('Tomar Foto con Cámara'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
                if (_imageFile != null || _existingImagePath != null)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'Eliminar Imagen',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _imageFile = null;
                        _existingImagePath = null;
                      });
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    try {
      String? finalImagePath = _existingImagePath;
      if (_imageFile != null &&
          (_existingImagePath == null ||
              _imageFile!.path != _existingImagePath)) {
        final appDir = await getApplicationDocumentsDirectory();
        final uniqueFileName =
            '${DateTime.now().millisecondsSinceEpoch}_${p.basename(_imageFile!.path)}';
        final savedImage = await _imageFile!.copy(
          p.join(appDir.path, uniqueFileName),
        );
        finalImagePath = savedImage.path;
      } else if (_imageFile == null &&
          _existingImagePath != null &&
          _isEditing) {
        finalImagePath = null; // Image was removed
      }

      final double? initialCost = double.tryParse(
        _costController.text.replaceAll(',', '.'),
      );

      final product = Product(
        id: _isEditing ? widget.productToEdit!.id : Uuid().v4(),
        name: _nameController.text.trim(),
        quantity: int.parse(_quantityController.text),
        category: _selectedCategory,
        imagePath: finalImagePath,
        cost:
            _isEditing && widget.productToEdit!.isBought
                ? widget.productToEdit!.cost
                : initialCost,
        isBought: _isEditing ? widget.productToEdit!.isBought : false,
        createdAt:
            _isEditing ? widget.productToEdit!.createdAt : DateTime.now(),
        boughtAt: _isEditing ? widget.productToEdit!.boughtAt : null,
      );

      if (_isEditing) {
        await ref.read(productProvider.notifier).updateProduct(product);
      } else {
        await ref.read(productProvider.notifier).addProduct(product);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${product.name} ${_isEditing ? "actualizado" : "agregado"}',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar producto: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Producto' : 'Agregar Producto'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _saveProduct,
              icon:
                  _isLoading
                      ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              theme.colorScheme.onPrimaryContainer ??
                              theme.colorScheme.primary,
                        ),
                      )
                      : Icon(
                        Icons.save_rounded,
                        color: theme.colorScheme.primary,
                      ),
              label: Text(
                'Guardar',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      backgroundImage:
                          (_imageFile != null && _imageFile!.existsSync())
                              ? FileImage(_imageFile!)
                              : null,
                      child:
                          (_imageFile == null || !_imageFile!.existsSync())
                              ? Icon(
                                Icons.add_a_photo_rounded,
                                size: 40,
                                color: theme.colorScheme.onSurfaceVariant,
                              )
                              : null,
                    ),
                  ),
                  Material(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                    elevation: 2,
                    child: InkWell(
                      onTap: _showImageSourceDialog,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalles del Producto',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del producto',
                        prefixIcon: Icon(Icons.shopping_bag_outlined),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: _validateName,
                      onFieldSubmitted:
                          (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        prefixIcon: Icon(Icons.format_list_numbered_rounded),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validateQuantity,
                      onFieldSubmitted:
                          (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _costController,
                      decoration: InputDecoration(
                        labelText: 'Costo Unitario (Opcional)',
                        hintText: 'Ej: 25.50',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                        prefixText: 'Bs. ',
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*[\.,]?\d{0,2}'),
                        ), // Allow . or ,
                      ],
                      validator: _validateCost,
                      onFieldSubmitted: (_) => _saveProduct(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categoría',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items:
                          categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Row(
                                children: [
                                  Icon(
                                    CategoryUtils.getCategoryIcon(category),
                                    color: CategoryUtils.getCategoryColor(
                                      category,
                                    ),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(category),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Selecciona una categoría'
                                  : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveProduct,
              icon:
                  _isLoading
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                      : Icon(
                        _isEditing
                            ? Icons.save_alt_rounded
                            : Icons.add_shopping_cart_rounded,
                      ),
              label: Text(
                _isLoading
                    ? 'Guardando...'
                    : (_isEditing ? 'Actualizar Producto' : 'Agregar Producto'),
              ),
              style: theme.elevatedButtonTheme.style?.copyWith(
                minimumSize: MaterialStateProperty.all(
                  Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty)
      return 'El nombre del producto es requerido.';
    if (value.trim().length < 2)
      return 'El nombre debe tener al menos 2 caracteres.';
    if (value.trim().length > 100)
      return 'El nombre no puede exceder los 100 caracteres.';
    return null;
  }

  String? _validateQuantity(String? value) {
    if (value == null || value.isEmpty) return 'La cantidad es requerida.';
    final quantity = int.tryParse(value);
    if (quantity == null) return 'Ingresa un número válido.';
    if (quantity <= 0) return 'La cantidad debe ser mayor a 0.';
    if (quantity > 9999) return 'La cantidad no puede ser mayor a 9999.';
    return null;
  }

  String? _validateCost(String? value) {
    if (value == null || value.isEmpty) return null;
    final cost = double.tryParse(value.replaceAll(',', '.'));
    if (cost == null) return 'Ingresa un número válido para el costo.';
    if (cost < 0) return 'El costo no puede ser negativo.';
    return null;
  }
}
