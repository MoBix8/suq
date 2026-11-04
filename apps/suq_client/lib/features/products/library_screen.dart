import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _search = TextEditingController();
  final Map<String, LibraryProduct> _picked = {};
  String? _categoryId;
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(LibraryProduct product) {
    setState(() {
      if (_picked.containsKey(product.id)) {
        _picked.remove(product.id);
      } else {
        _picked[product.id] = product;
      }
    });
  }

  Future<void> _download() async {
    if (_picked.isEmpty) {
      showAppSnack(context, 'Choose at least one product first.');
      return;
    }

    setState(() => _busy = true);
    try {
      final inserted = await ref
          .read(productRepositoryProvider)
          .downloadLibrary(_picked.values.toList());

      _picked.clear();
      ref.invalidate(productsProvider);
      ref.invalidate(localLibraryIdsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(reportProvider);

      if (!mounted) return;
      setState(() {});
      showAppSnack(
        context,
        inserted == 0
            ? 'Those products are already in your shop.'
            : 'Added $inserted product${inserted == 1 ? '' : 's'} to your shop.',
      );
    } catch (error) {
      if (mounted) {
        showAppSnack(context, 'Could not download: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(libraryProductsProvider(_categoryId));
    final localIds =
        ref.watch(localLibraryIdsProvider).asData?.value ?? const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('SUQ library'),
        actions: [
          TextButton.icon(
            onPressed: _busy || _picked.isEmpty ? null : _download,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 19),
            label: Text(
              _picked.isEmpty ? 'Download' : 'Download (${_picked.length})',
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search the SUQ product library…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            _CategoryStrip(
              selected: _categoryId,
              onSelected: (id) => setState(() => _categoryId = id),
            ),
            const Divider(height: 1),
            Expanded(
              child: AsyncValueView<List<LibraryProduct>>(
                value: productsAsync,
                loadingMessage: 'Loading the library…',
                onRetry: () => ref.invalidate(libraryProductsProvider(_categoryId)),
                builder: (items) {
                  final query = _query.trim().toLowerCase();
                  final filtered = items.where((item) {
                    if (query.isEmpty) return true;
                    return item.name.toLowerCase().contains(query) ||
                        item.sku.toLowerCase().contains(query) ||
                        (item.barcode ?? '').toLowerCase().contains(query);
                  }).toList();

                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No products in this category',
                      message: 'Try another category or check back later.',
                    );
                  }
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No products match this search.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                    itemCount: filtered.length + 1,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Text(
                                '${filtered.length} product${filtered.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              if (_picked.isNotEmpty)
                                TextButton(
                                  onPressed: () => setState(_picked.clear),
                                  child: const Text('Clear selection'),
                                ),
                            ],
                          ),
                        );
                      }

                      final item = filtered[index - 1];
                      final inLibrary = localIds.contains(item.id);
                      final selected = _picked.containsKey(item.id);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        onTap: inLibrary ? null : () => _toggle(item),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.seed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.seed,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${item.categoryName} • ${money(item.defaultSellingPrice)} / ${item.unit}'
                          '${item.defaultBuyingPrice == null ? '' : ' • cost ${money(item.defaultBuyingPrice!)}'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                        trailing: inLibrary
                            ? const StatusChip(
                                label: 'In shop',
                                color: AppColors.profit,
                                icon: Icons.check_rounded,
                              )
                            : Checkbox(
                                value: selected,
                                onChanged: (_) => _toggle(item),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryStrip extends ConsumerWidget {
  const _CategoryStrip({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(libraryCategoriesProvider);

    return SizedBox(
      height: 56,
      child: categories.when(
        data: (items) => ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('All'),
                selected: selected == null,
                onSelected: (_) => onSelected(null),
              ),
            ),
            ...items.map(
              (category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${category.name} (${category.productCount})'),
                  selected: selected == category.id,
                  onSelected: (_) => onSelected(category.id),
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, stack) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(libraryCategoriesProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reload categories'),
          ),
        ),
      ),
    );
  }
}
