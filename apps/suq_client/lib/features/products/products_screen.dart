import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import 'library_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _lowStockOnly = false;
  int _page = 1;
  static const _pageSize = 30;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(productsProvider);
    ref.invalidate(localLibraryIdsProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(reportProvider);
  }

  Future<void> _openEditor([Product? product]) async {
    final result = await showDialog<Product>(
      context: context,
      builder: (context) => _ProductEditorDialog(product: product),
    );
    if (result == null || !mounted) return;

    try {
      await ref.read(productRepositoryProvider).save(result);
      _refresh();
      if (mounted) {
        showAppSnack(
          context,
          product == null ? 'Product added to your shop.' : 'Product updated.',
        );
      }
    } catch (error) {
      if (mounted) showAppSnack(context, 'Could not save: $error', error: true);
    }
  }

  Future<void> _delete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove product?'),
        content: Text(
          '“${product.name}” will be hidden from your shop. Past sales are kept. '
          'Library products can be downloaded again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(productRepositoryProvider).softDelete(product.id);
      _refresh();
      if (mounted) showAppSnack(context, '${product.name} removed.');
    } catch (error) {
      if (mounted) showAppSnack(context, 'Could not remove: $error', error: true);
    }
  }

  void _openLibrary() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LibraryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(
      productsProvider(ProductQuery(
        query: _query,
        lowStockOnly: _lowStockOnly,
        page: _page,
        pageSize: _pageSize,
      )),
    );

    return AsyncValueView<List<Product>>(
      value: productsAsync,
      loadingMessage: 'Loading your products…',
      onRetry: () => ref.invalidate(productsProvider),
      builder: (products) {
        final filtered = products;
        final lowStockCount = products.where((product) => product.isLowStock).length;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(productsProvider);
            await ref.read(productsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth > 620;
                                final search = TextField(
                                  controller: _search,
                                  onChanged: (value) => setState(() {
                    _query = value;
                    _page = 1;
                  }),
                                  decoration: InputDecoration(
                                    hintText: 'Search products or barcode…',
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
                                );
                                final actions = Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _openLibrary,
                                      icon: const Icon(Icons.storefront_outlined, size: 19),
                                      label: const Text('SUQ library'),
                                    ),
                                    FilledButton.icon(
                                      onPressed: () => _openEditor(),
                                      icon: const Icon(Icons.add_rounded, size: 20),
                                      label: const Text('Add product'),
                                    ),
                                  ],
                                );
                                if (!wide) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      search,
                                      const SizedBox(height: 10),
                                      actions,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: search),
                                    const SizedBox(width: 12),
                                    actions,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                FilterChip(
                                  label: Text('All (${products.length})'),
                                  selected: !_lowStockOnly,
                                  onSelected: (_) => setState(() {
                                    _lowStockOnly = false;
                                    _page = 1;
                                  }),
                                ),
                                FilterChip(
                                  label: Text('Low stock ($lowStockCount)'),
                                  selected: _lowStockOnly,
                                  onSelected: (_) => setState(() {
                                    _lowStockOnly = true;
                                    _page = 1;
                                  }),
                                  avatar: lowStockCount > 0
                                      ? const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 16,
                                          color: AppColors.warning,
                                        )
                                      : null,
                                ),
                                Text(
                                  '${filtered.length} shown',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (products.isEmpty)
                        EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No products yet',
                          message:
                              'Download the SUQ product library or add your own custom products to start selling.',
                          action: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _openLibrary,
                                icon: const Icon(Icons.storefront_outlined, size: 19),
                                label: const Text('Browse library'),
                              ),
                              FilledButton.icon(
                                onPressed: () => _openEditor(),
                                icon: const Icon(Icons.add_rounded, size: 20),
                                label: const Text('Add product'),
                              ),
                            ],
                          ),
                        )
                      else if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 44),
                          child: Center(
                            child: Text(
                              'No products match this search.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        )
                      else
                        SectionCard(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: filtered
                                .map<Widget>(
                                  (product) => _ProductRow(
                                    product: product,
                                    onEdit: () => _openEditor(product),
                                    onDelete: () => _delete(product),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        if (products.isNotEmpty && filtered.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton(
                                  onPressed: _page > 1
                                      ? () => setState(() => _page -= 1)
                                      : null,
                                  child: const Text('Previous'),
                                ),
                                const SizedBox(width: 12),
                                Text('Page $_page'),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: filtered.length >= _pageSize
                                      ? () => setState(() => _page += 1)
                                      : null,
                                  child: const Text('Next'),
                                ),
                              ],
                            ),
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

String _productDisplayName(Product product) {
  final parts = <String>[product.name];
  if (product.nameAm != null && product.nameAm!.trim().isNotEmpty) {
    parts.add(product.nameAm!.trim());
  }
  if (product.nameOr != null && product.nameOr!.trim().isNotEmpty) {
    parts.add(product.nameOr!.trim());
  }
  return parts.join(' / ');
}
class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final initial = product.name.trim().isEmpty
        ? '?'
        : product.name.trim().substring(0, 1).toUpperCase();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.seed.withValues(alpha: 0.1),
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.seed,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              _productDisplayName(product),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          if (product.custom) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'CUSTOM',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '${money(product.sellingPrice)} / ${product.unit}'
            '${product.barcode == null ? '' : ' • ${product.barcode}'}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 3),
          Wrap(
            spacing: 10,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (product.hasCost)
                Text(
                  'Cost ${money(product.buyingPrice!)} • ${percent(product.margin)} margin',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                )
              else
                const Text(
                  'No buying price — profit will be estimated',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              if (product.trackStock)
                Text(
                  '${qty(product.stockQty)} ${product.unit} in stock',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: product.isLowStock ? AppColors.warning : AppColors.profit,
                  ),
                ),
              if (product.isLowStock)
                const Text(
                  'LOW STOCK',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                    letterSpacing: 0.4,
                  ),
                ),
            ],
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Product actions',
        onSelected: (value) {
          if (value == 'edit') {
            onEdit();
          } else if (value == 'delete') {
            onDelete();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined, size: 19),
              title: Text('Edit'),
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.loss),
              title: Text('Remove', style: TextStyle(color: AppColors.loss)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductEditorDialog extends StatefulWidget {
  const _ProductEditorDialog({this.product});

  final Product? product;

  @override
  State<_ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<_ProductEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _unit;
  late final TextEditingController _selling;
  late final TextEditingController _buying;
  late final TextEditingController _stock;
  late final TextEditingController _threshold;
  late bool _trackStock;
  String? _error;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _barcode = TextEditingController(text: product?.barcode ?? '');
    _unit = TextEditingController(text: product?.unit ?? 'pcs');
    _selling = TextEditingController(
      text: product == null ? '' : product.sellingPrice.toStringAsFixed(2),
    );
    _buying = TextEditingController(
      text: product?.buyingPrice == null
          ? ''
          : product!.buyingPrice!.toStringAsFixed(2),
    );
    _stock = TextEditingController(
      text: product == null ? '0' : qty(product.stockQty),
    );
    _threshold = TextEditingController(
      text: product == null ? '0' : qty(product.lowStockThreshold),
    );
    _trackStock = product?.trackStock ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _unit.dispose();
    _selling.dispose();
    _buying.dispose();
    _stock.dispose();
    _threshold.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a product name.');
      return;
    }

    final selling = double.tryParse(_selling.text.trim());
    if (selling == null || selling < 0) {
      setState(() => _error = 'Enter a valid selling price.');
      return;
    }

    final buyingText = _buying.text.trim();
    final buying = buyingText.isEmpty ? null : double.tryParse(buyingText);
    if (buyingText.isNotEmpty && (buying == null || buying < 0)) {
      setState(() => _error = 'Enter a valid buying price, or leave it empty.');
      return;
    }

    final unit = _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim();
    final barcodeText = _barcode.text.trim();
    final stock = _trackStock
        ? (double.tryParse(_stock.text.trim()) ?? 0)
        : (widget.product?.stockQty ?? 0);
    final threshold =
        _trackStock ? (double.tryParse(_threshold.text.trim()) ?? 0) : 0.0;
    final now = DateTime.now();

    final Product product;
    if (widget.product == null) {
      product = Product(
        id: const Uuid().v4(),
        name: name,
        barcode: barcodeText.isEmpty ? null : barcodeText,
        unit: unit,
        sellingPrice: selling,
        buyingPrice: buying,
        stockQty: stock,
        lowStockThreshold: threshold,
        trackStock: _trackStock,
        custom: true,
        updatedAt: now,
      );
    } else {
      product = widget.product!.copyWith(
        name: name,
        barcode: barcodeText.isEmpty ? null : barcodeText,
        clearBarcode: barcodeText.isEmpty,
        unit: unit,
        sellingPrice: selling,
        buyingPrice: buying,
        clearBuyingPrice: buying == null,
        stockQty: stock,
        lowStockThreshold: threshold,
        trackStock: _trackStock,
        updatedAt: now,
      );
    }

    Navigator.of(context).pop(product);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'New product' : 'Edit product'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Product name',
                  hintText: 'e.g. Sugar 1kg',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _barcode,
                decoration: const InputDecoration(
                  labelText: 'Barcode (optional)',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _selling,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Selling price',
                        prefixText: 'Br ',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _buying,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Buying price (optional)',
                  prefixText: 'Br ',
                  helperText: 'Used to calculate profit. Leave empty if unknown.',
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Track stock',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Stock goes down automatically when you sell.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                value: _trackStock,
                onChanged: (value) => setState(() => _trackStock = value),
              ),
              if (_trackStock) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stock,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(labelText: 'In stock'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _threshold,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Low-stock alert at',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.loss, fontSize: 12.5),
                ),
              ],
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
          onPressed: _save,
          child: Text(widget.product == null ? 'Add product' : 'Save changes'),
        ),
      ],
    );
  }
}
