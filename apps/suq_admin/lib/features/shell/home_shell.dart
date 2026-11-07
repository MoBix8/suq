import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../dashboard/dashboard_screen.dart';
import '../payments/payments_screen.dart';
import '../settings/settings_screen.dart';
import '../shops/shops_screen.dart';
import '../suppliers/suppliers_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _titles = ['Dashboard', 'Payments', 'Shops', 'Suppliers'];

  static const _destinations = [
    (
      icon: Icons.space_dashboard_outlined,
      selected: Icons.space_dashboard_rounded,
      label: 'Dashboard',
    ),
    (
      icon: Icons.receipt_long_outlined,
      selected: Icons.receipt_long_rounded,
      label: 'Payments',
    ),
    (
      icon: Icons.storefront_outlined,
      selected: Icons.storefront_rounded,
      label: 'Shops',
    ),
    (
      icon: Icons.local_shipping_outlined,
      selected: Icons.local_shipping_rounded,
      label: 'Suppliers',
    ),
  ];

  Future<void> _logout() async {
    final confirmed = await confirmAction(
      context,
      title: 'Sign out?',
      message:
          'You will need your administrator phone number and PIN to sign in again.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed) return;
    ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final user = ref.watch(sessionProvider).user;

    final pages = <Widget>[
      DashboardScreen(onOpenPayments: () => setState(() => _index = 1)),
      const PaymentsScreen(),
      const ShopsScreen(),
      const SuppliersScreen(),
    ];

    final body = IndexedStack(index: _index, children: pages);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AdminLogo(size: 34),
            const SizedBox(width: 10),
            Text(_titles[_index]),
          ],
        ),
        actions: [
          if (user != null)
            PopupMenuButton<String>(
              tooltip: 'Account',
              onSelected: (value) {
                if (value == 'settings') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
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
                          color: AdminColors.ink,
                        ),
                      ),
                      Text(
                        user.phone,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AdminColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Settings'),
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: AdminColors.seed.withValues(alpha: 0.12),
                  child: Text(
                    _initials(user.name),
                    style: const TextStyle(
                      color: AdminColors.seed,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 10),
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
                    child: AdminLogo(size: 38),
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
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
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

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    if (parts.isEmpty) return 'A';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}
