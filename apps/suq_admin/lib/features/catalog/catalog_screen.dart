import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'banks_tab.dart';
import 'categories_tab.dart';
import 'packages_tab.dart';
import 'products_tab.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catalog & billing settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Packages, receiving accounts, and the shared product library that shops download.',
                  style: TextStyle(fontSize: 12.5, color: AdminColors.muted),
                ),
              ],
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.symmetric(horizontal: 12),
            tabs: [
              Tab(icon: Icon(Icons.sell_outlined, size: 20), text: 'Packages'),
              Tab(icon: Icon(Icons.account_balance_outlined, size: 20), text: 'Bank accounts'),
              Tab(icon: Icon(Icons.category_outlined, size: 20), text: 'Categories'),
              Tab(icon: Icon(Icons.inventory_2_outlined, size: 20), text: 'Products'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                PackagesTab(),
                BanksTab(),
                CategoriesTab(),
                ProductsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
