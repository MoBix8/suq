import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'categories_tab.dart';
import 'products_tab.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your catalog',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: SupplierColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'The same retail product library shops browse in the client app. Wholesale listings are separate offers.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: SupplierColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.symmetric(horizontal: 12),
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined, size: 20), text: 'Products'),
              Tab(icon: Icon(Icons.category_outlined, size: 20), text: 'Categories'),
            ],
          ),
          const Expanded(
            child: TabBarView(children: [ProductsTab(), CategoriesTab()]),
          ),
        ],
      ),
    );
  }
}
