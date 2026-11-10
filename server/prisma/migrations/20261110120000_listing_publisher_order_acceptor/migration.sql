-- Record the exact account that published a listing and the account that
-- accepted an order. Both columns are nullable so existing rows remain valid.

ALTER TABLE "SupplierListing" ADD COLUMN "publishedById" TEXT;
ALTER TABLE "ShopOrder"
    ADD COLUMN "acceptedById" TEXT,
    ADD COLUMN "acceptedAt" TIMESTAMP(3);

-- Backfill listings from the supplier account that owns them.
UPDATE "SupplierListing" AS l
SET "publishedById" = s."userId"
FROM "Supplier" AS s
WHERE l."supplierId" = s."id" AND l."publishedById" IS NULL;

-- Existing accepted orders were accepted by the owning supplier account. The
-- exact timestamp was not stored, so use the last update as the best estimate.
UPDATE "ShopOrder" AS o
SET
    "acceptedById" = s."userId",
    "acceptedAt" = o."updatedAt"
FROM "Supplier" AS s
WHERE o."supplierId" = s."id"
  AND o."status" IN ('ACCEPTED', 'READY', 'DELIVERED')
  AND o."acceptedById" IS NULL;

CREATE INDEX "SupplierListing_publishedById_idx" ON "SupplierListing"("publishedById");
CREATE INDEX "ShopOrder_acceptedById_idx" ON "ShopOrder"("acceptedById");

ALTER TABLE "SupplierListing"
    ADD CONSTRAINT "SupplierListing_publishedById_fkey"
    FOREIGN KEY ("publishedById") REFERENCES "User"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "ShopOrder"
    ADD CONSTRAINT "ShopOrder_acceptedById_fkey"
    FOREIGN KEY ("acceptedById") REFERENCES "User"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
