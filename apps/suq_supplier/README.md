# SUQ Supplier

Supplier console for the SUQ marketplace.

Suppliers use this app to:

- browse and maintain the same retail catalog library shops see in the client
  app; suppliers can add products and categories, while SUQ and other suppliers'
  entries stay read-only,
- publish independent wholesale listings sold by piece, dozen, pack, sack,
  crate, or bulk lot, with a supplier-set price, minimum order, and the number
  of pieces inside each sale unit (for example 6 or 12 in a pack),
- record each listing's weight (entered in kg or g) and length × width × height
  so delivery can be priced from the space and weight an order takes,
- receive shop orders, quote delivery, and update order status,
- keep their delivery rates up to date.

Listings are not linked to catalog products. Delivery is suggested from:

```text
base fee
+ distance (km) × rate per km
+ order weight (kg) × rate per kg
+ order volume (m³) × rate per m³
```

The supplier can override the suggested fee on any order.

Run with:

```bash
# Windows desktop
flutter run -d windows --dart-define=SUQ_API=https://suq-silk.vercel.app

# Android device or emulator
flutter run -d <device-id> --dart-define=SUQ_API=https://suq-silk.vercel.app
```
