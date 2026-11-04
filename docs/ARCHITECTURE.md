# SUQ — Architecture

## System overview

```
┌──────────────────────────┐        HTTPS/JSON        ┌──────────────────────────┐
│  Shop app (Flutter)      │  ──────────────────────▶ │  API (Node/TS/Express)   │
│  Android / Windows       │  ◀────────────────────── │  Prisma + SQLite         │
│                          │                          │                          │
│  Riverpod                │   auth, packages,        │  JWT auth                │
│  sqflite (local DB)      │   library, payments,     │  Ed25519 entitlement     │
│  sync queue              │   entitlement, sync      │  admin endpoints         │
│  TrustedClock            │                          │  server time             │
└──────────────────────────┘                          └────────────┬─────────────┘
                                                                   │
┌──────────────────────────┐        HTTPS/JSON                     │
│  Admin app (Flutter)     │  ─────────────────────────────────────┘
│  Windows / Web           │  payments approve/reject, packages,
│  Riverpod + dio          │  banks, product library, shops
└──────────────────────────┘
```

## Why these choices

| Layer | Choice | Reason |
|-------|--------|--------|
| Shop state | **Riverpod** | Explicit, testable, no service locator, no GetX |
| Local DB | **sqflite** | Mature on Android; FFI on Windows for development |
| HTTP | **dio** | Interceptors, timeouts, simple errors |
| Routing | **go_router** | Declarative, deep-link friendly |
| Server | **Express + TypeScript** | Small team, fast iteration |
| ORM | **Prisma** | Typed queries, easy SQLite → Postgres migration |
| Auth | **JWT + bcrypt PIN** | Phone + 4–6 digit PIN is the local norm |
| Entitlement | **Ed25519 signed lease** | Client cannot forge or edit dates |

## Offline data flow

### Write path (sale)

1. UI calls `SalesRepository.checkout(...)`.
2. A single SQLite transaction inserts `sales`, `sale_items`, optional
   `credit_entries`, decrements product stock, and enqueues a sync job.
3. UI updates instantly from the local stream.
4. `SyncService` flushes the queue when connectivity returns.

### Read path

All screens read from local SQLite through repositories. The API is never on the
critical path of a sale.

### Sync queue

```
sync_queue(id, entity, entity_id, op, payload, created_at, attempts)
```

- `entity`: `sale`, `customer`, `credit_entry`, `product`
- `op`: `upsert`, `delete`
- Flushed in order, idempotent by client-generated UUID.
- Failed jobs retry with backoff; permanent validation errors are parked.

## Subscription enforcement

### Server side

- `Subscription` has `startsAt`, `endsAt`, `status`.
- On payment approval the server appends the package duration to the current
  end date if it is still in the future, otherwise starts now.
- The server signs:

```json
{
  "v": 1,
  "shopId": "…",
  "subscriptionId": "…",
  "packageName": "1 Month",
  "startsAt": "2026-11-04T…",
  "endsAt": "2026-12-04T…",
  "issuedAt": "2026-11-04T…",
  "leaseUntil": "2026-11-11T…",
  "deviceId": "…"
}
```

`leaseUntil = min(endsAt, issuedAt + 7 days)`. The signature is Ed25519 over the
exact UTF-8 payload bytes. Token format: `base64url(payload) + "." + base64url(sig)`.

### Client side

1. Verify the Ed25519 signature with the embedded public key.
2. Verify `shopId` matches the logged-in shop.
3. Evaluate dates with `TrustedClock`, not `DateTime.now()`.
4. Unlock only if `trustedNow ∈ [startsAt, leaseUntil)`.
5. If `leaseUntil` has passed, show “Connect to the internet to verify your
   subscription” and keep the app locked (data is never deleted).
6. If the clock rolled backwards, force an online refresh.

`TrustedClock` stores the last server timestamp and the local timestamp at the
moment it was received:

```
trustedNow = lastServerTime + (localNow - localTimeAtAnchor)
```

If `localNow < localTimeAtAnchor - 60s`, the clock was moved backwards. The app
flags tampering and refuses to extend the lease offline.

### Limitations (honest)

A determined attacker with a rooted phone can patch the app. No offline client
can be made 100% tamper-proof. The lease model makes casual date changes
useless, bounds offline abuse to 7 days per check, and gives the server a full
audit trail (`Device.lastSeenAt`, `lastServerTime`). For higher assurance, add
Play Integrity / App Attest in v2.

## Data model

Core server entities:

- `User` (owner/admin), `Shop`, `Device`
- `Package`, `Subscription`, `Payment`, `BankAccount`
- `Category`, `ProductLibraryItem`
- `ShopProduct`, `Customer`, `Sale`, `SaleItem`
- `SyncLog`

Local SQLite mirrors the shop-scoped subset plus `settings`, `sync_queue`,
and `credit_entries`.

## Environments

| Environment | API | DB |
|-------------|-----|----|
| Local dev | `http://localhost:4000` | SQLite file |
| Android emulator | `http://10.0.2.2:4000` | SQLite file |
| Production | `https://api.suq.et` | Postgres (recommended) |

## Failure modes

| Failure | Behavior |
|---------|----------|
| No internet at sale time | Sale saved locally, queued for sync |
| API down | Shop keeps working; activation/payment screens show retry |
| Phone date changed | TrustedClock detects rollback; lease does not extend |
| App killed mid-cart | Carts persisted in settings after every change |
| Duplicate sync | Idempotent upserts by UUID |
| Payment approved twice | Transaction + status check makes it idempotent |
| Subscription expires offline | Locked after lease; local data remains |

## Testing strategy

- Server: unit tests for date math, entitlement signing, payment approval.
- Flutter: `flutter analyze`, widget tests for cart totals, unit tests for
  entitlement verification and trusted clock.
- Manual: two-device flow (owner submits, admin approves, owner refreshes).
