import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

const categories = [
  { slug: "grains", name: "Grains & Flour", sortOrder: 1 },
  { slug: "cooking", name: "Cooking Essentials", sortOrder: 2 },
  { slug: "spices", name: "Spices & Condiments", sortOrder: 3 },
  { slug: "beverages", name: "Beverages", sortOrder: 4 },
  { slug: "snacks", name: "Snacks", sortOrder: 5 },
  { slug: "household", name: "Household", sortOrder: 6 },
  { slug: "personal", name: "Personal Care", sortOrder: 7 },
  { slug: "dairy", name: "Dairy & Eggs", sortOrder: 8 },
  { slug: "bakery", name: "Bakery", sortOrder: 9 },
  { slug: "stationery", name: "Stationery", sortOrder: 10 },
];

type SeedProduct = {
  sku: string;
  category: string;
  name: string;
  unit: string;
  sell: number;
  buy: number;
};

const products: SeedProduct[] = [
  // Grains & Flour
  { sku: "GR-001", category: "grains", name: "Teff 1kg", unit: "kg", sell: 180, buy: 150 },
  { sku: "GR-002", category: "grains", name: "Wheat flour 1kg", unit: "kg", sell: 95, buy: 78 },
  { sku: "GR-003", category: "grains", name: "White rice 1kg", unit: "kg", sell: 130, buy: 105 },
  { sku: "GR-004", category: "grains", name: "Brown rice 1kg", unit: "kg", sell: 140, buy: 115 },
  { sku: "GR-005", category: "grains", name: "Maize flour 1kg", unit: "kg", sell: 70, buy: 55 },
  { sku: "GR-006", category: "grains", name: "Sorghum 1kg", unit: "kg", sell: 90, buy: 70 },
  { sku: "GR-007", category: "grains", name: "Barley 1kg", unit: "kg", sell: 85, buy: 68 },
  { sku: "GR-008", category: "grains", name: "Chickpeas 1kg", unit: "kg", sell: 150, buy: 120 },
  { sku: "GR-009", category: "grains", name: "Lentils 1kg", unit: "kg", sell: 160, buy: 130 },
  { sku: "GR-010", category: "grains", name: "Shiro powder 500g", unit: "pack", sell: 140, buy: 110 },

  // Cooking Essentials
  { sku: "CK-001", category: "cooking", name: "Cooking oil 1L", unit: "l", sell: 280, buy: 240 },
  { sku: "CK-002", category: "cooking", name: "Cooking oil 5L", unit: "pack", sell: 1250, buy: 1100 },
  { sku: "CK-003", category: "cooking", name: "Sugar 1kg", unit: "kg", sell: 90, buy: 75 },
  { sku: "CK-004", category: "cooking", name: "Salt 1kg", unit: "kg", sell: 35, buy: 25 },
  { sku: "CK-005", category: "cooking", name: "Tomato paste 400g", unit: "can", sell: 85, buy: 70 },
  { sku: "CK-006", category: "cooking", name: "Pasta 500g", unit: "pack", sell: 65, buy: 50 },
  { sku: "CK-007", category: "cooking", name: "Macaroni 500g", unit: "pack", sell: 60, buy: 48 },
  { sku: "CK-008", category: "cooking", name: "Instant noodles", unit: "pack", sell: 45, buy: 35 },
  { sku: "CK-009", category: "cooking", name: "Baking powder 100g", unit: "pack", sell: 30, buy: 22 },
  { sku: "CK-010", category: "cooking", name: "Yeast 50g", unit: "pack", sell: 25, buy: 18 },

  // Spices
  { sku: "SP-001", category: "spices", name: "Berbere 100g", unit: "pack", sell: 70, buy: 55 },
  { sku: "SP-002", category: "spices", name: "Berbere 500g", unit: "pack", sell: 300, buy: 250 },
  { sku: "SP-003", category: "spices", name: "Turmeric 100g", unit: "pack", sell: 40, buy: 30 },
  { sku: "SP-004", category: "spices", name: "Black pepper 100g", unit: "pack", sell: 55, buy: 42 },
  { sku: "SP-005", category: "spices", name: "Garlic powder 100g", unit: "pack", sell: 45, buy: 35 },
  { sku: "SP-006", category: "spices", name: "Cardamom 50g", unit: "pack", sell: 80, buy: 65 },
  { sku: "SP-007", category: "spices", name: "Cinnamon 100g", unit: "pack", sell: 50, buy: 38 },
  { sku: "SP-008", category: "spices", name: "Chili powder 100g", unit: "pack", sell: 45, buy: 34 },
  { sku: "SP-009", category: "spices", name: "Mixed spice 100g", unit: "pack", sell: 60, buy: 45 },

  // Beverages
  { sku: "BV-001", category: "beverages", name: "Coca-Cola 500ml", unit: "bottle", sell: 60, buy: 48 },
  { sku: "BV-002", category: "beverages", name: "Pepsi 500ml", unit: "bottle", sell: 60, buy: 48 },
  { sku: "BV-003", category: "beverages", name: "Mirinda 500ml", unit: "bottle", sell: 60, buy: 48 },
  { sku: "BV-004", category: "beverages", name: "Bottled water 1L", unit: "bottle", sell: 30, buy: 22 },
  { sku: "BV-005", category: "beverages", name: "Bottled water 500ml", unit: "bottle", sell: 20, buy: 14 },
  { sku: "BV-006", category: "beverages", name: "Ambo mineral water 500ml", unit: "bottle", sell: 35, buy: 26 },
  { sku: "BV-007", category: "beverages", name: "Coffee beans 500g", unit: "pack", sell: 280, buy: 230 },
  { sku: "BV-008", category: "beverages", name: "Ground coffee 250g", unit: "pack", sell: 150, buy: 120 },
  { sku: "BV-009", category: "beverages", name: "Black tea 100g", unit: "pack", sell: 70, buy: 55 },

  // Snacks
  { sku: "SN-001", category: "snacks", name: "Biscuits 100g", unit: "pack", sell: 40, buy: 30 },
  { sku: "SN-002", category: "snacks", name: "Potato chips", unit: "pack", sell: 50, buy: 38 },
  { sku: "SN-003", category: "snacks", name: "Peanuts 100g", unit: "pack", sell: 35, buy: 25 },
  { sku: "SN-004", category: "snacks", name: "Chocolate bar", unit: "pcs", sell: 60, buy: 48 },
  { sku: "SN-005", category: "snacks", name: "Cake slice", unit: "pcs", sell: 45, buy: 30 },

  // Household
  { sku: "HH-001", category: "household", name: "Laundry soap bar", unit: "pcs", sell: 50, buy: 38 },
  { sku: "HH-002", category: "household", name: "Detergent 500g", unit: "pack", sell: 130, buy: 105 },
  { sku: "HH-003", category: "household", name: "Dish soap 500ml", unit: "bottle", sell: 90, buy: 70 },
  { sku: "HH-004", category: "household", name: "Bleach 1L", unit: "bottle", sell: 80, buy: 62 },
  { sku: "HH-005", category: "household", name: "Toilet paper 4 rolls", unit: "pack", sell: 120, buy: 95 },
  { sku: "HH-006", category: "household", name: "Matches", unit: "pack", sell: 10, buy: 6 },
  { sku: "HH-007", category: "household", name: "Candles", unit: "pack", sell: 60, buy: 45 },
  { sku: "HH-008", category: "household", name: "Charcoal 5kg", unit: "bag", sell: 350, buy: 300 },

  // Personal Care
  { sku: "PC-001", category: "personal", name: "Bath soap", unit: "pcs", sell: 55, buy: 42 },
  { sku: "PC-002", category: "personal", name: "Shampoo 400ml", unit: "bottle", sell: 250, buy: 210 },
  { sku: "PC-003", category: "personal", name: "Toothpaste 100ml", unit: "tube", sell: 120, buy: 95 },
  { sku: "PC-004", category: "personal", name: "Toothbrush", unit: "pcs", sell: 40, buy: 28 },
  { sku: "PC-005", category: "personal", name: "Body lotion 250ml", unit: "bottle", sell: 180, buy: 150 },
  { sku: "PC-006", category: "personal", name: "Sanitary pads", unit: "pack", sell: 90, buy: 70 },
  { sku: "PC-007", category: "personal", name: "Razor", unit: "pack", sell: 35, buy: 25 },
  { sku: "PC-008", category: "personal", name: "Hand sanitizer 250ml", unit: "bottle", sell: 110, buy: 85 },

  // Dairy & Eggs
  { sku: "DY-001", category: "dairy", name: "Eggs 12pcs", unit: "tray", sell: 200, buy: 175 },
  { sku: "DY-002", category: "dairy", name: "Fresh milk 1L", unit: "pack", sell: 95, buy: 80 },
  { sku: "DY-003", category: "dairy", name: "Yogurt 500ml", unit: "pack", sell: 80, buy: 65 },
  { sku: "DY-004", category: "dairy", name: "Butter 250g", unit: "pack", sell: 220, buy: 190 },
  { sku: "DY-005", category: "dairy", name: "Cheese 250g", unit: "pack", sell: 250, buy: 215 },

  // Bakery
  { sku: "BK-001", category: "bakery", name: "White bread", unit: "pcs", sell: 50, buy: 35 },
  { sku: "BK-002", category: "bakery", name: "Brown bread", unit: "pcs", sell: 60, buy: 42 },
  { sku: "BK-003", category: "bakery", name: "Injera", unit: "pcs", sell: 35, buy: 20 },
  { sku: "BK-004", category: "bakery", name: "Dabo", unit: "pcs", sell: 45, buy: 30 },
  { sku: "BK-005", category: "bakery", name: "Croissant", unit: "pcs", sell: 40, buy: 28 },

  // Stationery
  { sku: "ST-001", category: "stationery", name: "Exercise book", unit: "pcs", sell: 35, buy: 25 },
  { sku: "ST-002", category: "stationery", name: "Pen", unit: "pcs", sell: 15, buy: 9 },
  { sku: "ST-003", category: "stationery", name: "Pencil", unit: "pcs", sell: 10, buy: 6 },
  { sku: "ST-004", category: "stationery", name: "A4 paper 500 sheets", unit: "pack", sell: 650, buy: 570 },
  { sku: "ST-005", category: "stationery", name: "Notebook", unit: "pcs", sell: 60, buy: 45 },
];

async function main() {
  console.log("Seeding SUQ…");

  const admin = await prisma.user.upsert({
    where: { phone: "0900000000" },
    update: { name: "SUQ Admin", role: "ADMIN" },
    create: {
      phone: "0900000000",
      name: "SUQ Admin",
      role: "ADMIN",
      pinHash: bcrypt.hashSync("1234", 10),
    },
  });

  const owner = await prisma.user.upsert({
    where: { phone: "0911111111" },
    update: {},
    create: {
      phone: "0911111111",
      name: "Abebe Kebede",
      pinHash: bcrypt.hashSync("1234", 10),
      shop: {
        create: {
          name: "Abebe Mini Market",
          city: "Addis Ababa",
          subcity: "Bole",
          phone: "0911111111",
        },
      },
    },
    include: { shop: true },
  });

  const pendingOwner = await prisma.user.upsert({
    where: { phone: "0922222222" },
    update: {},
    create: {
      phone: "0922222222",
      name: "Hana Tesfaye",
      pinHash: bcrypt.hashSync("1234", 10),
      shop: {
        create: {
          name: "Hana Kiosk",
          city: "Addis Ababa",
          subcity: "Kirkos",
          phone: "0922222222",
        },
      },
    },
    include: { shop: true },
  });

  const packages = [
    { code: "pkg_1m", name: "1 Month", months: 1, priceEtb: 300, description: "Perfect for trying SUQ.", sortOrder: 1 },
    { code: "pkg_3m", name: "3 Months", months: 3, priceEtb: 800, description: "Save 100 ETB.", sortOrder: 2 },
    { code: "pkg_6m", name: "6 Months", months: 6, priceEtb: 1500, description: "Save 300 ETB.", sortOrder: 3 },
    { code: "pkg_12m", name: "12 Months", months: 12, priceEtb: 2800, description: "Best value — save 800 ETB.", sortOrder: 4 },
  ];

  const bankAccounts = [
    {
      code: "bank_cbe",
      bankName: "Commercial Bank of Ethiopia",
      accountName: "SUQ Technologies",
      accountNumber: "1000123456789",
      branch: "Bole Branch",
      instructions: "Use your shop phone number as the transfer reason.",
      sortOrder: 1,
    },
    {
      code: "bank_telebirr",
      bankName: "Telebirr",
      accountName: "SUQ Technologies",
      accountNumber: "0911000000",
      instructions: "Send the exact amount and keep the SMS confirmation.",
      sortOrder: 2,
    },
    {
      code: "bank_awash",
      bankName: "Awash Bank",
      accountName: "SUQ Technologies",
      accountNumber: "0130123456789",
      branch: "Megenagna Branch",
      sortOrder: 3,
    },
  ];

  for (const p of packages) {
    await prisma.package.upsert({
      where: { code: p.code },
      update: { name: p.name, months: p.months, priceEtb: p.priceEtb, description: p.description, sortOrder: p.sortOrder, active: true },
      create: p,
    });
  }

  for (const b of bankAccounts) {
    await prisma.bankAccount.upsert({
      where: { code: b.code },
      update: b,
      create: b,
    });
  }

  const categoryMap = new Map<string, string>();
  for (const c of categories) {
    const row = await prisma.category.upsert({
      where: { slug: c.slug },
      update: { name: c.name, sortOrder: c.sortOrder },
      create: c,
    });
    categoryMap.set(c.slug, row.id);
  }

  for (const p of products) {
    const categoryId = categoryMap.get(p.category);
    if (!categoryId) continue;
    await prisma.productLibraryItem.upsert({
      where: { sku: p.sku },
      update: {
        categoryId,
        name: p.name,
        unit: p.unit,
        defaultSellingPrice: p.sell,
        defaultBuyingPrice: p.buy,
        active: true,
      },
      create: {
        sku: p.sku,
        categoryId,
        name: p.name,
        unit: p.unit,
        defaultSellingPrice: p.sell,
        defaultBuyingPrice: p.buy,
      },
    });
  }

  // Give the demo owner an active 30-day subscription so the shop app is usable.
  if (owner.shop) {
    const active = await prisma.subscription.findFirst({
      where: { shopId: owner.shop.id, status: "ACTIVE", endsAt: { gt: new Date() } },
    });
    if (!active) {
      const pkg = await prisma.package.findUnique({ where: { code: "pkg_1m" } });
      if (pkg) {
        const startsAt = new Date();
        const endsAt = new Date(startsAt.getTime() + 30 * 24 * 60 * 60 * 1000);
        await prisma.subscription.create({
          data: {
            shopId: owner.shop.id,
            packageId: pkg.id,
            status: "ACTIVE",
            startsAt,
            endsAt,
          },
        });
      }
    }
  }

  // A pending payment for the admin queue.
  if (pendingOwner.shop) {
    const pkg = await prisma.package.findUnique({ where: { code: "pkg_3m" } });
    const bank = await prisma.bankAccount.findUnique({ where: { code: "bank_cbe" } });
    if (pkg && bank) {
      const existing = await prisma.payment.findUnique({ where: { transactionRef: "FT24DEMO0001" } });
      if (!existing) {
        await prisma.payment.create({
          data: {
            shopId: pendingOwner.shop.id,
            packageId: pkg.id,
            bankAccountId: bank.id,
            amountEtb: pkg.priceEtb,
            transactionRef: "FT24DEMO0001",
            note: "Paid via CBE mobile banking",
            status: "PENDING",
          },
        });
      }
    }
  }

  console.log(`Seeded ${products.length} products, ${categories.length} categories.`);
  console.log("Admin: 0900000000 / 1234");
  console.log("Owner (active): 0911111111 / 1234");
  console.log("Owner (pending payment): 0922222222 / 1234");
  console.log(`Admin id: ${admin.id}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
