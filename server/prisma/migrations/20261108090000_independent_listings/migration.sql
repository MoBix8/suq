-- Make supplier listings standalone wholesale offers.
-- Listings no longer reference ProductLibraryItem; catalog products stay in the
-- retail library that shops copy into their own shop catalog.

-- Add the new listing columns before backfilling from the old product link.
ALTER TABLE "SupplierListing"
    ADD COLUMN "name" TEXT,
    ADD COLUMN "description" TEXT,
    ADD COLUMN "category" TEXT,
    ADD COLUMN "saleUnit" TEXT NOT NULL DEFAULT 'pack',
    ADD COLUMN "pricePerUnit" DOUBLE PRECISION,
    ADD COLUMN "minOrderQty" INTEGER NOT NULL DEFAULT 1,
    ADD COLUMN "weightPerUnitKg" DOUBLE PRECISION NOT NULL DEFAULT 0,
    ADD COLUMN "lengthCm" DOUBLE PRECISION NOT NULL DEFAULT 0,
    ADD COLUMN "widthCm" DOUBLE PRECISION NOT NULL DEFAULT 0,
    ADD COLUMN "heightCm" DOUBLE PRECISION NOT NULL DEFAULT 0,
    ADD COLUMN "volumePerUnitM3" DOUBLE PRECISION NOT NULL DEFAULT 0;

UPDATE "SupplierListing" AS l
SET
    "name" = COALESCE(NULLIF(TRIM(p."name" || ' — ' || l."packName"), ''), l."packName"),
    "category" = c."name",
    "pricePerUnit" = l."bulkPrice",
    "weightPerUnitKg" = l."weightKg",
    "volumePerUnitM3" = l."volumeCubicM"
FROM "ProductLibraryItem" p
LEFT JOIN "Category" c ON c."id" = p."categoryId"
WHERE p."id" = l."productId";

UPDATE "SupplierListing"
SET
    "name" = COALESCE("name", "packName"),
    "pricePerUnit" = COALESCE("pricePerUnit", "bulkPrice")
WHERE "name" IS NULL OR "pricePerUnit" IS NULL;

ALTER TABLE "SupplierListing" ALTER COLUMN "name" SET NOT NULL;
ALTER TABLE "SupplierListing" ALTER COLUMN "pricePerUnit" SET NOT NULL;
ALTER TABLE "SupplierListing" ALTER COLUMN "saleUnit" SET DEFAULT 'piece';

DROP INDEX "SupplierListing_supplierId_productId_key";
ALTER TABLE "SupplierListing" DROP CONSTRAINT "SupplierListing_productId_fkey";
ALTER TABLE "SupplierListing"
    DROP COLUMN "productId",
    DROP COLUMN "packName",
    DROP COLUMN "unitsPerPack",
    DROP COLUMN "weightKg",
    DROP COLUMN "volumeCubicM",
    DROP COLUMN "bulkPrice";

-- Order lines snapshot the standalone listing at the time of ordering.
ALTER TABLE "ShopOrderItem"
    ADD COLUMN "listingId" TEXT,
    ADD COLUMN "listingName" TEXT,
    ADD COLUMN "category" TEXT,
    ADD COLUMN "saleUnit" TEXT NOT NULL DEFAULT 'pack',
    ADD COLUMN "quantity" INTEGER,
    ADD COLUMN "lengthCm" DOUBLE PRECISION NOT NULL DEFAULT 0,
    ADD COLUMN "widthCm" DOUBLE PRECISION NOT NULL DEFAULT 0,
    ADD COLUMN "heightCm" DOUBLE PRECISION NOT NULL DEFAULT 0;

UPDATE "ShopOrderItem"
SET
    "listingName" = COALESCE(NULLIF(TRIM("productName" || ' — ' || "packName"), ''), "productName"),
    "quantity" = "packageCount";

UPDATE "ShopOrderItem"
SET
    "listingName" = COALESCE("listingName", 'Listing'),
    "quantity" = COALESCE("quantity", 1)
WHERE "listingName" IS NULL OR "quantity" IS NULL;

ALTER TABLE "ShopOrderItem" ALTER COLUMN "listingName" SET NOT NULL;
ALTER TABLE "ShopOrderItem" ALTER COLUMN "quantity" SET NOT NULL;
-- The column default only existed to backfill old rows; new rows always send it.
ALTER TABLE "ShopOrderItem" ALTER COLUMN "saleUnit" DROP DEFAULT;

ALTER TABLE "ShopOrderItem"
    DROP COLUMN "productId",
    DROP COLUMN "productName",
    DROP COLUMN "sku",
    DROP COLUMN "retailUnit",
    DROP COLUMN "packName",
    DROP COLUMN "unitsPerPack",
    DROP COLUMN "packageCount";

CREATE INDEX "ShopOrderItem_orderId_idx" ON "ShopOrderItem"("orderId");

ALTER TABLE "ShopOrderItem"
    ADD CONSTRAINT "ShopOrderItem_listingId_fkey"
    FOREIGN KEY ("listingId") REFERENCES "SupplierListing"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
