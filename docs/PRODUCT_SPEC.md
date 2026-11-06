# SUQ — Product Specification

## 1. One-line summary

SUQ is a monthly subscription app that lets an Ethiopian neighborhood shop run
its entire business **without internet**: download a curated product catalog, set
local prices, serve several customers at once with parallel carts, record cash
and credit sales, track customer debts, and see daily revenue, cost, and profit.

## 2. The problem

Small shops in Ethiopia usually track sales in a notebook. The owner cannot
answer basic questions:

- How much did I sell today?
- What is my profit after cost?
- Who owes me money (ዱቤ), and how much?
- Which products are running out?
- What did I sell to the customer standing in front of me while two others wait?

Existing POS apps assume reliable internet, card payments, and barcode scanners.
SUQ assumes the opposite: intermittent power and internet, cash and Telebirr/CBE
transfers, handwritten credit books, and cheap Android phones.

## 3. Target user

- Neighborhood shops, kiosks, minimarkets, pharmacies, cosmetics shops.
- One owner, sometimes one helper.
- Android phone as the primary device; a laptop is optional.
- Pays for software monthly via CBE / Telebirr / Awash bank transfer.
- Needs Amharic-friendly, low-text, large-tap-target UI.

## 4. Core jobs to be done

| Job | SUQ feature |
|-----|-------------|
| "Let me sell fast" | Multi-cart checkout with search, quantity, discount, cash/credit |
| "I don't want to type every product" | Shared product library, download all or selected items |
| "I decide my prices" | Per-shop selling price; optional buying price for profit |
| "Some customers pay later" | Customer ledger, credit sales, repayments, outstanding balance |
| "How was today?" | Daily dashboard: revenue, profit, sales count, credit given |
| "Which products make money?" | Reports: top products, low stock, 7-day trend, P&L |
| "I paid for a month" | Manual bank payment → transaction number → admin approval |
| "I have no internet" | Everything above works offline; sync when connected |

## 5. Subscription and activation flow

1. Owner registers with phone, PIN, shop name, city.
2. Owner sees packages (1, 3, 6, 12 months) at **200 ETB per month**
   (200 / 600 / 1,200 / 2,400 ETB).
3. Owner selects a package and a bank account (CBE, Telebirr, Awash).
4. App shows account name, account number, exact amount, and a reference code.
5. Owner transfers the money and submits the **transaction number**.
6. Payment appears in the admin app as **Pending**.
7. Admin verifies the bank statement and taps **Approve**.
8. Server computes `startsAt` and `endsAt` from **server time** and issues a
   signed entitlement lease to the device.
9. Shop app unlocks. If the previous subscription is still active, the new
   period is appended to its end date (no lost days).

Each owner account is bound to **one device**. Login/registration sends a stable
device id, and the server rejects the account on any other device. The admin app
has a **Reset linked device** action for lost or replaced phones; the next login
claims the new device.

### Anti-tamper rules

- Subscription start/end are stored only on the server.
- The client receives an **Ed25519-signed lease**, not editable dates.
- The lease is valid for at most **7 offline days**, even if the package is
  longer. The app must reconnect before the lease expires.
- The client clock is anchored to the last server time. Rolling the device clock
  backwards is detected and forces an online refresh.
- Moving the clock forward only makes the subscription expire sooner; moving it
  backwards triggers the rollback flag.
- Payment approval is idempotent and transactional.

## 6. Product library

- Admin-managed categories and products (Ethiopian staples: teff, berbere, shiro,
  cooking oil, sugar, flour, pasta, coffee, soap, detergent, soft drinks…).
- Each library item has: name, category, unit, default selling price, optional
  default buying price, barcode, version. The admin product form uses a **unit
  dropdown** so units stay consistent.
- Admin category and product lists are paginated, with server-side search and a
  category filter, so the app never loads every library record at once.
- The shop can download a category, select items one by one, or tap **Select all**
  to add every matching product at once. Select-all explicitly fetches the
  remaining pages on demand.
- Downloaded items become shop products. The shop sets its own selling price and
  optionally its buying price. Library updates never overwrite a shop's price.
- Library pages, categories, packages, bank accounts, and payment history are
  cached locally so the relevant screens keep working offline.
- Shops can add custom products that stay local (and sync to the server as backup).

## 7. Multi-customer carts

- The checkout screen supports multiple tabs ("Customer 1", "Customer 2", …).
- Each tab has its own lines, customer, discount, and payment state.
- Switching tabs is instant; carts are persisted locally so a crash does not lose
  a sale.
- Checking out one tab does not affect the others.
- A tab can be linked to a registered customer or a walk-in name.

## 8. Customers and credit (ዱቤ)

- Customer record: name, phone, credit balance, ledger.
- At checkout the owner can take **full payment**, **partial payment**, or
  **full credit**.
- The unpaid amount increases the customer's balance and creates a ledger entry.
- "Receive payment" decreases the balance and records the method/note.
- The customer list shows total outstanding credit and who is over their limit.

## 9. Reports

- Today: revenue, cost, profit, sales count, credit given, cash collected.
- Last 7 days chart.
- Top products by revenue and profit.
- Low-stock list.
- Outstanding credit total and per-customer balances.
- Profit is marked **estimated** when some sold items have no buying price.

## 10. Offline-first behavior

- All reads/writes go to local SQLite.
- A sync queue records sales, customers, credit entries, and product changes.
- When online, the app pushes the queue and pulls catalog updates.
- The server is a backup/analytics copy; it is **not** required to make a sale.
- Conflicts are resolved last-write-wins by `updatedAt`, except sales which are
  immutable and idempotent by client-generated ID.

## 11. Screens (shop app)

1. Splash / session restore
2. Login / Register
3. Activation gate (plans, bank details, transaction submission, pending state)
4. Home dashboard
5. Checkout (multi-cart)
6. My products + product editor
7. Library browser/downloader
8. Customers + customer ledger
9. Reports
10. Subscription / account / settings

## 12. Screens (admin app)

1. Login
2. Dashboard (pending payments, active shops, expiring soon, revenue)
3. Payments queue + approve/reject
4. Packages CRUD
5. Bank accounts CRUD
6. Product library (categories + items CRUD)
7. Shops / subscriptions list

## 13. Non-goals for v1

- Payment gateway integration (manual approval is intentional).
- Multi-staff roles and permissions.
- Hardware receipt printer / barcode scanner integration.
- E-commerce storefront.
- Ethiopian VAT/tax invoicing.
- Web shop app (admin is Flutter desktop/web; shop app is Android-first).

## 14. Roadmap

**v1.1** — Amharic localization, receipt sharing (image/PDF), barcode scanning,
stock adjustments, supplier records.

**v1.2** — Postgres, object-storage payment proofs, SMS reminders for credit,
daily backup export, multi-device per shop.

**v2** — Staff accounts, purchase orders, multiple branches, analytics API,
Telebirr receipt verification, reseller/agent portal.

## 15. Success metrics

- Time to complete a sale < 20 seconds.
- 7-day retention of activated shops.
- % of sales recorded offline.
- Payment approval time < 12 hours.
- Weekly active shops / paid shops.
- Credit recovery rate.
