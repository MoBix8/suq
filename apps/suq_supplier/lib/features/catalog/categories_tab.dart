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
      ref.invalidate(categoriesProvider);
      ref.invalidate(productsProvider);
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
      ref.invalidate(categoriesProvider);
      if (mounted) showAppSnack(context, 'Category deleted.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final supplierId = ref.watch(sessionProvider).supplier?.id ?? '';

    return AsyncValueView<List<SupplierCategory>>(
      value: categoriesAsync,
      onRetry: () => ref.invalidate(categoriesProvider),
      loadingMessage: 'Loading categories…',
      builder: (categories) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          await ref.read(categoriesProvider.future);
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
                    PageHeader(
                      title: 'Categories',
                      subtitle:
                          '${categories.length} categor${categories.length == 1 ? 'y' : 'ies'} in the shared product library.',
                      action: FilledButton.icon(
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                        label: const Text('New category'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (categories.isEmpty)
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
                    else
                      for (final category in categories) ...[
                        _CategoryCard(
                          category: category,
                          owned: category.supplierId == supplierId,
                          onEdit: () => _openEditor(category: category),
                          onDelete: () => _delete(category),
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
