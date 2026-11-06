import 'dart:async';

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
  Timer? _searchDebounce;
  String? _categoryId;
  String _searchText = '';
  String _query = '';
  bool _busy = false;
  bool _selectingAll = false;
  bool _loadingMore = false;

  LibraryFeedQuery get _feedQuery =>
      LibraryFeedQuery(categoryId: _categoryId, search: _query);

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
      setState(() => _query = value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _search.clear();
    setState(() {
      _searchText = '';
      _query = '';
    });
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

  void _setAll(List<LibraryProduct> items, {required bool selected}) {
    setState(() {
      for (final item in items) {
        if (selected) {
          _picked[item.id] = item;
        } else {
          _picked.remove(item.id);
        }
      }
    });
  }

  Future<void> _selectAllMatching(
    LibraryFeedState feed,
    Set<String> localIds,
    bool allLoadedSelected,
  ) async {
    if (allLoadedSelected) {
      _setAll(
        feed.items.where((item) => !localIds.contains(item.id)).toList(),
        selected: false,
      );
      return;
    }
    if (_selectingAll) return;

    setState(() => _selectingAll = true);
    try {
      final all = await ref.read(libraryFeedProvider(_feedQuery).notifier).allMatching();
      if (!mounted) return;
      setState(() {
        for (final item in all) {
          if (!localIds.contains(item.id)) _picked[item.id] = item;
        }
      });
    } catch (error) {
      if (mounted) {
        showAppSnack(context, 'Could not load all products: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _selectingAll = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      await ref.read(libraryFeedProvider(_feedQuery).notifier).loadMore();
    } catch (error) {
      if (mounted) {
        showAppSnack(context, 'Could not load more: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
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
    final feedAsync = ref.watch(libraryFeedProvider(_feedQuery));
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
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search the SUQ product library…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchText.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clearSearch,
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
              child: AsyncValueView<LibraryFeedState>(
                value: feedAsync,
                loadingMessage: 'Loading the library…',
                onRetry: () => ref.invalidate(libraryFeedProvider(_feedQuery)),
                builder: (feed) {
                  if (feed.total == 0) {
                    if (_query.trim().isNotEmpty) {
                      return const Center(
                        child: Text(
                          'No products match this search.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      );
                    }
                    return const EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No products in this category',
                      message: 'Try another category or check back later.',
                    );
                  }

                  final items = feed.items;
                  final selectable =
                      items.where((item) => !localIds.contains(item.id)).toList();
                  final allLoadedSelected = selectable.isNotEmpty &&
                      selectable.every((item) => _picked.containsKey(item.id));
                  final countLabel = items.length >= feed.total
                      ? '${feed.total} product${feed.total == 1 ? '' : 's'}'
                      : '${items.length} of ${feed.total} products';

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                    itemCount: items.length + 2,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$countLabel'
                                  '${_picked.isEmpty ? '' : ' • ${_picked.length} selected'}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (_picked.isNotEmpty)
                                IconButton(
                                  onPressed: () => setState(_picked.clear),
                                  icon: const Icon(Icons.clear_all_rounded, size: 20),
                                  tooltip: 'Clear selection',
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (selectable.isNotEmpty || _picked.isNotEmpty)
                                TextButton.icon(
                                  onPressed: _selectingAll
                                      ? null
                                      : () => _selectAllMatching(
                                            feed,
                                            localIds,
                                            allLoadedSelected,
                                          ),
                                  icon: _selectingAll
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          allLoadedSelected
                                              ? Icons.deselect_rounded
                                              : Icons.select_all_rounded,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _selectingAll
                                        ? 'Selecting…'
                                        : allLoadedSelected
                                            ? 'Deselect all'
                                            : 'Select all',
                                  ),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }

                      if (index == items.length + 1) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: feed.hasMore
                                ? OutlinedButton.icon(
                                    onPressed: _loadingMore ? null : _loadMore,
                                    icon: _loadingMore
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.expand_more_rounded,
                                            size: 19,
                                          ),
                                    label: Text(
                                      _loadingMore
                                          ? 'Loading…'
                                          : 'Load more products',
                                    ),
                                  )
                                : Text(
                                    'All ${feed.total} products loaded',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        );
                      }

                      final item = items[index - 1];
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
                          _libraryProductDisplayName(item),
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

String _libraryProductDisplayName(LibraryProduct item) {
  final parts = <String>[item.name];
  if (item.nameAm != null && item.nameAm!.trim().isNotEmpty) {
    parts.add(item.nameAm!.trim());
  }
  if (item.nameOr != null && item.nameOr!.trim().isNotEmpty) {
    parts.add(item.nameOr!.trim());
  }
  return parts.join(' / ');
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
