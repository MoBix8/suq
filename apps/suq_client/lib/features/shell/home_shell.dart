import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../checkout/checkout_screen.dart';
import '../customers/customers_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../products/products_screen.dart';
import '../orders/orders_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool _syncing = false;

  static const _titles = [
    'Dashboard',
    'New sale',
    'Products',
    'Orders',
    'Customers',
    'Reports',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncNow(showFeedback: false),
    );
  }

  Future<void> _syncNow({bool showFeedback = true}) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final count = await ref.read(syncRepositoryProvider).flush();
      ref.invalidate(pendingSyncProvider);
      ref.invalidate(dashboardProvider);
      if (showFeedback && mounted) {
        showAppSnack(
          context,
          count == 0
              ? 'Everything is up to date.'
              : 'Synced $count change${count == 1 ? '' : 's'}.',
        );
      }
    } catch (error) {
      if (showFeedback && mounted) {
        showAppSnack(context, 'Sync failed: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final entitlement = ref.watch(entitlementProvider).asData?.value;
    final pending = ref.watch(pendingSyncProvider).asData?.value ?? 0;

    final pages = <Widget>[
      DashboardScreen(onStartSale: () => setState(() => _index = 1)),
      const CheckoutScreen(),
      const ProductsScreen(),
      const OrdersScreen(),
      const CustomersScreen(),
      const ReportsScreen(),
    ];

    final body = IndexedStack(index: _index, children: pages);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 34),
            const SizedBox(width: 10),
            Text(_titles[_index]),
          ],
        ),
        actions: [
          if (entitlement?.active == true)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: StatusChip(
                  label: '${entitlement!.daysLeft}d left',
                  color: entitlement.daysLeft <= 5
                      ? AppColors.warning
                      : AppColors.profit,
                  icon: Icons.verified_rounded,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Sync now',
            onPressed: _syncing ? null : () => _syncNow(),
            icon: Badge.count(
              count: pending,
              isLabelVisible: pending > 0,
              child: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
          if (!wide)
            IconButton(
              tooltip: 'Supplier orders',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrdersScreen()),
              ),
              icon: const Icon(Icons.local_shipping_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: AppLogo(size: 38),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard_rounded),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.point_of_sale_outlined),
                      selectedIcon: Icon(Icons.point_of_sale_rounded),
                      label: Text('Sell'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: Text('Products'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.local_shipping_outlined),
                      selectedIcon: Icon(Icons.local_shipping_rounded),
                      label: Text('Orders'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline_rounded),
                      selectedIcon: Icon(Icons.people_rounded),
                      label: Text('Customers'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart_rounded),
                      label: Text('Reports'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index > 3 ? _index - 1 : _index,
              onDestinationSelected: (value) => setState(() => _index = value > 2 ? value + 1 : value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.point_of_sale_outlined),
                  selectedIcon: Icon(Icons.point_of_sale_rounded),
                  label: 'Sell',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2_rounded),
                  label: 'Products',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline_rounded),
                  selectedIcon: Icon(Icons.people_rounded),
                  label: 'Customers',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart_rounded),
                  label: 'Reports',
                ),
              ],
            ),
    );
  }
}
