import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import 'product_dialog.dart';

class ProductsTab extends ConsumerStatefulWidget {
  const ProductsTab({super.key});

  @override
  ConsumerState<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<ProductsTab> {
  static const _pageSize = 10;

  final _search = TextEditingController();
  Timer? _searchDebounce;
  List<SupplierProduct> _products = const [];
  List<SupplierCategory> _categories = const [];
  String _query = '';
  String? _categoryId;
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  List<SupplierCategory> _ownCategories(String supplierId) =>
      _categories.where((category) => category.supplierId == supplierId).toList();

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() {
      if (_products.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiProvider).get(
            '/supplier/products',
            query: {
              'page': '$_page',
              'pageSize': '$_pageSize',
              if (_categoryId != null) 'categoryId': _categoryId,
              if (_query.trim().isNotEmpty) 'q': _query.trim(),
            },
          );
      if (!mounted) return;
      final products = (response['products'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => SupplierProduct.fromJson(asMap(row)))
          .toList();
      setState(() {
        _products = products;
        _total = asInt(response['total']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : error.toString();
      });
    }
  }

  /// Loads the category chips ten at a time. Categories are a small dimension
  /// table, but the "ten per page" rule still applies to every server list.
  Future<void> _loadCategories() async {
    final all = <SupplierCategory>[];
    try {
      var page = 1;
      while (true) {
        final response = await ref.read(apiProvider).get(
              '/supplier/categories',
              query: {'page': '$page', 'pageSize': '10'},
            );
        final items = (response['categories'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => SupplierCategory.fromJson(asMap(row)))
            .toList();
        all.addAll(items);
        final total = asInt(response['total']);
        if (items.isEmpty || all.length >= total) break;
        page += 1;
      }
      if (!mounted) return;
      setState(() => _categories = all);
    } catch (_) {
      // The product list still works without the category chips.
    }
  }

  void _searchChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _page = 1);
      _loadProducts();
    });
  }

  void _selectCategory(String? id) {
    setState(() {
      _categoryId = id;
      _page = 1;
    });
    _loadProducts();
  }

  Future<void> _refresh() async {
    await Future.wait([_loadProducts(), _loadCategories()]);
  }

  Future<void> _openEditor({SupplierProduct? product}) async {
    final ownCategories = _ownCategories(
      ref.read(sessionProvider).supplier?.id ?? '',
    );
    if (ownCategories.isEmpty) {
      showAppSnack(
        context,
        'Create one of your own categories before adding products.',
        error: true,
      );
      return;
    }

    final draft = await showDialog<ProductDraft>(
      context: context,
      builder: (_) => ProductDialog(categories: ownCategories, product: product),
    );
    if (draft == null) return;

    try {
      final api = ref.read(apiProvider);
      if (product == null) {
        await api.post('/supplier/products', body: draft.toJson());
      } else {
        await api.patch('/supplier/products/${product.id}', body: draft.toJson());
      }
      ref.invalidate(summaryProvider);
      if (!mounted) return;
      setState(() => _page = 1);
      await _refresh();
      if (mounted) {
        showAppSnack(
          context,
          product == null ? 'Product added to the shared library.' : 'Product updated.',
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
    final supplierId = ref.watch(sessionProvider).supplier?.id ?? '';
    final ownCategories = _ownCategories(supplierId);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const InfoBanner(
                    message:
                        'This is the same retail product library shops browse in the client app. Add products to share them; SUQ and other suppliers\' entries are read-only here.',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: _searchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search name, SKU or translation',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      _search.clear();
                                      _searchDebounce?.cancel();
                                      setState(() {
                                        _query = '';
                                        _page = 1;
                                      });
                                      _loadProducts();
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.add_rounded, size: 19),
                        label: const Text('Add product'),
                      ),
                    ],
                  ),
                  if (_categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: const Text('All categories'),
                              selected: _categoryId == null,
                              onSelected: (_) => _selectCategory(null),
                            ),
                          ),
                          for (final category in _categories)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  '${category.name} (${category.productCount})',
                                ),
                                selected: _categoryId == category.id,
                                onSelected: (_) => _selectCategory(category.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (_error != null) ...[
                    _inlineError(_error!),
                    const SizedBox(height: 8),
                  ],
                  if (_loading && _products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_products.isEmpty)
                    EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: _total == 0 ? 'No products yet' : 'No matching products',
                      message: _total == 0
                          ? 'Add your first product to the shared library shops copy from.'
                          : 'Try a different search or category filter.',
                      action: _total == 0
                          ? FilledButton.icon(
                              onPressed: () => _openEditor(),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add a product'),
                            )
                          : null,
                    )
                  else ...[
                    for (final product in _products) ...[
                      _ProductCard(
                        product: product,
                        canEdit: product.supplierId == supplierId,
                        onEdit: () => _openEditor(product: product),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _pagination(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineError(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SupplierColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: SupplierColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: SupplierColors.danger),
            ),
          ),
          TextButton(onPressed: _loadProducts, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _pagination() {
    final start = (_page - 1) * _pageSize + 1;
    final end = math.min(_page * _pageSize, _total);
    final pages = math.max(1, (_total / _pageSize).ceil());
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: _page > 1
              ? () {
                  setState(() => _page -= 1);
                  _loadProducts();
                }
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            '$start–$end of $_total · page $_page of $pages',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: SupplierColors.muted),
          ),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: _page < pages
              ? () {
                  setState(() => _page += 1);
                  _loadProducts();
                }
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.canEdit,
    required this.onEdit,
  });

  final SupplierProduct product;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final translations = [
      if ((product.nameAm ?? '').trim().isNotEmpty) product.nameAm!,
      if ((product.nameOr ?? '').trim().isNotEmpty) product.nameOr!,
    ];
    final source = product.supplierId.isEmpty
        ? 'SUQ library'
        : canEdit
            ? 'Your product'
            : 'Shared library';

    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SupplierColors.seed.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: SupplierColors.seed,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: SupplierColors.ink,
                      ),
                    ),
                    StatusChip(
                      label: source,
                      color: canEdit
                          ? SupplierColors.seed
                          : SupplierColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${product.sku} · ${product.unit} · ${product.categoryName}',
                  style: const TextStyle(
                    color: SupplierColors.muted,
                    fontSize: 11.5,
                  ),
                ),
                if (translations.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    translations.join(' · '),
                    style: const TextStyle(
                      color: SupplierColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(product.defaultSellingPrice),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: SupplierColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'retail / ${product.unit}',
                style: const TextStyle(
                  color: SupplierColors.muted,
                  fontSize: 10.5,
                ),
              ),
              if (canEdit) ...[
                const SizedBox(height: 4),
                IconButton(
                  tooltip: 'Edit product',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                ),
              ] else
                const SizedBox(height: 28),
            ],
          ),
        ],
      ),
    );
  }
}
