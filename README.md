# SUQ — Offline-first shop management for Ethiopia

**SUQ (ሱቅ)** is a subscription SaaS for small shops in Ethiopia. Shop owners manage
sales, products, customers, credit (ዱቤ), and daily profit — **fully offline** — while
a Node.js API and a Flutter admin app handle subscriptions, manual bank payments,
and the shared product library.

```
suq/
├── docs/                  Product spec, architecture, API contract
├── server/                Node.js + TypeScript + Express + Prisma + SQLite
├── apps/
│   ├── suq_client/        Flutter shop app (offline-first, Riverpod, no GetX)
│   └── suq_admin/         Flutter admin app (payments, packages, library)
```

## Why this design

- **Offline is the default, not a fallback.** Every sale is written to the local
  SQLite database first. The network is only used for activation, entitlement
  refresh, library downloads, and optional backup sync.
- **Subscription dates are server-authoritative.** The server signs a short-lived
  entitlement lease with Ed25519. The client verifies the signature and evaluates
  it against a tamper-resistant clock. Changing the phone date does not extend a
  subscription.
- **Manual payments fit the market.** The owner picks a package, sees the bank
  account, transfers the money, and submits the transaction number. An admin
  approves it; the subscription starts at server time.

## Quick start

### 1. Server

```powershell
cd server
npm install
copy .env.example .env
npm run setup        # prisma generate + db push + seed
npm run dev          # http://localhost:4000
```

Seeded accounts:

| Role  | Phone        | PIN    | Notes |
|-------|--------------|--------|-------|
| Admin | `0900000000` | `1234` | Admin console login |
| Owner | `0911111111` | `1234` | Active subscription |
| Owner | `0922222222` | `1234` | Has a pending payment (`FT24DEMO0001`) to approve |

### 2. Shop app (Flutter)

```powershell
cd apps/suq_client
flutter pub get
flutter run -d windows        # or an Android device/emulator
```

Android emulator uses `http://10.0.2.2:4000` automatically. For a physical phone:

```powershell
flutter run --dart-define=SUQ_API=http://192.168.1.50:4000
```

### 3. Admin app (Flutter)

```powershell
cd apps/suq_admin
flutter pub get
flutter run -d windows --dart-define=SUQ_API=http://localhost:4000
# or in a browser
flutter run -d chrome --dart-define=SUQ_API=http://localhost:4000
```

Sign in with the admin account. The console has four sections:

- **Dashboard** — shop/revenue stats, renewals due within 7 days, recent payments.
- **Payments** — pending queue with approve (extends the subscription) and reject
  (with a note); filters for approved/rejected history.
- **Shops** — every shop with its owner, activity counts, subscription term, and a
  **Grant time** action for payments confirmed outside the queue.
- **Catalog** — CRUD for packages, receiving bank accounts, library categories, and
  library products (default selling/buying prices, units, barcodes, active state).

## Verification

```powershell
cd server && npm run typecheck
cd apps/suq_client && flutter analyze && flutter test
cd apps/suq_admin && flutter analyze && flutter test && flutter build web --release
```

## Security notes before production

1. Replace the seeded admin PIN and `JWT_SECRET`.
2. Generate a production entitlement key pair with `node scripts/gen-keys.mjs`,
   keep the private key off the repo, and rebuild the client with the new public key.
3. Serve the API over HTTPS only; put it behind Caddy/Nginx.
4. Switch SQLite to Postgres when you have concurrent shops (Prisma makes this a
   datasource change plus a migration).
5. Add payment-proof uploads to object storage (S3/R2) and rate limiting.

See `docs/PRODUCT_SPEC.md` for the full product summary and `docs/SECURITY.md`
for the subscription enforcement model.
