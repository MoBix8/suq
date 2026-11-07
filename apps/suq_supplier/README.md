# SUQ Supplier

The supplier app provides a supplier-managed product library, bulk listings, delivery settings, and shop-order processing.

Supplier accounts are created by a SUQ administrator. Sign-in uses the same phone and PIN credentials created for that account.

The Android package uses the production SUQ API by default. Override it at build time with `--dart-define=SUQ_API=https://your-api-host` only when targeting another environment.
