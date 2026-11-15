-- Every supplier ships from one universal warehouse. Merkato is the default
-- pickup point because it is the main wholesale hub in Addis Ababa.
ALTER TABLE "Supplier"
    ADD COLUMN "warehouseName" TEXT NOT NULL DEFAULT 'Merkato';

ALTER TABLE "Supplier"
    ALTER COLUMN "latitude" SET DEFAULT 9.03056,
    ALTER COLUMN "longitude" SET DEFAULT 38.73889;

-- Existing suppliers without a pin fall back to Merkato.
UPDATE "Supplier"
SET "latitude" = 9.03056,
    "longitude" = 38.73889
WHERE "latitude" IS NULL OR "longitude" IS NULL;

-- Persist the delivery quote breakdown so old orders keep the exact numbers
-- that were agreed when the order was placed.
ALTER TABLE "ShopOrder"
    ADD COLUMN "deliveryBaseFee" DOUBLE PRECISION NOT NULL DEFAULT 0,
    ADD COLUMN "deliveryDistanceFee" DOUBLE PRECISION NOT NULL DEFAULT 0,
    ADD COLUMN "deliveryWeightFee" DOUBLE PRECISION NOT NULL DEFAULT 0,
    ADD COLUMN "deliveryVolumeFee" DOUBLE PRECISION NOT NULL DEFAULT 0,
    ADD COLUMN "warehouseName" TEXT;

-- Existing orders did not store the breakdown; attribute the whole fee to the
-- base component so the UI still reconciles to the stored delivery fee.
UPDATE "ShopOrder"
SET "deliveryBaseFee" = "deliveryFee"
WHERE "deliveryFee" > 0;
