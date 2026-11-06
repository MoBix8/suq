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
