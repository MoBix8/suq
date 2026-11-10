# SUQ — API contract

Base URL: `http://localhost:4000/api`

All responses are JSON. Errors: `{ "error": "message", "details": ... }`.

Auth header: `Authorization: Bearer <jwt>`.

## Auth

### `POST /auth/register`

```json
{
  "phone": "0911223344",
  "pin": "1234",
  "name": "Abebe Kebede",
  "shopName": "Abebe Mini Market",
  "city": "Addis Ababa",
  "subcity": "Bole",
  "deviceId": "stable-device-uuid"
}
```

Returns `{ token, user, shop, subscription }`. The shop starts with no active
subscription; the client shows the activation gate. `deviceId` binds the owner
account to this device.

### `POST /auth/login`

```json
{
  "phone": "0911111111",
  "pin": "1234",
  "deviceId": "stable-device-uuid"
}
```

Returns `{ token, user, shop, subscription }`. Owners must send the same
`deviceId` that claimed the account. A different device receives `409` until an
admin resets the binding. Admin logins do not need `deviceId`.

### `GET /auth/me`

Returns the current user, shop, and latest subscription.

### `GET /time`

Public. Returns `{ "serverTime": "2026-11-04T09:00:00.000Z" }`.

## Catalog

### `GET /packages`

Public. Active packages ordered by `sortOrder`.

### `GET /bank-accounts`

Public. Active bank accounts.

### `GET /library/categories?page=1&pageSize=100`

Auth + device-bound. Categories with item counts. Returns
`{ categories, total, page, pageSize, hasMore }`.

### `GET /library/products?page=1&pageSize=50&categoryId=…&q=…&updatedSince=ISO`

Auth + device-bound. Product library items. `q` searches name, SKU, and barcode.
`updatedSince` enables incremental pulls. Returns
`{ products, total, page, pageSize, hasMore }`.

## Supplier marketplace

Supplier endpoints require a `SUPPLIER` token.

### `GET /supplier/categories`, `POST /supplier/categories`, `PATCH|DELETE /supplier/categories/:id`

`GET` mirrors the client's SUQ library: it returns every category with active
products plus the supplier's own categories (including empty ones). Each row
includes `supplierId`, so the app can tell which categories the supplier owns.
Only the supplier's own categories can be renamed or deleted.

### `GET /supplier/products`, `POST /supplier/products`, `PATCH|DELETE /supplier/products/:id`

`GET` returns the same feed shops browse in the client's SUQ library — every
active product from SUQ and all suppliers — plus the supplier's own rows. Only
products created by the supplier can be edited or deleted. These products form
the library shops copy into their own catalog; they are not wholesale listings.

### `GET /supplier/listings`, `POST /supplier/listings`, `PATCH /supplier/listings/:id`

Wholesale listings are standalone offers and are not linked to catalog products.

```json
{
  "name": "Teff flour — 25 kg sack",
  "description": "Grade 1, Addis Ababa",
  "category": "Grains",
  "saleUnit": "sack",
  "piecesPerUnit": 1,
  "pricePerUnit": 3200,
  "minOrderQty": 2,
  "weightPerUnitKg": 25,
  "lengthCm": 60,
  "widthCm": 40,
  "heightCm": 15,
  "active": true
}
```

`saleUnit` is one of `piece`, `dozen`, `pack`, `sack`, `crate`, `bulk`.
`piecesPerUnit` states how many individual pieces one sale unit contains — for
example a pack of 6 or 12, or a sack holding 24 tins. It defaults to `1`, and a
`dozen` should use `12`. `weightPerUnitKg` is always kilograms even when the
supplier enters grams in the app. The server computes
`volumePerUnitM3 = lengthCm × widthCm × heightCm / 1,000,000`. `PATCH` accepts
any subset of the fields above.

Every listing records the publishing account in `publishedById` and returns the
account as `publishedBy` (`{ id, name, phone }`). The field is set from the
authenticated supplier token and cannot be chosen by the client.

### Shop ordering

`GET /orders/suppliers` returns suppliers with active listings. `POST /orders`
accepts `{ supplierId, items: [{ listingId, quantity }], latitude?, longitude?, note? }`;
each quantity must meet the listing's `minOrderQty`.

Delivery is suggested from the supplier's rates:

```text
base fee
+ distanceKm × deliveryPerKm
+ shippingWeightKg × deliveryPerKg
+ shippingVolumeM3 × deliveryPerCubicMeter
```

Fees and totals are rounded to 2 decimals. The supplier can override the quote
with `PATCH /supplier/orders/:id/delivery` before accepting the order.

`PATCH /supplier/orders/:id/status` moves an order through
`PENDING → ACCEPTED/REJECTED`, `ACCEPTED → READY`, and `READY → DELIVERED`.
Accepting stores `acceptedById` from the supplier token and `acceptedAt`.
Order responses include `acceptedBy` (`{ id, name, phone }`) and `acceptedAt` so
shops and suppliers can see who accepted the order.

## Subscription

### `GET /subscription/me`

Auth. Current subscription + payment history summary.

### `POST /payments`

Auth. Submit a manual payment.

```json
{
  "packageId": "pkg_1m",
  "bankAccountId": "bank_cbe",
  "transactionRef": "FT24ABC123",
  "note": "Paid from CBE app"
}
```

Returns the pending payment. Amount is computed server-side from the package —
the client cannot choose the price.

### `GET /payments/mine`

Auth. Payment history.

### `POST /subscription/entitlement`

Auth. Body `{ "deviceId": "…", "appVersion": "1.0.0" }`.

Returns:

```json
{
  "serverTime": "2026-11-04T09:00:00.000Z",
  "active": true,
  "subscription": { "id": "…", "packageName": "1 Month", "startsAt": "…", "endsAt": "…" },
  "token": "<base64url payload>.<base64url signature>",
  "leaseDays": 7
}
```

## Sync

### `POST /sync`

Auth. Idempotent push of local changes.

```json
{
  "deviceId": "…",
  "sales": [
    {
      "id": "uuid",
      "receiptNo": "SUQ-20261104-0001",
      "customerId": "uuid",
      "customerName": "Sara",
      "subtotal": 120,
      "discount": 0,
      "total": 120,
      "paid": 100,
      "credit": 20,
      "cost": 90,
      "profit": 30,
      "paymentMethod": "PARTIAL",
      "soldAt": "2026-11-04T08:00:00.000Z",
      "items": [
        { "id": "uuid", "productId": "uuid", "name": "Sugar 1kg", "unit": "kg", "qty": 2, "unitPrice": 60, "unitCost": 45, "lineTotal": 120 }
      ]
    }
  ],
  "customers": [ ... ],
  "products": [ ... ],
  "creditEntries": [ ... ]
}
```

Returns `{ "accepted": { "sales": 1, … }, "serverTime": "…" }`.

## Admin

All admin routes require a JWT whose user role is `ADMIN`.

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/admin/dashboard` | Counts, revenue, expiring shops |
| GET | `/admin/payments?status=PENDING` | Payment queue |
| POST | `/admin/payments/:id/approve` | Approve + activate subscription |
| POST | `/admin/payments/:id/reject` | Reject with note |
| GET | `/admin/shops` | Shops with subscription state and device binding |
| POST | `/admin/shops/:id/reset-device` | Clear the bound device so the owner can log in on a new phone |
| GET/POST | `/admin/packages` | List / create packages |
| PATCH/DELETE | `/admin/packages/:id` | Update / deactivate |
| GET/POST | `/admin/bank-accounts` | List / create bank accounts |
| PATCH/DELETE | `/admin/bank-accounts/:id` | Update / deactivate |
| GET/POST | `/admin/library/categories` | Paginated list (`page`, `pageSize`) / create |
| PATCH/DELETE | `/admin/library/categories/:id` | Update / delete |
| GET/POST | `/admin/library/products` | Paginated list (`page`, `pageSize`, `q`, `categoryId`) / create |
| PATCH/DELETE | `/admin/library/products/:id` | Update / deactivate |

### Approve payment response

```json
{
  "payment": { "id": "…", "status": "APPROVED" },
  "subscription": {
    "id": "…",
    "status": "ACTIVE",
    "startsAt": "2026-11-04T09:00:00.000Z",
    "endsAt": "2026-12-04T09:00:00.000Z"
  }
}
```

## Status codes

- `200` OK
- `201` Created
- `400` Validation error
- `401` Missing/invalid token
- `403` Wrong role / subscription not active
- `404` Not found
- `409` Conflict (duplicate transaction reference or account already bound to another device)
- `500` Server error
