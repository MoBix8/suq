import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models.dart';

class ListingDraft {
  const ListingDraft({
    required this.name,
    required this.category,
    required this.description,
    required this.saleUnit,
    required this.piecesPerUnit,
    required this.pricePerUnit,
    required this.minOrderQty,
    required this.weightPerUnitKg,
    required this.lengthCm,
    required this.widthCm,
    required this.heightCm,
    required this.active,
  });

  final String name;
  final String? category;
  final String? description;
  final String saleUnit;
  final int piecesPerUnit;
  final double pricePerUnit;
  final int minOrderQty;
  final double weightPerUnitKg;
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final bool active;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'description': description,
        'saleUnit': saleUnit,
        'piecesPerUnit': piecesPerUnit,
        'pricePerUnit': pricePerUnit,
        'minOrderQty': minOrderQty,
        'weightPerUnitKg': weightPerUnitKg,
        'lengthCm': lengthCm,
        'widthCm': widthCm,
        'heightCm': heightCm,
        'active': active,
      };
}

class ListingDialog extends StatefulWidget {
  const ListingDialog({super.key, this.listing});

  final SupplierListing? listing;

  @override
  State<ListingDialog> createState() => _ListingDialogState();
}

class _ListingDialogState extends State<ListingDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _minOrder;
  late final TextEditingController _pieces;
  late final TextEditingController _weight;
  late final TextEditingController _length;
  late final TextEditingController _width;
  late final TextEditingController _height;
  late String _saleUnit;
  late String _weightUnit;
  late bool _active;

  bool get _editing => widget.listing != null;
  bool get _piecesLocked => _saleUnit == 'piece' || _saleUnit == 'dozen';

  @override
  void initState() {
    super.initState();
    final listing = widget.listing;
    _saleUnit = listing?.saleUnit ?? 'piece';
    _weightUnit = 'kg';
    _name = TextEditingController(text: listing?.name ?? '');
    _category = TextEditingController(text: listing?.category ?? '');
    _description = TextEditingController(text: listing?.description ?? '');
    _price = TextEditingController(
      text: listing == null ? '' : _numberText(listing.pricePerUnit),
    );
    _minOrder = TextEditingController(
      text: listing == null ? '1' : listing.minOrderQty.toString(),
    );
    final pieces = listing?.piecesPerUnit ?? 0;
    _pieces = TextEditingController(
      text: (pieces > 0 ? pieces : defaultPiecesForSaleUnit(_saleUnit))
          .toString(),
    );
    _weight = TextEditingController(
      text: listing == null ? '' : _numberText(listing.weightPerUnitKg),
    );
    _length = TextEditingController(
      text: listing == null ? '' : _numberText(listing.lengthCm),
    );
    _width = TextEditingController(
      text: listing == null ? '' : _numberText(listing.widthCm),
    );
    _height = TextEditingController(
      text: listing == null ? '' : _numberText(listing.heightCm),
    );
    _active = listing?.active ?? true;
  }

  String _numberText(double value) =>
      value == value.roundToDouble() ? value.round().toString() : value.toString();

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _description.dispose();
    _price.dispose();
    _minOrder.dispose();
    _pieces.dispose();
    _weight.dispose();
    _length.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  double _valueOf(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  double get _volumeCubicM =>
      _valueOf(_length) * _valueOf(_width) * _valueOf(_height) / 1000000;

  double get _weightKg => weightToKg(_valueOf(_weight), _weightUnit);

  int get _piecesValue {
    final parsed = int.tryParse(_pieces.text.trim());
    if (parsed != null && parsed > 0) return parsed;
    return defaultPiecesForSaleUnit(_saleUnit);
  }

  String? _validatePositive(String? value, String label) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) return 'Enter $label';
    return null;
  }

  String? _validateMinOrder(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 1) return 'At least 1';
    if (parsed > 10000) return 'Maximum 10,000';
    return null;
  }

  String? _validatePieces(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 1) return 'Enter a whole number';
    if (parsed > 100000) return 'Too many pieces';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final category = _category.text.trim();
    final description = _description.text.trim();
    Navigator.of(context).pop(
      ListingDraft(
        name: _name.text.trim(),
        category: category.isEmpty ? null : category,
        description: description.isEmpty ? null : description,
        saleUnit: _saleUnit,
        piecesPerUnit: _piecesLocked
            ? defaultPiecesForSaleUnit(_saleUnit)
            : _piecesValue,
        pricePerUnit: double.parse(_price.text.trim()),
        minOrderQty: int.parse(_minOrder.text.trim()),
        weightPerUnitKg: _weightKg,
        lengthCm: double.parse(_length.text.trim()),
        widthCm: double.parse(_width.text.trim()),
        heightCm: double.parse(_height.text.trim()),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final maxWidth = media.width < 720 ? media.width - 32 : 680.0;
    final maxHeight = media.height * 0.9;
    final unitLabel = saleUnitLabel(_saleUnit);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                child: Form(
                  key: _formKey,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 480;
                      return _buildForm(wide, unitLabel);
                    },
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 12, 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SupplierColors.seed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.sell_outlined,
              color: SupplierColors.seed,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editing
                      ? 'Edit wholesale listing'
                      : 'Publish a wholesale listing',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SupplierColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Shops order this directly. It is separate from your retail catalog.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: SupplierColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _submit,
            child: Text(_editing ? 'Save listing' : 'Publish listing'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(bool wide, String unitLabel) {
    final pieces = _piecesValue;
    final price = _valueOf(_price);
    final weight = _weightKg;
    final volume = _volumeCubicM;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(icon: Icons.sell_outlined, title: 'The offer'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Listing name',
            hintText: 'e.g. Teff flour — 25 kg sack',
            prefixIcon: Icon(Icons.sell_outlined),
          ),
          validator: (value) {
            final name = value?.trim() ?? '';
            if (name.length < 2) return 'Give this listing a name';
            if (name.length > 120) return 'Use 120 characters or fewer';
            return null;
          },
        ),
        const SizedBox(height: 12),
        _pair(
          TextFormField(
            controller: _category,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Category (optional)',
              hintText: 'e.g. Grains',
              prefixIcon: Icon(Icons.category_outlined),
            ),
          ),
          TextFormField(
            controller: _description,
            maxLines: 2,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Short note (optional)',
              hintText: 'Grade, origin, packaging…',
            ),
          ),
          wide,
        ),
        const SizedBox(height: 24),
        const _SectionTitle(
          icon: Icons.payments_outlined,
          title: 'Price & pack size',
          subtitle:
              'State exactly what one sale unit contains so shops know what they are ordering.',
        ),
        const SizedBox(height: 12),
        _pair(
          DropdownButtonFormField<String>(
            value: _saleUnit,
            decoration: const InputDecoration(
              labelText: 'Sold by',
              prefixIcon: Icon(Icons.straighten_outlined),
            ),
            items: [
              for (final unit in listingSaleUnits)
                DropdownMenuItem(
                  value: unit,
                  child: Text(saleUnitLabel(unit)),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                final wasLocked = _piecesLocked;
                _saleUnit = value;
                if (_piecesLocked || wasLocked) {
                  _pieces.text = defaultPiecesForSaleUnit(value).toString();
                }
              });
            },
          ),
          TextFormField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Price per $unitLabel (Br)',
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
            validator: (value) => _validatePositive(value, 'a price'),
          ),
          wide,
        ),
        const SizedBox(height: 12),
        _pair(
          TextFormField(
            controller: _minOrder,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Minimum order',
              helperText: 'Sale units',
              prefixIcon: const Icon(Icons.shopping_basket_outlined),
            ),
            validator: _validateMinOrder,
          ),
          _buildPiecesField(unitLabel),
          wide,
        ),
        if (!_piecesLocked) ...[
          const SizedBox(height: 6),
          Text(
            'A pack can hold 6, 12, or any other number of pieces. Use 1 if the $unitLabel is a single item.',
            style: const TextStyle(
              fontSize: 11.5,
              color: SupplierColors.muted,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 24),
        const _SectionTitle(
          icon: Icons.local_shipping_outlined,
          title: 'Delivery measurements',
          subtitle:
              'Measured for one sale unit. Shops pay delivery from the total weight and space the order takes.',
        ),
        const SizedBox(height: 12),
        _buildWeightField(unitLabel),
        const SizedBox(height: 12),
        _buildDimensionFields(wide),
        const SizedBox(height: 12),
        _buildPreview(unitLabel, pieces, price, weight, volume),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _active,
          onChanged: (value) => setState(() => _active = value),
          title: const Text(
            'Visible to shops',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Hidden listings stay in your records but cannot be ordered.',
            style: TextStyle(fontSize: 11.5, color: SupplierColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _buildPiecesField(String unitLabel) {
    return TextFormField(
      controller: _pieces,
      enabled: !_piecesLocked,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: _piecesLocked
            ? 'Pieces per sale unit'
            : 'Pieces per $unitLabel',
        helperText: _piecesLocked
            ? (_saleUnit == 'dozen'
                ? 'A dozen always has 12 pieces'
                : 'A single piece')
            : 'e.g. 6 or 12',
        prefixIcon: const Icon(Icons.widgets_outlined),
      ),
      validator: _piecesLocked ? null : _validatePieces,
    );
  }

  Widget _buildWeightField(String unitLabel) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Weight per $unitLabel',
              prefixIcon: const Icon(Icons.scale_outlined),
            ),
            onChanged: (_) => setState(() {}),
            validator: (value) => _validatePositive(value, 'a weight'),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 108,
          child: DropdownButtonFormField<String>(
            value: _weightUnit,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: [
              for (final unit in weightUnits)
                DropdownMenuItem(value: unit, child: Text(unit)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _weightUnit = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDimensionFields(bool wide) {
    final fields = <Widget>[
      _dimensionField(_length, 'Length (cm)', 'a length'),
      _dimensionField(_width, 'Width (cm)', 'a width'),
      _dimensionField(_height, 'Height (cm)', 'a height'),
    ];

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: fields[i]),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          fields[i],
        ],
      ],
    );
  }

  Widget _dimensionField(
    TextEditingController controller,
    String label,
    String validationLabel,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
      validator: (value) => _validatePositive(value, validationLabel),
    );
  }

  Widget _buildPreview(
    String unitLabel,
    int pieces,
    double price,
    double weight,
    double volume,
  ) {
    final piecesText = pieces > 1 ? '$pieces pieces' : '1 piece';
    final weightText = _weightUnit == 'g'
        ? '${qty(_valueOf(_weight))} g (${weightLabel(weight)})'
        : weightLabel(weight);
    final perPiece = price > 0 && pieces > 1
        ? ' · ${money(price / pieces)} / piece'
        : '';
    final summary = [
      'One $unitLabel',
      piecesText,
      weightText,
      if (volume > 0) volumeLabel(volume) else 'enter dimensions for volume',
      '${money(price)}$perPiece',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SupplierColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SupplierColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.view_in_ar_outlined,
            size: 18,
            color: SupplierColors.seed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary,
              style: const TextStyle(
                fontSize: 11.5,
                color: SupplierColors.ink,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pair(Widget first, Widget second, bool wide) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, const SizedBox(height: 12), second],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: SupplierColors.seed),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: SupplierColors.ink,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 11.5,
              color: SupplierColors.muted,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
