import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/export_import.dart';

class PackagesTab extends ConsumerWidget {
  const PackagesTab({super.key});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    PackagePlan? package,
  }) async {
    final draft = await showDialog<_PackageDraft>(
      context: context,
      builder: (context) => _PackageDialog(package: package),
    );
    if (draft == null) return;

    try {
      final api = ref.read(apiProvider);
      if (package == null) {
        await api.post('/admin/packages', body: draft.toJson());
      } else {
        await api.patch('/admin/packages/${package.id}', body: draft.toJson());
      }
      ref.invalidate(packagesProvider);
      if (context.mounted) {
        showAppSnack(context, package == null ? 'Package created.' : 'Package updated.');
      }
    } on ApiException catch (error) {
      if (context.mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    PackagePlan package,
  ) async {
    final deactivating = package.active;
    if (deactivating) {
      final confirmed = await confirmAction(
        context,
        title: 'Deactivate ${package.name}?',
        message:
            'Shops will no longer see this package when choosing a plan. '
            'Existing subscriptions keep their current term.',
        confirmLabel: 'Deactivate',
        destructive: true,
      );
      if (!confirmed) return;
    }

    try {
      final api = ref.read(apiProvider);
      if (deactivating) {
        await api.delete('/admin/packages/${package.id}');
      } else {
        await api.patch('/admin/packages/${package.id}', body: {'active': true});
      }
      ref.invalidate(packagesProvider);
      if (context.mounted) {
        showAppSnack(context, deactivating ? 'Package deactivated.' : 'Package reactivated.');
      }
    } on ApiException catch (error) {
      if (context.mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(packagesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Subscription packages offered to shops.',
                style: TextStyle(fontSize: 12.5, color: AdminColors.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openEditor(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('New package'),
                  ),
                  ExportImportButtons(
                    exportPath: '/admin/export/packages',
                    importPath: '/admin/import/packages',
                    onImported: () => ref.invalidate(packagesProvider),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<List<PackagePlan>>(
            value: packages,
            onRetry: () => ref.invalidate(packagesProvider),
            loadingMessage: 'Loading packages…',
            builder: (records) {
              if (records.isEmpty) {
                return const EmptyState(
                  icon: Icons.sell_rounded,
                  title: 'No packages',
                  message: 'Create at least one package so shops can choose a plan.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: records.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final package = records[index];
                  return SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          package.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AdminColors.ink,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusChip(
                                        label: package.active ? 'ACTIVE' : 'INACTIVE',
                                        color: package.active
                                            ? AdminColors.success
                                            : AdminColors.muted,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${package.months} month${package.months == 1 ? '' : 's'} · '
                                    'sort ${package.sortOrder}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AdminColors.muted,
                                    ),
                                  ),
                                  if ((package.description ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      package.description!,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AdminColors.muted,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money(package.priceEtb),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AdminColors.seed,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${package.paymentCount} payment${package.paymentCount == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AdminColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '${package.subscriptionCount} subscription${package.subscriptionCount == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AdminColors.muted,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _toggleActive(context, ref, package),
                              style: TextButton.styleFrom(
                                foregroundColor: package.active
                                    ? AdminColors.danger
                                    : AdminColors.success,
                              ),
                              icon: Icon(
                                package.active
                                    ? Icons.pause_circle_outline_rounded
                                    : Icons.play_circle_outline_rounded,
                                size: 18,
                              ),
                              label: Text(package.active ? 'Deactivate' : 'Reactivate'),
                            ),
                            const SizedBox(width: 4),
                            OutlinedButton.icon(
                              onPressed: () => _openEditor(context, ref, package: package),
                              icon: const Icon(Icons.edit_outlined, size: 17),
                              label: const Text('Edit'),
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

class _PackageDraft {
  const _PackageDraft({
    required this.name,
    required this.months,
    required this.priceEtb,
    required this.description,
    required this.sortOrder,
    required this.active,
  });

  final String name;
  final int months;
  final double priceEtb;
  final String? description;
  final int sortOrder;
  final bool active;

  Map<String, dynamic> toJson() => {
        'name': name,
        'months': months,
        'priceEtb': priceEtb,
        'description': description,
        'sortOrder': sortOrder,
        'active': active,
      };
}

class _PackageDialog extends StatefulWidget {
  const _PackageDialog({this.package});

  final PackagePlan? package;

  @override
  State<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<_PackageDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _months;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final TextEditingController _sortOrder;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final package = widget.package;
    _name = TextEditingController(text: package?.name ?? '');
    _months = TextEditingController(text: '${package?.months ?? 1}');
    _price = TextEditingController(
      text: package == null ? '' : package.priceEtb.toStringAsFixed(2),
    );
    _description = TextEditingController(text: package?.description ?? '');
    _sortOrder = TextEditingController(text: '${package?.sortOrder ?? 0}');
    _active = package?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _months.dispose();
    _price.dispose();
    _description.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final description = _description.text.trim();
    Navigator.of(context).pop(
      _PackageDraft(
        name: _name.text.trim(),
        months: int.parse(_months.text.trim()),
        priceEtb: double.parse(_price.text.trim()),
        description: description.isEmpty ? null : description,
        sortOrder: int.parse(_sortOrder.text.trim()),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.package == null ? 'New package' : 'Edit package'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Package name'),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'Enter at least 2 characters.'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _months,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Months'),
                        validator: (value) {
                          final months = int.tryParse((value ?? '').trim());
                          if (months == null || months < 1 || months > 36) {
                            return '1–36';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Price (ETB)',
                          prefixText: 'Br ',
                        ),
                        validator: (value) {
                          final price = double.tryParse((value ?? '').trim());
                          if (price == null || price <= 0) {
                            return 'Enter a price greater than zero.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 4),
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
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text('Inactive packages are hidden from shops.'),
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
          child: Text(widget.package == null ? 'Create package' : 'Save changes'),
        ),
      ],
    );
  }
}
