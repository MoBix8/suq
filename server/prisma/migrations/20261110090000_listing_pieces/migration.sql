-- Number of individual pieces inside one wholesale sale unit. A pack may hold
-- 6, 12, or any other count; a sack/crate/bulk lot can differ as well.
ALTER TABLE "SupplierListing"
    ADD COLUMN "piecesPerUnit" INTEGER NOT NULL DEFAULT 1;
