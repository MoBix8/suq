-- DropIndex
DROP INDEX "Category_name_key";

-- DropIndex
DROP INDEX "Category_slug_key";

-- AlterTable
ALTER TABLE "Shop" ADD COLUMN     "latitude" DOUBLE PRECISION,
ADD COLUMN     "longitude" DOUBLE PRECISION;

-- AlterTable
ALTER TABLE "Category" ADD COLUMN     "supplierId" TEXT;

-- AlterTable
ALTER TABLE "ProductLibraryItem" ADD COLUMN     "supplierId" TEXT;

-- CreateTable
CREATE TABLE "Supplier" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "businessName" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "deliveryBaseFee" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "deliveryPerKm" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "deliveryPerKg" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "deliveryPerCubicMeter" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Supplier_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SupplierListing" (
    "id" TEXT NOT NULL,
    "supplierId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "packName" TEXT NOT NULL,
    "unitsPerPack" DOUBLE PRECISION NOT NULL,
    "weightKg" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "volumeCubicM" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "bulkPrice" DOUBLE PRECISION NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SupplierListing_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ShopOrder" (
    "id" TEXT NOT NULL,
    "shopId" TEXT NOT NULL,
    "supplierId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "subtotal" DOUBLE PRECISION NOT NULL,
    "deliveryFee" DOUBLE PRECISION NOT NULL,
    "total" DOUBLE PRECISION NOT NULL,
    "deliveryDistanceKm" DOUBLE PRECISION,
    "deliveryQuoted" BOOLEAN NOT NULL DEFAULT false,
    "shippingWeightKg" DOUBLE PRECISION NOT NULL,
    "shippingVolumeM3" DOUBLE PRECISION NOT NULL,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ShopOrder_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ShopOrderItem" (
    "id" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "productId" TEXT,
    "productName" TEXT NOT NULL,
    "sku" TEXT NOT NULL,
    "retailUnit" TEXT NOT NULL,
    "packName" TEXT NOT NULL,
    "unitsPerPack" DOUBLE PRECISION NOT NULL,
    "packageCount" INTEGER NOT NULL,
    "unitPrice" DOUBLE PRECISION NOT NULL,
    "lineTotal" DOUBLE PRECISION NOT NULL,
    "weightKg" DOUBLE PRECISION NOT NULL,
    "volumeCubicM" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "ShopOrderItem_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Supplier_userId_key" ON "Supplier"("userId");

-- CreateIndex
CREATE INDEX "SupplierListing_supplierId_active_idx" ON "SupplierListing"("supplierId", "active");

-- CreateIndex
CREATE UNIQUE INDEX "SupplierListing_supplierId_productId_key" ON "SupplierListing"("supplierId", "productId");

-- CreateIndex
CREATE INDEX "ShopOrder_shopId_createdAt_idx" ON "ShopOrder"("shopId", "createdAt");

-- CreateIndex
CREATE INDEX "ShopOrder_supplierId_status_createdAt_idx" ON "ShopOrder"("supplierId", "status", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "Category_supplierId_name_key" ON "Category"("supplierId", "name");

-- CreateIndex
CREATE UNIQUE INDEX "Category_supplierId_slug_key" ON "Category"("supplierId", "slug");

-- AddForeignKey
ALTER TABLE "Supplier" ADD CONSTRAINT "Supplier_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Category" ADD CONSTRAINT "Category_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "Supplier"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProductLibraryItem" ADD CONSTRAINT "ProductLibraryItem_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "Supplier"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SupplierListing" ADD CONSTRAINT "SupplierListing_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "Supplier"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SupplierListing" ADD CONSTRAINT "SupplierListing_productId_fkey" FOREIGN KEY ("productId") REFERENCES "ProductLibraryItem"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ShopOrder" ADD CONSTRAINT "ShopOrder_shopId_fkey" FOREIGN KEY ("shopId") REFERENCES "Shop"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ShopOrder" ADD CONSTRAINT "ShopOrder_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "Supplier"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ShopOrderItem" ADD CONSTRAINT "ShopOrderItem_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "ShopOrder"("id") ON DELETE CASCADE ON UPDATE CASCADE;
