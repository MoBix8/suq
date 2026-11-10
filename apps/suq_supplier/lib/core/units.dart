/// How a wholesale listing is sold. These are deliberately separate from the
/// retail units used by the catalog library.
const listingSaleUnits = <String>[
  'piece',
  'dozen',
  'pack',
  'sack',
  'crate',
  'bulk',
];

String saleUnitLabel(String unit) => switch (unit) {
      'piece' => 'piece',
      'dozen' => 'dozen',
      'pack' => 'pack',
      'sack' => 'sack',
      'crate' => 'crate',
      'bulk' => 'bulk lot',
      _ => unit,
    };

/// A dozen is always 12 pieces and a single piece is always 1. Other wholesale
/// units let the supplier state how many pieces they contain.
int defaultPiecesForSaleUnit(String unit) => switch (unit) {
      'dozen' => 12,
      _ => 1,
    };

const weightUnits = <String>['kg', 'g'];

/// Convert a weight entry in [unit] to kilograms, the unit the server stores.
double weightToKg(double value, String unit) =>
    unit == 'g' ? value / 1000 : value;

/// Units used by the supplier catalog. Kept as a dropdown so retail units
/// stay consistent between the supplier catalog and shop shelves.
const productUnits = <String>[
  'pcs',
  'pack',
  'dozen',
  'kg',
  'g',
  'litre',
  'ml',
  'bottle',
  'can',
  'bag',
  'box',
  'tray',
  'tube',
  'jar',
  'roll',
  'pair',
  'set',
  'carton',
  'sachet',
];
