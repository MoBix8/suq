import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/product_options.dart';
import '../../core/theme.dart';
import '../../core/translation_service.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/export_import.dart';
import '../../widgets/pager.dart';

class ProductsTab extends ConsumerStatefulWidget {
  const ProductsTab({super.key});

  @override
  ConsumerState<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<ProductsTab> {
  static const _pageSize = 25;

  final _search = TextEditingController();
  Timer? _searchDebounce;
  String _searchText = '';
  String _query = '';
  String _categoryFilter = '';
  int _page = 1;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchText = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _page = 1;
      });
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _search.clear();
    setState(() {
      _searchText = '';
      _query = '';
      _page = 1;
    });
  }

  Future<void> _openEditor(
    List<LibraryCategory> categories, {
    LibraryProduct? product,
  }) async {
    if (categories.isEmpty) {
      showAppSnack(
        context,
        'Create a category before adding products.',
        error: true,
      );
      return;
    }

    final draft = await showDialog<_ProductDraft>(
      context: context,
      builder: (context) =>
          _ProductDialog(categories: categories, product: product),
    );
    if (draft == null) return;

    try {
      final api = ref.read(apiProvider);
      if (product == null) {
        await api.post('/admin/library/products', body: draft.toJson());
      } else {
        await api.patch(
          '/admin/library/products/${product.id}',
          body: draft.toJson(),
        );
      }
      ref.invalidate(libraryProductsProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(allCategoriesProvider);
      if (mounted) {
        setState(() => _page = 1);
        showAppSnack(
          context,
          product == null
              ? 'Product added to the library.'
              : 'Product updated.',
        );
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
        await api.patch(
          '/admin/library/products/${product.id}',
          body: {'active': true},
        );
      }
      ref.invalidate(libraryProductsProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(allCategoriesProvider);
      if (mounted) {
        showAppSnack(
          context,
          deactivating ? 'Product deactivated.' : 'Product reactivated.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final categories =
        categoriesAsync.asData?.value ?? const <LibraryCategory>[];
    // Fall back to "all" if the selected category no longer exists.
    final selectedCategory =
        _categoryFilter.isEmpty ||
            categories.any((category) => category.id == _categoryFilter)
        ? _categoryFilter
        : '';
    final query = LibraryProductQuery(
      categoryId: selectedCategory.isEmpty ? null : selectedCategory,
      query: _query,
      page: _page,
      pageSize: _pageSize,
    );
    final productsAsync = ref.watch(libraryProductsProvider(query));
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 20,
            compact ? 8 : 16,
            compact ? 12 : 20,
            compact ? 4 : 8,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        isDense: compact,
                        contentPadding: compact
                            ? const EdgeInsets.symmetric(vertical: 10)
                            : null,
                        hintText: 'Search library by name, SKU, or barcode',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchText.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                  if (compact) ...[
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      tooltip: 'New product',
                      onPressed: categoriesAsync.isLoading
                          ? null
                          : () => _openEditor(categories),
                      icon: const Icon(Icons.add_rounded),
                    ),
                    ExportImportButtons(
                      exportPath: '/admin/export/products',
                      importPath: '/admin/import/products',
                      onImported: () {
                        ref.invalidate(libraryProductsProvider);
                        ref.invalidate(categoriesProvider);
                        ref.invalidate(allCategoriesProvider);
                      },
                    ),
                  ],
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: categoriesAsync.isLoading
                          ? null
                          : () => _openEditor(categories),
                      icon: const Icon(Icons.add_rounded, size: 19),
                      label: const Text('New product'),
                    ),
                    ExportImportButtons(
                      exportPath: '/admin/export/products',
                      importPath: '/admin/import/products',
                      onImported: () {
                        ref.invalidate(libraryProductsProvider);
                        ref.invalidate(categoriesProvider);
                        ref.invalidate(allCategoriesProvider);
                      },
                    ),
                  ],
                ),
              ],
              SizedBox(height: compact ? 6 : 10),
              Row(
                children: [
                  if (compact)
                    Expanded(
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
                                  child: Text(
                                    category.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              _categoryFilter = value ?? '';
                              _page = 1;
                            }),
                          ),
                        ),
                      ),
                    )
                  else
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
                                  child: Text(
                                    category.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              _categoryFilter = value ?? '';
                              _page = 1;
                            }),
                          ),
                        ),
                      ),
                    ),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    if (categoriesAsync.hasError)
                      Expanded(
                        child: Text(
                          categoriesAsync.error.toString(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AdminColors.danger,
                          ),
                        ),
                      )
                    else
                      const Expanded(
                        child: Text(
                          'Products downloaded by shops keep their own selling price.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AdminColors.muted,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<PagedLibraryProducts>(
            value: productsAsync,
            onRetry: () => ref.invalidate(libraryProductsProvider(query)),
            loadingMessage: 'Loading library products…',
            builder: (pageData) {
              final records = pageData.items;
              if (records.isEmpty) {
                return Column(
                  children: [
                    Expanded(
                      child: EmptyState(
                        icon: Icons.inventory_2_rounded,
                        title: _query.isEmpty
                            ? 'No products here'
                            : 'No products match your search',
                        message: _query.isEmpty
                            ? 'Add products to the shared library so shops can download them.'
                            : 'Try a different name, SKU, or barcode.',
                      ),
                    ),
                    CatalogPager(
                      page: pageData.page,
                      pageSize: pageData.pageSize,
                      total: pageData.total,
                      onPrevious: pageData.page > 1
                          ? () => setState(() => _page -= 1)
                          : null,
                      onNext: pageData.hasMore
                          ? () => setState(() => _page += 1)
                          : null,
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: records.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = records[index];
                        return SectionCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AdminColors.seed.withValues(
                                    alpha: 0.09,
                                  ),
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
                                            _adminProductDisplayName(product),
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
                                              ? Icons
                                                    .pause_circle_outline_rounded
                                              : Icons
                                                    .play_circle_outline_rounded,
                                          size: 17,
                                          color: product.active
                                              ? AdminColors.danger
                                              : AdminColors.success,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          product.active
                                              ? 'Deactivate'
                                              : 'Reactivate',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  CatalogPager(
                    page: pageData.page,
                    pageSize: pageData.pageSize,
                    total: pageData.total,
                    onPrevious: pageData.page > 1
                        ? () => setState(() => _page -= 1)
                        : null,
                    onNext: pageData.hasMore
                        ? () => setState(() => _page += 1)
                        : null,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

String _adminProductDisplayName(LibraryProduct product) {
  final parts = <String>[product.name];
  if (product.nameAm != null && product.nameAm!.trim().isNotEmpty) {
    parts.add(product.nameAm!.trim());
  }
  if (product.nameOr != null && product.nameOr!.trim().isNotEmpty) {
    parts.add(product.nameOr!.trim());
  }
  return parts.join(' / ');
}

class _ProductDraft {
  const _ProductDraft({
    required this.categoryId,
    required this.name,
    this.nameAm,
    this.nameOr,
    required this.sku,
    required this.barcode,
    required this.unit,
    required this.sellingPrice,
    required this.buyingPrice,
    required this.active,
  });

  final String categoryId;
  final String name;
  final String? nameAm;
  final String? nameOr;
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
      'nameAm': (nameAm ?? '').trim().isEmpty ? null : nameAm!.trim(),
      'nameOr': (nameOr ?? '').trim().isEmpty ? null : nameOr!.trim(),
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
  late final TextEditingController _nameAm;
  late final TextEditingController _nameOr;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _buyingPrice;
  late String _categoryId;
  late String _unit;
  late bool _active;
  bool _suggesting = false;
  String? _suggestionStatus;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _nameAm = TextEditingController(text: product?.nameAm ?? '');
    _nameOr = TextEditingController(text: product?.nameOr ?? '');
    _sku = TextEditingController(text: product?.sku ?? '');
    _barcode = TextEditingController(text: product?.barcode ?? '');
    _unit = product?.unit ?? 'pcs';
    _sellingPrice = TextEditingController(
      text: product == null
          ? ''
          : product.defaultSellingPrice.toStringAsFixed(2),
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
    _nameAm.dispose();
    _nameOr.dispose();
    _sku.dispose();
    _barcode.dispose();
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
        nameAm: _nameAm.text.trim(),
        nameOr: _nameOr.text.trim(),
        sku: _sku.text.trim(),
        barcode: _barcode.text.trim(),
        unit: _unit,
        sellingPrice: double.parse(_sellingPrice.text.trim()),
        buyingPrice: buyingText.isEmpty ? null : double.parse(buyingText),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.product == null ? 'New library product' : 'Edit library product',
      ),
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
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                TextFormField(
                  controller: _nameAm,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name in Amharic (optional)',
                    hintText: 'ስኳር 1kg',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameOr,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name in Afan Oromo (optional)',
                    hintText: 'Sukkaara 1kg',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _suggesting
                        ? null
                        : () async {
                            final name = _name.text.trim();
                            if (name.isEmpty) {
                              setState(
                                () => _suggestionStatus =
                                    'Enter an English name first.',
                              );
                              return;
                            }
                            setState(() {
                              _suggesting = true;
                              _suggestionStatus = 'Contacting Gemini…';
                            });
                            try {
                              final result = await TranslationService().suggest(
                                name,
                              );
                              if (!mounted) return;
                              setState(() {
                                if (result.amharic != null &&
                                    result.amharic!.trim().isNotEmpty) {
                                  _nameAm.text = result.amharic!.trim();
                                }
                                if (result.oromo != null &&
                                    result.oromo!.trim().isNotEmpty) {
                                  _nameOr.text = result.oromo!.trim();
                                }
                                _suggesting = false;
                                _suggestionStatus = 'Done.';
                              });
                            } catch (error) {
                              if (mounted) {
                                setState(() {
                                  _suggesting = false;
                                  _suggestionStatus = error.toString();
                                });
                                showAppSnack(
                                  context,
                                  error.toString(),
                                  error: true,
                                );
                              }
                            }
                          },
                    icon: _suggesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.translate_rounded, size: 18),
                    label: Text(
                      _suggesting
                          ? 'Suggesting…'
                          : 'Suggest translations (Gemini)',
                    ),
                  ),
                ),
                if (_suggestionStatus != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    _suggestionStatus!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AdminColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: _suggestionStatus!),
                      );
                      showAppSnack(context, 'Copied.');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    label: const Text('Copy'),
                  ),
                ],
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
                        decoration: const InputDecoration(
                          labelText: 'Barcode (optional)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: [
                          for (final unit in productUnits)
                            DropdownMenuItem(value: unit, child: Text(unit)),
                          if (!productUnits.contains(_unit))
                            DropdownMenuItem(value: _unit, child: Text(_unit)),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _unit = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingPrice,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                  subtitle: const Text(
                    'Inactive products are hidden from the library.',
                  ),
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
