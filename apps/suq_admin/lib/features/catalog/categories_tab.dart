import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class CategoriesTab extends ConsumerWidget {
  const CategoriesTab({super.key});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    LibraryCategory? category,
  }) async {
    final draft = await showDialog<_CategoryDraft>(
      context: context,
      builder: (context) => _CategoryDialog(category: category),
    );
    if (draft == null) return;

    try {
      final api = ref.read(apiProvider);
      if (category == null) {
        await api.post('/admin/library/categories', body: draft.toJson());
      } else {
        await api.patch('/admin/library/categories/${category.id}', body: draft.toJson());
      }
      ref.invalidate(categoriesProvider);
      ref.invalidate(libraryProductsProvider);
      if (context.mounted) {
        showAppSnack(context, category == null ? 'Category created.' : 'Category updated.');
      }
    } on ApiException catch (error) {
      if (context.mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    LibraryCategory category,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${category.name}?',
      message:
          'This permanently removes the category. It only works when the category has no products.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(apiProvider).delete('/admin/library/categories/${category.id}');
      ref.invalidate(categoriesProvider);
      if (context.mounted) showAppSnack(context, 'Category deleted.');
    } on ApiException catch (error) {
      if (context.mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Groups used to organise the shared product library.',
                  style: TextStyle(fontSize: 12.5, color: AdminColors.muted),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openEditor(context, ref),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('New category'),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<List<LibraryCategory>>(
            value: categories,
            onRetry: () => ref.invalidate(categoriesProvider),
            loadingMessage: 'Loading categories…',
            builder: (records) {
              if (records.isEmpty) {
                return const EmptyState(
                  icon: Icons.category_rounded,
                  title: 'No categories',
                  message: 'Create a category before adding library products.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: records.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final category = records[index];
                  return SectionCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AdminColors.seed.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.category_rounded,
                            size: 18,
                            color: AdminColors.seed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${category.productCount} product${category.productCount == 1 ? '' : 's'} · '
                                'sort ${category.sortOrder}'
                                '${(category.slug ?? '').isEmpty ? '' : ' · ${category.slug}'}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AdminColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _openEditor(context, ref, category: category),
                          icon: const Icon(Icons.edit_outlined, size: 19),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(context, ref, category),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: AdminColors.danger,
                          ),
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

class _CategoryDraft {
  const _CategoryDraft({
    required this.name,
    required this.slug,
    required this.sortOrder,
  });

  final String name;
  final String? slug;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (slug != null) 'slug': slug,
        'sortOrder': sortOrder,
      };
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category});

  final LibraryCategory? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _sortOrder;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _slug = TextEditingController(text: widget.category?.slug ?? '');
    _sortOrder = TextEditingController(text: '${widget.category?.sortOrder ?? 0}');
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final slug = _slug.text.trim();
    Navigator.of(context).pop(
      _CategoryDraft(
        name: _name.text.trim(),
        slug: slug.isEmpty ? null : slug,
        sortOrder: int.parse(_sortOrder.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'New category' : 'Edit category'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Category name'),
                validator: (value) => (value ?? '').trim().length < 2
                    ? 'Enter at least 2 characters.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _slug,
                decoration: const InputDecoration(
                  labelText: 'Slug (optional)',
                  helperText: 'Leave blank to generate one automatically.',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sortOrder,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Sort order',
                  helperText: 'Lower numbers appear first.',
                ),
                validator: (value) => int.tryParse((value ?? '').trim()) == null
                    ? 'Enter a whole number.'
                    : null,
              ),
            ],
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
          child: Text(widget.category == null ? 'Create category' : 'Save changes'),
        ),
      ],
    );
  }
}
