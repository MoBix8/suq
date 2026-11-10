import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../account/account_screen.dart';
import '../catalog/catalog_screen.dart';
import '../listings/listings_screen.dart';
import '../orders/orders_screen.dart';
import '../overview/overview_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _titles = [
    'Overview',
    'Catalog',
    'Listings',
    'Orders',
    'Account',
  ];

  static const _destinations = [
    (
      icon: Icons.space_dashboard_outlined,
      selected: Icons.space_dashboard_rounded,
      label: 'Overview',
    ),
    (
      icon: Icons.inventory_2_outlined,
      selected: Icons.inventory_2_rounded,
      label: 'Catalog',
    ),
    (
      icon: Icons.sell_outlined,
      selected: Icons.sell_rounded,
      label: 'Listings',
    ),
    (
      icon: Icons.receipt_long_outlined,
      selected: Icons.receipt_long_rounded,
      label: 'Orders',
    ),
    (
      icon: Icons.storefront_outlined,
      selected: Icons.storefront_rounded,
      label: 'Account',
    ),
  ];

  void _go(int index) => setState(() => _index = index);

  Future<void> _logout() async {
    final confirmed = await confirmAction(
      context,
      title: 'Sign out?',
      message:
          'You will need your supplier phone number and PIN to sign in again.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed) return;
    if (!mounted) return;
    await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final businessName =
        session.supplier?.businessName ?? user?.name ?? 'Supplier';

    final pages = <Widget>[
      OverviewScreen(
        onOpenOrders: () => _go(3),
        onOpenCatalog: () => _go(1),
        onOpenListings: () => _go(2),
        onOpenAccount: () => _go(4),
      ),
      const CatalogScreen(),
      const ListingsScreen(),
      const OrdersScreen(),
      const AccountScreen(),
    ];

    final body = IndexedStack(index: _index, children: pages);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SupplierLogo(size: 34),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _titles[_index],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  businessName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: SupplierColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (user != null)
            PopupMenuButton<String>(
              tooltip: 'Supplier account',
              onSelected: (value) {
                if (value == 'account') {
                  _go(4);
                } else if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: SupplierColors.ink,
                        ),
                      ),
                      Text(
                        user.phone,
                        style: const TextStyle(
                          fontSize: 12,
                          color: SupplierColors.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        businessName,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: SupplierColors.seed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'account',
                  child: Row(
                    children: [
                      Icon(Icons.storefront_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Account settings'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Sign out'),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: SupplierColors.seed.withValues(alpha: 0.12),
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: SupplierColors.seed,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: wide
          ? Row(
              children: [
                Container(
                  width: 108,
                  color: Colors.white,
                  child: NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _go,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: Colors.white,
                    indicatorColor: SupplierColors.seed.withValues(alpha: 0.12),
                    selectedIconTheme: const IconThemeData(
                      color: SupplierColors.seed,
                    ),
                    selectedLabelTextStyle: const TextStyle(
                      color: SupplierColors.seed,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: SupplierColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    leading: const Padding(
                      padding: EdgeInsets.fromLTRB(0, 16, 0, 10),
                      child: Column(
                        children: [
                          SupplierLogo(size: 38),
                          SizedBox(height: 6),
                          Text(
                            'SUPPLIER',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: SupplierColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    destinations: [
                      for (final destination in _destinations)
                        NavigationRailDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selected),
                          label: Text(destination.label),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _go,
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selected),
                    label: destination.label,
                  ),
              ],
            ),
    );
  }
}
