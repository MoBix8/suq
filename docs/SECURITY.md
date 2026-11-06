# SUQ — Security & subscription enforcement

## Threat model

The paying customer controls the device and can:

- change the device date/time,
- edit or replace the local SQLite database,
- reinstall the app,
- inspect network traffic,
- share the APK.

We assume they **cannot** compromise the server or the Ed25519 private key.

## Controls

### 1. Server-authoritative dates

`startsAt` / `endsAt` are written only by the API on payment approval. The client
never sends subscription dates.

### 2. Signed offline lease

The client stores an Ed25519-signed token:

```
base64url(JSON payload) + "." + base64url(64-byte signature)
```

The app embeds only the **public** key. Editing the payload invalidates the
signature. Reinstalling cannot mint a new token.

Lease lifetime is `min(subscription end, 7 days)`. This limits offline abuse and
gives the server regular contact.

### 3. Trusted clock

- On every successful API response the client stores `serverTime` and the local
  wall-clock time.
- Later, `trustedNow = serverTime + (localNow - anchorLocalTime)`.
- A backwards jump > 60 seconds sets `clockTampered = true` and forces an online
  check; the app will not extend the lease using the local clock.
- A forward jump only shortens access.

### 4. Rollback handling

If the lease has expired and the device is offline, the app locks. Data is not
deleted; the owner sees a clear “verify subscription” screen. When online, the
server issues a fresh lease if the subscription is still valid.

### 5. Payment integrity

- Amount comes from the package row, not the request body.
- Duplicate transaction references are rejected (`409`).
- Approval runs in a Prisma transaction and checks `status === 'PENDING'`, so a
  double tap cannot create two subscription periods.
- Admin actions are attributed (`reviewedBy`) and timestamped.

### 6. Authentication

- Phone + PIN, hashed with bcrypt (cost 10+).
- JWT with role, shop, and device claims, signed by `JWT_SECRET`.
- Admin routes require `role === 'ADMIN'`.
- Owner accounts are bound to one `deviceId` (`Shop.boundDeviceId`). Login and
  registration claim the device; catalog, billing, entitlement, and sync routes
  run `requireBoundDevice` and reject a mismatched token. Admins can reset the
  binding from the admin app.
- Production: HTTPS only, rate-limit login and payment submission, and consider
  Play Integrity / App Attest for stronger device identity.

### 7. Data protection

- Local SQLite contains business data; use SQLCipher or Android encrypted storage
  for v1.1 if shops request it.
- Payment proofs should go to private object storage, not the database.
- Backups must be encrypted.

## What this does not stop

- A rooted device with a patched APK.
- A user who keeps the phone clock frozen and never restarts the app for longer
  than the lease. (The lease still expires by wall clock; freezing is an edge
  case. Play Integrity closes it.)
- A user who copies the app's local `device.id` value to another phone. Device
  binding blocks normal multi-device use, but it is not hardware attestation.
  Play Integrity / App Attest is the stronger fix.

## Production checklist

- [ ] Rotate `JWT_SECRET`
- [ ] Replace seeded admin credentials
- [ ] Generate production entitlement keys; store private key in a secret manager
- [ ] HTTPS + HSTS
- [ ] Rate limiting (login, payment submit, sync)
- [ ] Postgres + daily backups
- [ ] Structured logs + error tracking
- [ ] Privacy policy and terms in Amharic/English
- [ ] Payment-proof storage with signed URLs
- [ ] Monitor `Device.lastServerTime` gaps for abuse
