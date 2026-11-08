import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'banks_tab.dart';
import 'packages_tab.dart';

class BillingSettingsScreen extends StatelessWidget {
  const BillingSettingsScreen({super.key});

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
                  'Billing settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Manage shop subscription packages and receiving bank accounts.',
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
              Tab(
                icon: Icon(Icons.account_balance_outlined, size: 20),
                text: 'Bank accounts',
              ),
            ],
          ),
          const Expanded(
            child: TabBarView(children: [PackagesTab(), BanksTab()]),
          ),
        ],
      ),
    );
  }
}
