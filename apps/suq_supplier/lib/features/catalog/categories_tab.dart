import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class CategoriesTab extends ConsumerStatefulWidget {
  const CategoriesTab({super.key});

  @override
  ConsumerState<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends ConsumerState<CategoriesTab> {
  static const _pageSize = 10;

  List<SupplierCategory> _categories = const [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      if (_categories.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiProvider).get(
            '/supplier/categories',
            query: {'page': '$_page', 'pageSize': '$_pageSize'},
          );
      if (!mounted) return;
      final categories = (response['categories'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => SupplierCategory.fromJson(asMap(row)))
          .toList();
      setState(() {
        _categories = categories;
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

  Future<void> _openEditor({SupplierCategory? category}) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryDialog(category: category),
    );
    if (name == null) return;

    try {
      final api = ref.read(apiProvider);
      if (category == null) {
        await api.post('/supplier/categories', body: {'name': name});
      } else {
        await api.patch(
          '/supplier/categories/${category.id}',
          body: {'name': name},
        );
      }
      ref.invalidate(summaryProvider);
      if (!mounted) return;
      setState(() => _page = 1);
      await _load();
      if (mounted) {
        showAppSnack(
          context,
          category == null ? 'Category created.' : 'Category updated.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  Future<void> _delete(SupplierCategory category) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${category.name}?',
      message: category.productCount > 0
          ? 'This category still has ${category.productCount} product(s). Move or remove them first.'
          : 'This category will be removed from the shared library.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(apiProvider).delete('/supplier/categories/${category.id}');
      ref.invalidate(summaryProvider);
      if (!mounted) return;
      if (_categories.length == 1 && _page > 1) _page -= 1;
      await _load();
      if (mounted) showAppSnack(context, 'Category deleted.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplierId = ref.watch(sessionProvider).supplier?.id ?? '';

    return RefreshIndicator(
      onRefresh: _load,
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
                  PageHeader(
                    title: 'Categories',
                    subtitle:
                        '$_total categor${_total == 1 ? 'y' : 'ies'} in the shared product library.',
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                      label: const Text('New category'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: SupplierColors.danger),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_loading && _categories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_categories.isEmpty)
                    EmptyState(
                      icon: Icons.category_outlined,
                      title: 'No categories yet',
                      message:
                          'Create categories to keep your products organised.',
                      action: FilledButton.icon(
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Create a category'),
                      ),
                    )
                  else ...[
                    for (final category in _categories) ...[
                      _CategoryCard(
                        category: category,
                        owned: category.supplierId == supplierId,
                        onEdit: () => _openEditor(category: category),
                        onDelete: () => _delete(category),
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
                  _load();
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
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.owned,
    required this.onEdit,
    required this.onDelete,
  });

  final SupplierCategory category;
  final bool owned;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SupplierColors.seed.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.category_outlined,
              size: 19,
              color: SupplierColors.seed,
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
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: SupplierColors.ink,
                      ),
                    ),
                    StatusChip(
                      label: category.supplierId.isEmpty
                          ? 'SUQ library'
                          : owned
                              ? 'Your category'
                              : 'Shared library',
                      color: owned
                          ? SupplierColors.seed
                          : SupplierColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${category.productCount} active product${category.productCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: SupplierColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (owned) ...[
            IconButton(
              tooltip: 'Edit category',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 19),
            ),
            IconButton(
              tooltip: 'Delete category',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: SupplierColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category});

  final SupplierCategory? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.category?.name ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.category != null;
    return AlertDialog(
      title: Text(editing ? 'Edit category' : 'New category'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Category name',
              hintText: 'e.g. Beverages',
            ),
            validator: (value) =>
                (value?.trim().length ?? 0) < 2 ? 'Enter a category name' : null,
            onFieldSubmitted: (_) => _submit(),
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
          child: Text(editing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_name.text.trim());
  }
}
