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
  final _search = TextEditingController();
  String _query = '';
  String? _categoryId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SupplierProduct> _filtered(List<SupplierProduct> products) {
    final query = _query.trim().toLowerCase();
    return products.where((product) {
      if (_categoryId != null && product.categoryId != _categoryId) {
        return false;
      }
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          (product.nameAm ?? '').toLowerCase().contains(query) ||
          (product.nameOr ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openEditor(
    List<SupplierCategory> categories, {
    SupplierProduct? product,
  }) async {
    if (categories.isEmpty) {
      showAppSnack(
        context,
        'Create one of your own categories before adding products.',
        error: true,
      );
      return;
    }

    final draft = await showDialog<ProductDraft>(
      context: context,
      builder: (_) => ProductDialog(categories: categories, product: product),
    );
    if (draft == null) return;

    try {
      final api = ref.read(apiProvider);
      if (product == null) {
        await api.post('/supplier/products', body: draft.toJson());
      } else {
        await api.patch('/supplier/products/${product.id}', body: draft.toJson());
      }
      ref.invalidate(productsProvider);
      ref.invalidate(categoriesProvider);
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
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.asData?.value ?? const <SupplierCategory>[];
    final supplierId = ref.watch(sessionProvider).supplier?.id ?? '';
    final ownCategories = categories
        .where((category) => category.supplierId == supplierId)
        .toList();

    return AsyncValueView<List<SupplierProduct>>(
      value: productsAsync,
      onRetry: () => ref.invalidate(productsProvider),
      loadingMessage: 'Loading the product library…',
      builder: (products) {
        final filtered = _filtered(products);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(productsProvider);
            ref.invalidate(categoriesProvider);
            await ref.read(productsProvider.future);
          },
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
                              onChanged: (value) => setState(() => _query = value),
                              decoration: InputDecoration(
                                hintText: 'Search name, SKU or translation',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
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
                            onPressed: () => _openEditor(ownCategories),
                            icon: const Icon(Icons.add_rounded, size: 19),
                            label: const Text('Add product'),
                          ),
                        ],
                      ),
                      if (categories.isNotEmpty) ...[
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
                                  onSelected: (_) =>
                                      setState(() => _categoryId = null),
                                ),
                              ),
                              for (final category in categories)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      '${category.name} (${category.productCount})',
                                    ),
                                    selected: _categoryId == category.id,
                                    onSelected: (_) => setState(
                                      () => _categoryId = category.id,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (filtered.isEmpty)
                        EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: products.isEmpty
                              ? 'No products yet'
                              : 'No matching products',
                          message: products.isEmpty
                              ? 'Add your first product to the shared library shops copy from.'
                              : 'Try a different search or category filter.',
                          action: products.isEmpty
                              ? FilledButton.icon(
                                  onPressed: () => _openEditor(ownCategories),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Add a product'),
                                )
                              : null,
                        )
                      else
                        for (final product in filtered) ...[
                          _ProductCard(
                            product: product,
                            canEdit: product.supplierId == supplierId,
                            onEdit: () => _openEditor(
                              ownCategories,
                              product: product,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
