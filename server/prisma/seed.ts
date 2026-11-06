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
  { slug: "frozen", name: "Frozen & Fresh", sortOrder: 11 },
  { slug: "baby", name: "Baby & Kids", sortOrder: 12 },
  { slug: "kitchen", name: "Home & Kitchen", sortOrder: 13 },
  { slug: "electronics", name: "Electronics & Power", sortOrder: 14 },
  { slug: "health", name: "Health & First Aid", sortOrder: 15 },
];

type SeedProduct = {
  sku: string;
  category: string;
  name: string;
  nameAm?: string;
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
  { sku: "ST-006", category: "stationery", name: "Eraser", unit: "pcs", sell: 8, buy: 5 },
  { sku: "ST-007", category: "stationery", name: "Sharpener", unit: "pcs", sell: 10, buy: 6 },
  { sku: "ST-008", category: "stationery", name: "Ruler 30cm", unit: "pcs", sell: 20, buy: 13 },
  { sku: "ST-009", category: "stationery", name: "Glue stick", unit: "pcs", sell: 35, buy: 25 },
  { sku: "ST-010", category: "stationery", name: "Scissors", unit: "pcs", sell: 60, buy: 42 },
  { sku: "ST-011", category: "stationery", name: "Stapler", unit: "pcs", sell: 120, buy: 90 },
  { sku: "ST-012", category: "stationery", name: "Staples", unit: "pack", sell: 20, buy: 13 },
  { sku: "ST-013", category: "stationery", name: "Envelopes 10pcs", unit: "pack", sell: 40, buy: 28 },
  { sku: "ST-014", category: "stationery", name: "Marker pen", unit: "pcs", sell: 25, buy: 16 },
  { sku: "ST-015", category: "stationery", name: "Drawing book", unit: "pcs", sell: 45, buy: 32 },

  // More Grains & Flour
  { sku: "GR-011", category: "grains", name: "Teff 5kg", unit: "bag", sell: 850, buy: 720 },
  { sku: "GR-012", category: "grains", name: "Wheat flour 5kg", unit: "pack", sell: 440, buy: 370 },
  { sku: "GR-013", category: "grains", name: "White rice 5kg", unit: "pack", sell: 610, buy: 500 },
  { sku: "GR-014", category: "grains", name: "Maize 5kg", unit: "pack", sell: 330, buy: 260 },
  { sku: "GR-015", category: "grains", name: "Green gram 1kg", unit: "kg", sell: 170, buy: 135 },
  { sku: "GR-016", category: "grains", name: "Faba beans 1kg", unit: "kg", sell: 120, buy: 95 },
  { sku: "GR-017", category: "grains", name: "Oats 500g", unit: "pack", sell: 110, buy: 85 },
  { sku: "GR-018", category: "grains", name: "Couscous 500g", unit: "pack", sell: 90, buy: 70 },

  // More Cooking Essentials
  { sku: "CK-011", category: "cooking", name: "Cooking oil 3L", unit: "pack", sell: 780, buy: 680 },
  { sku: "CK-012", category: "cooking", name: "Sugar 5kg", unit: "pack", sell: 430, buy: 360 },
  { sku: "CK-013", category: "cooking", name: "Salt 500g", unit: "pack", sell: 20, buy: 14 },
  { sku: "CK-014", category: "cooking", name: "Honey 500g", unit: "bottle", sell: 350, buy: 280 },
  { sku: "CK-015", category: "cooking", name: "Tomato sauce 500g", unit: "bottle", sell: 110, buy: 88 },
  { sku: "CK-016", category: "cooking", name: "Mayonnaise 250g", unit: "bottle", sell: 140, buy: 110 },
  { sku: "CK-017", category: "cooking", name: "Vinegar 500ml", unit: "bottle", sell: 60, buy: 45 },
  { sku: "CK-018", category: "cooking", name: "Shiro powder 1kg", unit: "pack", sell: 260, buy: 210 },
  { sku: "CK-019", category: "cooking", name: "Lentil flour 500g", unit: "pack", sell: 90, buy: 70 },
  { sku: "CK-020", category: "cooking", name: "Peanut butter 340g", unit: "jar", sell: 220, buy: 180 },

  // More Spices
  { sku: "SP-010", category: "spices", name: "Cumin 100g", unit: "pack", sell: 50, buy: 38 },
  { sku: "SP-011", category: "spices", name: "Coriander 100g", unit: "pack", sell: 40, buy: 30 },
  { sku: "SP-012", category: "spices", name: "Ginger powder 100g", unit: "pack", sell: 45, buy: 34 },
  { sku: "SP-013", category: "spices", name: "Nutmeg 50g", unit: "pack", sell: 60, buy: 45 },
  { sku: "SP-014", category: "spices", name: "Cloves 50g", unit: "pack", sell: 70, buy: 55 },
  { sku: "SP-015", category: "spices", name: "Fenugreek 100g", unit: "pack", sell: 35, buy: 26 },
  { sku: "SP-016", category: "spices", name: "Paprika 100g", unit: "pack", sell: 50, buy: 38 },
  { sku: "SP-017", category: "spices", name: "Mitmita 100g", unit: "pack", sell: 65, buy: 50 },
  { sku: "SP-018", category: "spices", name: "Shiro spice mix 100g", unit: "pack", sell: 45, buy: 33 },

  // More Beverages
  { sku: "BV-010", category: "beverages", name: "Coca-Cola 2L", unit: "bottle", sell: 120, buy: 98 },
  { sku: "BV-011", category: "beverages", name: "Pepsi 2L", unit: "bottle", sell: 120, buy: 98 },
  { sku: "BV-012", category: "beverages", name: "Fanta 500ml", unit: "bottle", sell: 60, buy: 48 },
  { sku: "BV-013", category: "beverages", name: "Sprite 500ml", unit: "bottle", sell: 60, buy: 48 },
  { sku: "BV-014", category: "beverages", name: "Mango juice 1L", unit: "pack", sell: 95, buy: 75 },
  { sku: "BV-015", category: "beverages", name: "Orange juice 1L", unit: "pack", sell: 95, buy: 75 },
  { sku: "BV-016", category: "beverages", name: "Energy drink 250ml", unit: "can", sell: 80, buy: 62 },
  { sku: "BV-017", category: "beverages", name: "Malt drink 330ml", unit: "bottle", sell: 70, buy: 55 },
  { sku: "BV-018", category: "beverages", name: "Tea bags 25pcs", unit: "pack", sell: 120, buy: 95 },
  { sku: "BV-019", category: "beverages", name: "Green tea 100g", unit: "pack", sell: 80, buy: 62 },
  { sku: "BV-020", category: "beverages", name: "Hot chocolate 200g", unit: "pack", sell: 160, buy: 130 },
  { sku: "BV-021", category: "beverages", name: "Milk powder 400g", unit: "pack", sell: 320, buy: 275 },
  { sku: "BV-022", category: "beverages", name: "Bottled water 2L", unit: "bottle", sell: 40, buy: 30 },
  { sku: "BV-023", category: "beverages", name: "Sparkling water 500ml", unit: "bottle", sell: 45, buy: 34 },

  // More Snacks
  { sku: "SN-006", category: "snacks", name: "Cookies 200g", unit: "pack", sell: 90, buy: 70 },
  { sku: "SN-007", category: "snacks", name: "Wafer 50g", unit: "pack", sell: 30, buy: 22 },
  { sku: "SN-008", category: "snacks", name: "Candy 100g", unit: "pack", sell: 45, buy: 33 },
  { sku: "SN-009", category: "snacks", name: "Chewing gum", unit: "pack", sell: 20, buy: 13 },
  { sku: "SN-010", category: "snacks", name: "Popcorn 100g", unit: "pack", sell: 35, buy: 25 },
  { sku: "SN-011", category: "snacks", name: "Roasted chickpeas 100g", unit: "pack", sell: 30, buy: 21 },
  { sku: "SN-012", category: "snacks", name: "Kolo 100g", unit: "pack", sell: 25, buy: 17 },
  { sku: "SN-013", category: "snacks", name: "Doughnut", unit: "pcs", sell: 30, buy: 20 },
  { sku: "SN-014", category: "snacks", name: "Muffin", unit: "pcs", sell: 35, buy: 24 },
  { sku: "SN-015", category: "snacks", name: "Ice cream cup", unit: "pcs", sell: 60, buy: 45 },

  // More Household
  { sku: "HH-009", category: "household", name: "Laundry detergent 1kg", unit: "pack", sell: 240, buy: 195 },
  { sku: "HH-010", category: "household", name: "Dish sponge", unit: "pcs", sell: 15, buy: 9 },
  { sku: "HH-011", category: "household", name: "Scouring pad", unit: "pcs", sell: 12, buy: 7 },
  { sku: "HH-012", category: "household", name: "Broom", unit: "pcs", sell: 120, buy: 90 },
  { sku: "HH-013", category: "household", name: "Mop", unit: "pcs", sell: 220, buy: 175 },
  { sku: "HH-014", category: "household", name: "Garbage bags 10pcs", unit: "pack", sell: 80, buy: 60 },
  { sku: "HH-015", category: "household", name: "Aluminum foil 5m", unit: "pack", sell: 90, buy: 68 },
  { sku: "HH-016", category: "household", name: "Cling film 30m", unit: "pack", sell: 110, buy: 85 },
  { sku: "HH-017", category: "household", name: "Insect spray 400ml", unit: "can", sell: 180, buy: 145 },
  { sku: "HH-018", category: "household", name: "Air freshener 300ml", unit: "can", sell: 150, buy: 118 },
  { sku: "HH-019", category: "household", name: "Batteries AA 4pcs", unit: "pack", sell: 100, buy: 78 },
  { sku: "HH-020", category: "household", name: "Lighter", unit: "pcs", sell: 15, buy: 9 },

  // More Personal Care
  { sku: "PC-009", category: "personal", name: "Face wash 100ml", unit: "tube", sell: 160, buy: 130 },
  { sku: "PC-010", category: "personal", name: "Deodorant 150ml", unit: "can", sell: 180, buy: 145 },
  { sku: "PC-011", category: "personal", name: "Hair oil 100ml", unit: "bottle", sell: 120, buy: 95 },
  { sku: "PC-012", category: "personal", name: "Comb", unit: "pcs", sell: 30, buy: 20 },
  { sku: "PC-013", category: "personal", name: "Nail clipper", unit: "pcs", sell: 40, buy: 28 },
  { sku: "PC-014", category: "personal", name: "Cotton buds 100pcs", unit: "pack", sell: 45, buy: 32 },
  { sku: "PC-015", category: "personal", name: "Tissue box", unit: "pack", sell: 70, buy: 52 },
  { sku: "PC-016", category: "personal", name: "Wet wipes 80pcs", unit: "pack", sell: 90, buy: 68 },
  { sku: "PC-017", category: "personal", name: "Sunscreen 100ml", unit: "tube", sell: 220, buy: 180 },
  { sku: "PC-018", category: "personal", name: "Perfume 50ml", unit: "bottle", sell: 350, buy: 290 },

  // More Dairy & Eggs
  { sku: "DY-006", category: "dairy", name: "Eggs 30pcs", unit: "tray", sell: 480, buy: 420 },
  { sku: "DY-007", category: "dairy", name: "Milk powder 900g", unit: "pack", sell: 650, buy: 560 },
  { sku: "DY-008", category: "dairy", name: "Yogurt 1L", unit: "pack", sell: 150, buy: 120 },
  { sku: "DY-009", category: "dairy", name: "Cream 200ml", unit: "pack", sell: 120, buy: 95 },
  { sku: "DY-010", category: "dairy", name: "Ghee 500g", unit: "jar", sell: 450, buy: 390 },
  { sku: "DY-011", category: "dairy", name: "Laban 500ml", unit: "bottle", sell: 70, buy: 52 },

  // More Bakery
  { sku: "BK-006", category: "bakery", name: "Hamburger bun 4pcs", unit: "pack", sell: 60, buy: 42 },
  { sku: "BK-007", category: "bakery", name: "Cake 500g", unit: "pcs", sell: 320, buy: 240 },
  { sku: "BK-008", category: "bakery", name: "Cookies 250g", unit: "pack", sell: 120, buy: 92 },
  { sku: "BK-009", category: "bakery", name: "Pizza base", unit: "pcs", sell: 70, buy: 50 },
  { sku: "BK-010", category: "bakery", name: "Samosa", unit: "pcs", sell: 20, buy: 12 },
  { sku: "BK-011", category: "bakery", name: "Pastry", unit: "pcs", sell: 35, buy: 22 },

  // Frozen & Fresh
  { sku: "FR-001", category: "frozen", name: "Frozen chicken 1kg", unit: "pack", sell: 420, buy: 350 },
  { sku: "FR-002", category: "frozen", name: "Frozen fish 1kg", unit: "pack", sell: 380, buy: 310 },
  { sku: "FR-003", category: "frozen", name: "Frozen vegetables 500g", unit: "pack", sell: 180, buy: 145 },
  { sku: "FR-004", category: "frozen", name: "Frozen French fries 1kg", unit: "pack", sell: 250, buy: 205 },
  { sku: "FR-005", category: "frozen", name: "Fresh tomatoes 1kg", unit: "kg", sell: 60, buy: 40 },
  { sku: "FR-006", category: "frozen", name: "Fresh onions 1kg", unit: "kg", sell: 45, buy: 30 },
  { sku: "FR-007", category: "frozen", name: "Fresh potatoes 1kg", unit: "kg", sell: 40, buy: 26 },
  { sku: "FR-008", category: "frozen", name: "Fresh bananas 1kg", unit: "kg", sell: 70, buy: 48 },
  { sku: "FR-009", category: "frozen", name: "Fresh oranges 1kg", unit: "kg", sell: 65, buy: 45 },

  // Baby & Kids
  { sku: "BB-001", category: "baby", name: "Diapers medium 20pcs", unit: "pack", sell: 450, buy: 380 },
  { sku: "BB-002", category: "baby", name: "Diapers large 20pcs", unit: "pack", sell: 480, buy: 400 },
  { sku: "BB-003", category: "baby", name: "Baby wipes 80pcs", unit: "pack", sell: 110, buy: 85 },
  { sku: "BB-004", category: "baby", name: "Baby soap 100g", unit: "pcs", sell: 70, buy: 52 },
  { sku: "BB-005", category: "baby", name: "Baby lotion 200ml", unit: "bottle", sell: 180, buy: 145 },
  { sku: "BB-006", category: "baby", name: "Baby powder 200g", unit: "pack", sell: 140, buy: 110 },
  { sku: "BB-007", category: "baby", name: "Baby cereal 250g", unit: "pack", sell: 190, buy: 155 },
  { sku: "BB-008", category: "baby", name: "Feeding bottle 250ml", unit: "pcs", sell: 220, buy: 170 },
  { sku: "BB-009", category: "baby", name: "Baby shampoo 200ml", unit: "bottle", sell: 160, buy: 128 },

  // Home & Kitchen
  { sku: "KT-001", category: "kitchen", name: "Dinner plate", unit: "pcs", sell: 90, buy: 65 },
  { sku: "KT-002", category: "kitchen", name: "Drinking glass", unit: "pcs", sell: 60, buy: 42 },
  { sku: "KT-003", category: "kitchen", name: "Cooking pot 3L", unit: "pcs", sell: 650, buy: 520 },
  { sku: "KT-004", category: "kitchen", name: "Frying pan", unit: "pcs", sell: 480, buy: 380 },
  { sku: "KT-005", category: "kitchen", name: "Kitchen knife", unit: "pcs", sell: 180, buy: 140 },
  { sku: "KT-006", category: "kitchen", name: "Cutting board", unit: "pcs", sell: 150, buy: 115 },
  { sku: "KT-007", category: "kitchen", name: "Water jug 2L", unit: "pcs", sell: 220, buy: 175 },
  { sku: "KT-008", category: "kitchen", name: "Food container 1L", unit: "pcs", sell: 120, buy: 92 },
  { sku: "KT-009", category: "kitchen", name: "Thermos flask 1L", unit: "pcs", sell: 550, buy: 450 },
  { sku: "KT-010", category: "kitchen", name: "Charcoal stove", unit: "pcs", sell: 900, buy: 750 },

  // Electronics & Power
  { sku: "EL-001", category: "electronics", name: "Phone charger", unit: "pcs", sell: 250, buy: 190 },
  { sku: "EL-002", category: "electronics", name: "USB cable", unit: "pcs", sell: 120, buy: 85 },
  { sku: "EL-003", category: "electronics", name: "Earphones", unit: "pcs", sell: 180, buy: 130 },
  { sku: "EL-004", category: "electronics", name: "Power bank 10000mAh", unit: "pcs", sell: 850, buy: 700 },
  { sku: "EL-005", category: "electronics", name: "LED bulb 9W", unit: "pcs", sell: 150, buy: 115 },
  { sku: "EL-006", category: "electronics", name: "Extension cord 3m", unit: "pcs", sell: 320, buy: 250 },
  { sku: "EL-007", category: "electronics", name: "Torch light", unit: "pcs", sell: 220, buy: 170 },
  { sku: "EL-008", category: "electronics", name: "Wall socket", unit: "pcs", sell: 90, buy: 65 },
  { sku: "EL-009", category: "electronics", name: "Phone screen protector", unit: "pcs", sell: 80, buy: 55 },
  { sku: "EL-010", category: "electronics", name: "SIM card adapter", unit: "pack", sell: 30, buy: 18 },

  // Health & First Aid
  { sku: "HL-001", category: "health", name: "Adhesive plasters 20pcs", unit: "pack", sell: 60, buy: 45 },
  { sku: "HL-002", category: "health", name: "Cotton wool 50g", unit: "pack", sell: 35, buy: 24 },
  { sku: "HL-003", category: "health", name: "Antiseptic 100ml", unit: "bottle", sell: 90, buy: 68 },
  { sku: "HL-004", category: "health", name: "Bandage roll", unit: "pcs", sell: 40, buy: 28 },
  { sku: "HL-005", category: "health", name: "Digital thermometer", unit: "pcs", sell: 350, buy: 280 },
  { sku: "HL-006", category: "health", name: "Face masks 10pcs", unit: "pack", sell: 60, buy: 42 },
  { sku: "HL-007", category: "health", name: "Hand gloves 10pcs", unit: "pack", sell: 80, buy: 58 },
  { sku: "HL-008", category: "health", name: "Hot water bag", unit: "pcs", sell: 220, buy: 175 },
  // Extra everyday items
  { sku: "EX-001", category: "grains", name: "Oats 500g", unit: "pack", sell: 120, buy: 95 },
  { sku: "EX-002", category: "cooking", name: "Vinegar 500ml", unit: "bottle", sell: 70, buy: 52 },
  { sku: "EX-003", category: "spices", name: "Ginger powder 100g", unit: "pack", sell: 50, buy: 38 },
  { sku: "EX-004", category: "beverages", name: "Green tea 50g", unit: "pack", sell: 90, buy: 70 },
  { sku: "EX-005", category: "snacks", name: "Biscuits family pack", unit: "pack", sell: 85, buy: 65 },
  { sku: "EX-006", category: "household", name: "Dish soap 500ml", unit: "bottle", sell: 95, buy: 72 },
  { sku: "EX-007", category: "personal", name: "Shampoo 250ml", unit: "bottle", sell: 180, buy: 140 },
  { sku: "EX-008", category: "dairy", name: "Yogurt 500ml", unit: "bottle", sell: 90, buy: 70 },
  { sku: "EX-009", category: "bakery", name: "Cake slice", unit: "pcs", sell: 75, buy: 55 },
  { sku: "EX-010", category: "stationery", name: "Glue stick", unit: "pcs", sell: 45, buy: 32 },
  // ── Ethiopian staples & grains ─────────────────────────────────────────
  { sku: "ET-001", category: "grains", name: "Injera (5 pieces)", unit: "pack", sell: 120, buy: 90 },
  { sku: "ET-002", category: "grains", name: "Teff white 1kg", unit: "kg", sell: 200, buy: 165 },
  { sku: "ET-003", category: "grains", name: "Teff red 1kg", unit: "kg", sell: 190, buy: 155 },
  { sku: "ET-004", category: "grains", name: "Teff mixed 1kg", unit: "kg", sell: 185, buy: 150 },
  { sku: "ET-005", category: "grains", name: "Wheat 1kg", unit: "kg", sell: 90, buy: 72 },
  { sku: "ET-006", category: "grains", name: "Maize 1kg", unit: "kg", sell: 65, buy: 50 },
  { sku: "ET-007", category: "grains", name: "Sorghum 1kg", unit: "kg", sell: 80, buy: 62 },
  { sku: "ET-008", category: "grains", name: "Barley 1kg", unit: "kg", sell: 85, buy: 68 },
  { sku: "ET-009", category: "grains", name: "Oats 1kg", unit: "kg", sell: 150, buy: 120 },
  { sku: "ET-010", category: "grains", name: "Bulgur 1kg", unit: "kg", sell: 140, buy: 112 },
  { sku: "PL-001", category: "grains", name: "Shiro (chickpea flour) 1kg", unit: "kg", sell: 220, buy: 180 },
  { sku: "PL-002", category: "grains", name: "Kik (split peas) 1kg", unit: "kg", sell: 170, buy: 135 },
  { sku: "PL-003", category: "grains", name: "Misir (red lentils) 1kg", unit: "kg", sell: 160, buy: 130 },
  { sku: "PL-004", category: "grains", name: "Bakela (fava beans) 1kg", unit: "kg", sell: 150, buy: 120 },
  { sku: "PL-005", category: "grains", name: "Ater (field peas) 1kg", unit: "kg", sell: 140, buy: 112 },
  { sku: "PL-006", category: "grains", name: "Azuki beans 1kg", unit: "kg", sell: 160, buy: 128 },
  { sku: "PL-007", category: "grains", name: "Black beans 1kg", unit: "kg", sell: 170, buy: 136 },
  { sku: "PL-008", category: "grains", name: "Soya beans 1kg", unit: "kg", sell: 130, buy: 104 },
  // ── Ethiopian spices & berbere ─────────────────────────────────────────
  { sku: "ES-001", category: "spices", name: "Berbere 1kg", unit: "kg", sell: 320, buy: 260 },
  { sku: "ES-002", category: "spices", name: "Berbere 250g", unit: "pack", sell: 90, buy: 72 },
  { sku: "ES-003", category: "spices", name: "Mitmita 100g", unit: "pack", sell: 60, buy: 45 },
  { sku: "ES-004", category: "spices", name: "Awaze 200g", unit: "jar", sell: 75, buy: 58 },
  { sku: "ES-005", category: "spices", name: "Korerima 50g", unit: "pack", sell: 80, buy: 62 },
  { sku: "ES-006", category: "spices", name: "Besobela 50g", unit: "pack", sell: 50, buy: 38 },
  { sku: "ES-007", category: "spices", name: "Tosign 50g", unit: "pack", sell: 45, buy: 34 },
  { sku: "ES-008", category: "spices", name: "Tikur azmud 50g", unit: "pack", sell: 55, buy: 42 },
  { sku: "ES-009", category: "spices", name: "Nech azmud 50g", unit: "pack", sell: 50, buy: 38 },
  { sku: "ES-010", category: "spices", name: "Zingibil (ginger) 100g", unit: "pack", sell: 40, buy: 30 },
  { sku: "ES-011", category: "spices", name: "Garlic 500g", unit: "kg", sell: 90, buy: 70 },
  { sku: "ES-012", category: "spices", name: "Onion 1kg", unit: "kg", sell: 60, buy: 45 },
  { sku: "ES-013", category: "spices", name: "Tomato 1kg", unit: "kg", sell: 70, buy: 52 },
  // ── Cooking essentials ─────────────────────────────────────────────────
  { sku: "CE-001", category: "cooking", name: "Niter kibbeh 500g", unit: "jar", sell: 280, buy: 220 },
  { sku: "CE-002", category: "cooking", name: "Sesame oil 500ml", unit: "bottle", sell: 260, buy: 205 },
  { sku: "CE-003", category: "cooking", name: "Sunflower oil 1L", unit: "l", sell: 290, buy: 245 },
  { sku: "CE-004", category: "cooking", name: "Palm oil 1L", unit: "l", sell: 260, buy: 215 },
  { sku: "CE-005", category: "cooking", name: "Ghee 500g", unit: "jar", sell: 320, buy: 260 },
  { sku: "CE-016", category: "cooking", name: "Vinegar 500ml", unit: "bottle", sell: 70, buy: 52 },
  { sku: "CE-017", category: "cooking", name: "Soy sauce 250ml", unit: "bottle", sell: 95, buy: 72 },
  // ── Beverages ──────────────────────────────────────────────────────────
  { sku: "BV-101", category: "beverages", name: "Coffee beans 500g", unit: "pack", sell: 280, buy: 230 },
  { sku: "BV-102", category: "beverages", name: "Ground coffee 250g", unit: "pack", sell: 150, buy: 120 },
  { sku: "BV-103", category: "beverages", name: "Instant coffee 100g", unit: "jar", sell: 180, buy: 145 },
  { sku: "BV-104", category: "beverages", name: "Black tea 100g", unit: "pack", sell: 70, buy: 55 },
  { sku: "BV-105", category: "beverages", name: "Green tea 50g", unit: "pack", sell: 90, buy: 70 },
  { sku: "BV-106", category: "beverages", name: "Herbal tea (tisane) 50g", unit: "pack", sell: 60, buy: 45 },
  { sku: "BV-114", category: "beverages", name: "Fresh milk 1L", unit: "l", sell: 90, buy: 72 },
  { sku: "BV-115", category: "beverages", name: "Yogurt 500ml", unit: "bottle", sell: 80, buy: 62 },
  // ── Dairy & eggs ───────────────────────────────────────────────────────
  { sku: "DA-001", category: "dairy", name: "Butter 250g", unit: "pack", sell: 180, buy: 145 },
  { sku: "DA-002", category: "dairy", name: "Cheese 200g", unit: "pack", sell: 220, buy: 175 },
  { sku: "DA-003", category: "dairy", name: "Eggs (tray of 30)", unit: "tray", sell: 360, buy: 300 },
  { sku: "DA-004", category: "dairy", name: "Cream 200ml", unit: "bottle", sell: 120, buy: 95 },
  { sku: "DA-005", category: "dairy", name: "Ayib (cottage cheese) 500g", unit: "pack", sell: 150, buy: 120 },
  // ── Bakery & bread ─────────────────────────────────────────────────────
  { sku: "BA-001", category: "bakery", name: "Dabo (bread) loaf", unit: "pcs", sell: 60, buy: 45 },
  { sku: "BA-002", category: "bakery", name: "Ambasha bread", unit: "pcs", sell: 80, buy: 60 },
  { sku: "BA-003", category: "bakery", name: "Kita (flatbread)", unit: "pcs", sell: 40, buy: 30 },
  { sku: "BA-004", category: "bakery", name: "Cake slice", unit: "pcs", sell: 75, buy: 55 },
  // ── Snacks ─────────────────────────────────────────────────────────────
  { sku: "SN-001", category: "snacks", name: "Kolo (roasted barley) 250g", unit: "pack", sell: 80, buy: 60 },
  { sku: "SN-002", category: "snacks", name: "Dabo kolo 200g", unit: "pack", sell: 70, buy: 52 },
  { sku: "SN-003", category: "snacks", name: "Popcorn 200g", unit: "pack", sell: 50, buy: 38 },
  { sku: "SN-004", category: "snacks", name: "Peanuts 250g", unit: "pack", sell: 75, buy: 58 },
  // ── Household ──────────────────────────────────────────────────────────
  { sku: "HH-101", category: "household", name: "Dish soap 500ml", unit: "bottle", sell: 95, buy: 72 },
  { sku: "HH-102", category: "household", name: "Laundry detergent 1kg", unit: "pack", sell: 180, buy: 145 },
  { sku: "HH-103", category: "household", name: "Bleach 1L", unit: "bottle", sell: 80, buy: 60 },
  { sku: "HH-104", category: "household", name: "Toilet paper (4 rolls)", unit: "pack", sell: 120, buy: 95 },
  { sku: "HH-105", category: "household", name: "Tissue box", unit: "box", sell: 70, buy: 52 },
  { sku: "HH-110", category: "household", name: "Charcoal 5kg", unit: "bag", sell: 350, buy: 280 },
  { sku: "HH-111", category: "household", name: "Matchbox 10pcs", unit: "pack", sell: 25, buy: 18 },
  { sku: "HH-112", category: "household", name: "Candles 4pcs", unit: "pack", sell: 40, buy: 30 },
  { sku: "HH-114", category: "household", name: "Batteries AA 4pcs", unit: "pack", sell: 120, buy: 95 },
  { sku: "HH-115", category: "household", name: "Flashlight", unit: "pcs", sell: 250, buy: 195 },
  // ── Personal care ──────────────────────────────────────────────────────
  { sku: "PC-101", category: "personal", name: "Soap bar 100g", unit: "pcs", sell: 35, buy: 25 },
  { sku: "PC-102", category: "personal", name: "Shampoo 250ml", unit: "bottle", sell: 180, buy: 140 },
  { sku: "PC-104", category: "personal", name: "Toothpaste 100ml", unit: "tube", sell: 90, buy: 70 },
  { sku: "PC-105", category: "personal", name: "Toothbrush", unit: "pcs", sell: 60, buy: 45 },
  { sku: "PC-109", category: "personal", name: "Sanitary pads 10pcs", unit: "pack", sell: 90, buy: 70 },
  { sku: "PC-110", category: "personal", name: "Diapers (small) 10pcs", unit: "pack", sell: 250, buy: 200 },
  // ── Baby & kids ────────────────────────────────────────────────────────
  { sku: "BK-001", category: "baby", name: "Baby formula 400g", unit: "can", sell: 480, buy: 400 },
  { sku: "BK-002", category: "baby", name: "Baby cereal 200g", unit: "box", sell: 180, buy: 145 },
  { sku: "BK-003", category: "baby", name: "Baby wipes 80pcs", unit: "pack", sell: 150, buy: 120 },
  // ── Health & first aid ─────────────────────────────────────────────────
  { sku: "HL-101", category: "health", name: "Paracetamol 500mg 10pcs", unit: "pack", sell: 40, buy: 30 },
  { sku: "HL-102", category: "health", name: "Ibuprofen 400mg 10pcs", unit: "pack", sell: 50, buy: 38 },
  { sku: "HL-103", category: "health", name: "ORS sachets 5pcs", unit: "pack", sell: 35, buy: 25 },
  { sku: "HL-109", category: "health", name: "Face masks 10pcs", unit: "pack", sell: 60, buy: 42 },
  { sku: "HL-110", category: "health", name: "Hand sanitizer 250ml", unit: "bottle", sell: 110, buy: 85 },
  // ── Stationery ─────────────────────────────────────────────────────────
  { sku: "ST-101", category: "stationery", name: "Exercise book A4", unit: "pcs", sell: 45, buy: 32 },
  { sku: "ST-102", category: "stationery", name: "Pen (blue) 10pcs", unit: "pack", sell: 60, buy: 45 },
  { sku: "ST-103", category: "stationery", name: "Pencil 10pcs", unit: "pack", sell: 40, buy: 30 },
  { sku: "ST-104", category: "stationery", name: "Eraser 5pcs", unit: "pack", sell: 25, buy: 18 },
  { sku: "ST-107", category: "stationery", name: "Glue stick", unit: "pcs", sell: 45, buy: 32 },
  { sku: "ST-112", category: "stationery", name: "Notebook A5", unit: "pcs", sell: 60, buy: 45 },
  // ── Home & kitchen ─────────────────────────────────────────────────────
  { sku: "HK-001", category: "kitchen", name: "Cooking pot (medium)", unit: "pcs", sell: 450, buy: 360 },
  { sku: "HK-002", category: "kitchen", name: "Frying pan", unit: "pcs", sell: 380, buy: 300 },
  { sku: "HK-003", category: "kitchen", name: "Kettle 2L", unit: "pcs", sell: 320, buy: 250 },
  { sku: "HK-009", category: "kitchen", name: "Thermos 1L", unit: "pcs", sell: 350, buy: 275 },
  // ── Electronics & power ────────────────────────────────────────────────
  { sku: "EL-001", category: "electronics", name: "Phone charger", unit: "pcs", sell: 250, buy: 190 },
  { sku: "EL-002", category: "electronics", name: "USB cable", unit: "pcs", sell: 120, buy: 90 },
  { sku: "EL-005", category: "electronics", name: "LED bulb 9W", unit: "pcs", sell: 80, buy: 60 },
  { sku: "EL-006", category: "electronics", name: "Extension cord 3m", unit: "pcs", sell: 220, buy: 170 },
  // ── Frozen & fresh ─────────────────────────────────────────────────────
  { sku: "FF-001", category: "frozen", name: "Frozen peas 500g", unit: "pack", sell: 120, buy: 95 },
  { sku: "FF-003", category: "frozen", name: "Frozen chicken 1kg", unit: "kg", sell: 380, buy: 310 },
  { sku: "FF-004", category: "frozen", name: "Frozen fish 500g", unit: "pack", sell: 220, buy: 175 },
  { sku: "FF-005", category: "frozen", name: "Ice cream 500ml", unit: "tub", sell: 150, buy: 115 },
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

  // Admin account only — no demo shops. Shops are created by real owners via registration.

  const packages = [
    { code: "pkg_1m", name: "1 Month", months: 1, priceEtb: 200, description: "200 ETB per month.", sortOrder: 1 },
    { code: "pkg_3m", name: "3 Months", months: 3, priceEtb: 600, description: "200 ETB per month.", sortOrder: 2 },
    { code: "pkg_6m", name: "6 Months", months: 6, priceEtb: 1200, description: "200 ETB per month.", sortOrder: 3 },
    { code: "pkg_12m", name: "12 Months", months: 12, priceEtb: 2400, description: "200 ETB per month.", sortOrder: 4 },
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
        nameAm: p.nameAm ?? null,
        unit: p.unit,
        defaultSellingPrice: p.sell,
        defaultBuyingPrice: p.buy,
        active: true,
      },
      create: {
        sku: p.sku,
        categoryId,
        name: p.name,
        nameAm: p.nameAm ?? null,
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
  console.log(`Admin id: ${admin.id}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
