import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class ProductsTab extends ConsumerStatefulWidget {
  const ProductsTab({super.key});

  @override
  ConsumerState<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<ProductsTab> {
  final _search = TextEditingController();
  String _query = '';
  String _categoryFilter = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<LibraryProduct> _filter(List<LibraryProduct> products) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          (product.barcode ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openEditor(List<LibraryCategory> categories, {LibraryProduct? product}) async {
    if (categories.isEmpty) {
      showAppSnack(context, 'Create a category before adding products.', error: true);
      return;
    }

    final draft = await showDialog<_ProductDraft>(
      context: context,
      builder: (context) => _ProductDialog(
        categories: categories,
        product: product,
      ),
    );
    if (draft == null) return;

    try {
      final api = ref.read(apiProvider);
      if (product == null) {
        await api.post('/admin/library/products', body: draft.toJson());
      } else {
        await api.patch('/admin/library/products/${product.id}', body: draft.toJson());
      }
      ref.invalidate(libraryProductsProvider);
      ref.invalidate(categoriesProvider);
      if (mounted) {
        showAppSnack(context, product == null ? 'Product added to the library.' : 'Product updated.');
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  Future<void> _toggleActive(LibraryProduct product) async {
    final deactivating = product.active;
    if (deactivating) {
      final confirmed = await confirmAction(
        context,
        title: 'Remove ${product.name}?',
        message:
            'The product is hidden from the library and marked inactive for shops that '
            'already downloaded it. Existing shop data is kept.',
        confirmLabel: 'Deactivate',
        destructive: true,
      );
      if (!confirmed) return;
    }

    try {
      final api = ref.read(apiProvider);
      if (deactivating) {
        await api.delete('/admin/library/products/${product.id}');
      } else {
        await api.patch('/admin/library/products/${product.id}', body: {'active': true});
      }
      ref.invalidate(libraryProductsProvider);
      ref.invalidate(categoriesProvider);
      if (mounted) {
        showAppSnack(context, deactivating ? 'Product deactivated.' : 'Product reactivated.');
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.asData?.value ?? const <LibraryCategory>[];
    // Fall back to "all" if the selected category no longer exists.
    final selectedCategory = categories.any((category) => category.id == _categoryFilter)
        ? _categoryFilter
        : '';
    final productsAsync = ref.watch(
      libraryProductsProvider(selectedCategory.isEmpty ? null : selectedCategory),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search library by name, SKU, or barcode',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: categoriesAsync.isLoading
                        ? null
                        : () => _openEditor(categories),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('New product'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 250,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All categories'),
                            ),
                            for (final category in categories)
                              DropdownMenuItem(
                                value: category.id,
                                child: Text(category.name, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _categoryFilter = value ?? ''),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (categoriesAsync.hasError)
                    Expanded(
                      child: Text(
                        categoriesAsync.error.toString(),
                        style: const TextStyle(fontSize: 11.5, color: AdminColors.danger),
                      ),
                    )
                  else
                    const Expanded(
                      child: Text(
                        'Products downloaded by shops keep their own selling price.',
                        style: TextStyle(fontSize: 11.5, color: AdminColors.muted),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<List<LibraryProduct>>(
            value: productsAsync,
            onRetry: () => ref.invalidate(libraryProductsProvider),
            loadingMessage: 'Loading library products…',
            builder: (records) {
              final filtered = _filter(records);
              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.inventory_2_rounded,
                  title: _query.isEmpty ? 'No products here' : 'No products match your search',
                  message: _query.isEmpty
                      ? 'Add products to the shared library so shops can download them.'
                      : 'Try a different name, SKU, or barcode.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = filtered[index];
                  return SectionCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AdminColors.seed.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            size: 18,
                            color: AdminColors.seed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AdminColors.ink,
                                      ),
                                    ),
                                  ),
                                  if (!product.active) ...[
                                    const SizedBox(width: 8),
                                    const StatusChip(
                                      label: 'INACTIVE',
                                      color: AdminColors.muted,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${product.categoryName} · ${product.sku}'
                                '${(product.barcode ?? '').isEmpty ? '' : ' · ${product.barcode}'}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AdminColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${money(product.defaultSellingPrice)} / ${product.unit}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AdminColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              product.defaultBuyingPrice == null
                                  ? 'No buying price'
                                  : 'Buy ${money(product.defaultBuyingPrice!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AdminColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          tooltip: 'Product actions',
                          onSelected: (value) {
                            if (value == 'edit') {
                              _openEditor(categories, product: product);
                            } else if (value == 'toggle') {
                              _toggleActive(product);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 17),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Row(
                                children: [
                                  Icon(
                                    product.active
                                        ? Icons.pause_circle_outline_rounded
                                        : Icons.play_circle_outline_rounded,
                                    size: 17,
                                    color: product.active
                                        ? AdminColors.danger
                                        : AdminColors.success,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(product.active ? 'Deactivate' : 'Reactivate'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductDraft {
  const _ProductDraft({
    required this.categoryId,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.unit,
    required this.sellingPrice,
    required this.buyingPrice,
    required this.active,
  });

  final String categoryId;
  final String name;
  final String sku;
  final String barcode;
  final String unit;
  final double sellingPrice;
  final double? buyingPrice;
  final bool active;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'categoryId': categoryId,
      'name': name,
      'barcode': barcode.isEmpty ? null : barcode,
      'unit': unit,
      'defaultSellingPrice': sellingPrice,
      'defaultBuyingPrice': buyingPrice,
      'active': active,
    };
    if (sku.isNotEmpty) json['sku'] = sku;
    return json;
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({required this.categories, this.product});

  final List<LibraryCategory> categories;
  final LibraryProduct? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _unit;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _buyingPrice;
  late String _categoryId;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _sku = TextEditingController(text: product?.sku ?? '');
    _barcode = TextEditingController(text: product?.barcode ?? '');
    _unit = TextEditingController(text: product?.unit ?? 'pcs');
    _sellingPrice = TextEditingController(
      text: product == null ? '' : product.defaultSellingPrice.toStringAsFixed(2),
    );
    _buyingPrice = TextEditingController(
      text: product?.defaultBuyingPrice == null
          ? ''
          : product!.defaultBuyingPrice!.toStringAsFixed(2),
    );
    _categoryId = product?.categoryId ?? widget.categories.first.id;
    _active = product?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _unit.dispose();
    _sellingPrice.dispose();
    _buyingPrice.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final buyingText = _buyingPrice.text.trim();
    Navigator.of(context).pop(
      _ProductDraft(
        categoryId: _categoryId,
        name: _name.text.trim(),
        sku: _sku.text.trim(),
        barcode: _barcode.text.trim(),
        unit: _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
        sellingPrice: double.parse(_sellingPrice.text.trim()),
        buyingPrice: buyingText.isEmpty ? null : double.parse(buyingText),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'New library product' : 'Edit library product'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in widget.categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _categoryId = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Product name'),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'Enter at least 2 characters.'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sku,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'SKU (optional)',
                          helperText: 'Generated automatically when blank.',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _barcode,
                        decoration: const InputDecoration(labelText: 'Barcode (optional)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          hintText: 'pcs, kg, litre…',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingPrice,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Default selling price',
                          prefixText: 'Br ',
                        ),
                        validator: (value) {
                          final price = double.tryParse((value ?? '').trim());
                          if (price == null || price <= 0) {
                            return 'Enter a price above zero.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _buyingPrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Default buying price (optional)',
                    prefixText: 'Br ',
                    helperText: 'Used by shops to estimate profit.',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    final price = double.tryParse(text);
                    if (price == null || price < 0) {
                      return 'Enter zero or a positive amount.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text('Inactive products are hidden from the library.'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.product == null ? 'Add product' : 'Save changes'),
        ),
      ],
    );
  }
}
