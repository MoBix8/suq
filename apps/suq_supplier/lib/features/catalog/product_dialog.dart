import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models.dart';

class ProductDraft {
  const ProductDraft({
    required this.categoryId,
    required this.sku,
    required this.name,
    required this.nameAm,
    required this.nameOr,
    required this.barcode,
    required this.unit,
    required this.defaultSellingPrice,
    required this.defaultBuyingPrice,
  });

  final String categoryId;
  final String sku;
  final String name;
  final String nameAm;
  final String nameOr;
  final String barcode;
  final String unit;
  final double defaultSellingPrice;
  final double? defaultBuyingPrice;

  Map<String, dynamic> toJson() => {
        'categoryId': categoryId,
        'sku': sku,
        'name': name,
        'nameAm': nameAm.isEmpty ? null : nameAm,
        'nameOr': nameOr.isEmpty ? null : nameOr,
        'barcode': barcode.isEmpty ? null : barcode,
        'unit': unit,
        'defaultSellingPrice': defaultSellingPrice,
        'defaultBuyingPrice': defaultBuyingPrice,
      };
}

class ProductDialog extends StatefulWidget {
  const ProductDialog({
    super.key,
    required this.categories,
    this.product,
  });

  final List<SupplierCategory> categories;
  final SupplierProduct? product;

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sku;
  late final TextEditingController _name;
  late final TextEditingController _nameAm;
  late final TextEditingController _nameOr;
  late final TextEditingController _barcode;
  late final TextEditingController _selling;
  late final TextEditingController _buying;
  late String _categoryId;
  late String _unit;

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _sku = TextEditingController(text: product?.sku ?? '');
    _name = TextEditingController(text: product?.name ?? '');
    _nameAm = TextEditingController(text: product?.nameAm ?? '');
    _nameOr = TextEditingController(text: product?.nameOr ?? '');
    _barcode = TextEditingController(text: product?.barcode ?? '');
    _selling = TextEditingController(
      text: product == null ? '' : _numberText(product.defaultSellingPrice),
    );
    _buying = TextEditingController(
      text: product?.defaultBuyingPrice == null
          ? ''
          : _numberText(product!.defaultBuyingPrice!),
    );
    _categoryId = product?.categoryId ?? widget.categories.first.id;
    _unit = product?.unit ?? 'pcs';
  }

  String _numberText(double value) =>
      value == value.roundToDouble() ? value.round().toString() : value.toString();

  @override
  void dispose() {
    _sku.dispose();
    _name.dispose();
    _nameAm.dispose();
    _nameOr.dispose();
    _barcode.dispose();
    _selling.dispose();
    _buying.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ProductDraft(
        categoryId: _categoryId,
        sku: _sku.text.trim(),
        name: _name.text.trim(),
        nameAm: _nameAm.text.trim(),
        nameOr: _nameOr.text.trim(),
        barcode: _barcode.text.trim(),
        unit: _unit,
        defaultSellingPrice: double.parse(_selling.text.trim()),
        defaultBuyingPrice: _buying.text.trim().isEmpty
            ? null
            : double.tryParse(_buying.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Edit product' : 'New product'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'This product belongs to your retail catalog library. It is independent of your wholesale listings.',
                  style: TextStyle(
                    color: SupplierColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in widget.categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _categoryId = value);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Product name (English)',
                        ),
                        validator: (value) =>
                            (value?.trim().length ?? 0) < 2
                                ? 'Enter a product name'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sku,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'SKU'),
                        validator: (value) =>
                            (value?.trim().length ?? 0) < 2
                                ? 'Required'
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameAm,
                        decoration: const InputDecoration(
                          labelText: 'Amharic name (optional)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _nameOr,
                        decoration: const InputDecoration(
                          labelText: 'Afaan Oromo name (optional)',
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
                        decoration: const InputDecoration(
                          labelText: 'Retail unit',
                        ),
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
                      child: TextFormField(
                        controller: _selling,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Default selling price (Br)',
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(value?.trim() ?? '');
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid price';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _buying,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Default buying price (optional)',
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          final parsed = double.tryParse(text);
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid price';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
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
          child: Text(_editing ? 'Save changes' : 'Add product'),
        ),
      ],
    );
  }
}
