import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/order_status.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({
    super.key,
    required this.onOpenOrders,
    required this.onOpenCatalog,
    required this.onOpenListings,
    required this.onOpenAccount,
  });

  final VoidCallback onOpenOrders;
  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenListings;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final listings = ref.watch(listingsProvider);
    final products = ref.watch(productsProvider);
    final profile = ref.watch(profileProvider);

    final error = orders.error ?? listings.error ?? products.error ?? profile.error;
    if (error != null) {
      return ErrorView(
        message: error.toString(),
        onRetry: () {
          ref.invalidate(ordersProvider);
          ref.invalidate(listingsProvider);
          ref.invalidate(productsProvider);
          ref.invalidate(profileProvider);
        },
      );
    }

    final orderList = orders.asData?.value;
    final listingList = listings.asData?.value;
    final productList = products.asData?.value;
    final supplier = profile.asData?.value;

    if (orderList == null ||
        listingList == null ||
        productList == null ||
        supplier == null) {
      return const LoadingView(message: 'Loading your workspace…');
    }

    // The catalog tab shows the shared library; the overview still reports only
    // the products this supplier owns.
    final ownProducts =
        productList.where((product) => product.supplierId == supplier.id).toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ordersProvider);
        ref.invalidate(listingsProvider);
        ref.invalidate(productsProvider);
        ref.invalidate(profileProvider);
        await ref.read(ordersProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroCard(
                    supplier: supplier,
                    pendingOrders:
                        orderList.where((order) => order.isPending).length,
                    activeListings:
                        listingList.where((listing) => listing.active).length,
                    productCount: ownProducts.length,
                    onOpenOrders: onOpenOrders,
                  ),
                  const SizedBox(height: 18),
                  _StatsGrid(
                    orders: orderList,
                    listings: listingList,
                    products: ownProducts,
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      final recent = _RecentOrders(
                        orders: orderList,
                        onOpenOrders: onOpenOrders,
                      );
                      final side = _SidePanel(
                        supplier: supplier,
                        onOpenAccount: onOpenAccount,
                        onOpenCatalog: onOpenCatalog,
                        onOpenListings: onOpenListings,
                      );
                      if (!wide) {
                        return Column(
                          children: [
                            recent,
                            const SizedBox(height: 18),
                            side,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: recent),
                          const SizedBox(width: 18),
                          Expanded(flex: 4, child: side),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.supplier,
    required this.pendingOrders,
    required this.activeListings,
    required this.productCount,
    required this.onOpenOrders,
  });

  final SupplierProfile supplier;
  final int pendingOrders;
  final int activeListings;
  final int productCount;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SupplierColors.deep, SupplierColors.seed, SupplierColors.bright],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 640;
              final summary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SupplierLogo(size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplier.businessName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Supplier workspace',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    pendingOrders == 0
                        ? 'All caught up. No orders waiting for review.'
                        : '$pendingOrders shop order${pendingOrders == 1 ? '' : 's'} waiting for your review.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: wide ? 15.5 : 14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroPill(
                        icon: Icons.sell_outlined,
                        label: '$activeListings active listings',
                      ),
                      _HeroPill(
                        icon: Icons.inventory_2_outlined,
                        label: '$productCount catalog products',
                      ),
                      _HeroPill(
                        icon: supplier.hasLocation
                            ? Icons.place_rounded
                            : Icons.location_off_outlined,
                        label: supplier.hasLocation
                            ? 'Location ready'
                            : 'Location not set',
                      ),
                    ],
                  ),
                ],
              );
              final action = FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: SupplierColors.seed,
                ),
                onPressed: onOpenOrders,
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('Review orders'),
              );

              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [summary, const SizedBox(height: 18), action],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 18),
                  action,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.orders,
    required this.listings,
    required this.products,
  });

  final List<SupplierOrder> orders;
  final List<SupplierListing> listings;
  final List<SupplierProduct> products;

  @override
  Widget build(BuildContext context) {
    final pending = orders.where((order) => order.isPending).length;
    final activeListings = listings.where((listing) => listing.active).length;
    final delivered = orders.where((order) => order.status == 'DELIVERED').length;

    final cards = [
      StatCard(
        label: 'Orders to review',
        value: '$pending',
        icon: Icons.hourglass_top_rounded,
        color: SupplierColors.warning,
        subtitle: 'Waiting for a delivery quote',
      ),
      StatCard(
        label: 'Active listings',
        value: '$activeListings',
        icon: Icons.sell_rounded,
        color: SupplierColors.seed,
        subtitle: '${listings.length} listing${listings.length == 1 ? '' : 's'} in total',
      ),
      StatCard(
        label: 'Catalog products',
        value: '${products.length}',
        icon: Icons.inventory_2_rounded,
        color: SupplierColors.bright,
        subtitle: 'Retail products for shop libraries',
      ),
      StatCard(
        label: 'Delivered orders',
        value: '$delivered',
        icon: Icons.local_shipping_rounded,
        color: SupplierColors.success,
        subtitle: 'Completed all time',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 980
            ? 4
            : width >= 640
                ? 2
                : 1;
        const spacing = 12.0;
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(width: itemWidth, child: card),
          ],
        );
      },
    );
  }
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders({required this.orders, required this.onOpenOrders});

  final List<SupplierOrder> orders;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    final open = orders.where((order) => order.isOpen).toList()
      ..sort((a, b) {
        if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    final preview = open.take(4).toList();

    return SectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Orders needing attention',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: SupplierColors.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: onOpenOrders,
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (preview.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text(
                  'No open orders right now.',
                  style: TextStyle(color: SupplierColors.muted),
                ),
              ),
            )
          else
            for (var i = 0; i < preview.length; i++) ...[
              if (i > 0) const Divider(height: 22),
              _OrderRow(order: preview[i]),
            ],
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final SupplierOrder order;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: orderStatusColor(order.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            orderStatusIcon(order.status),
            size: 18,
            color: orderStatusColor(order.status),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.shop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: SupplierColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${order.items.length} item${order.items.length == 1 ? '' : 's'} · ${formatDate(order.createdAt)}',
                style: const TextStyle(
                  color: SupplierColors.muted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(order.total),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: SupplierColors.ink,
              ),
            ),
            const SizedBox(height: 3),
            StatusChip(
              label: order.statusLabel,
              color: orderStatusColor(order.status),
            ),
          ],
        ),
      ],
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.supplier,
    required this.onOpenAccount,
    required this.onOpenCatalog,
    required this.onOpenListings,
  });

  final SupplierProfile supplier;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenListings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Delivery profile',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SupplierColors.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenAccount,
                    child: const Text('Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              KeyValueRow(
                label: 'Base fee',
                value: money(supplier.deliveryBaseFee),
              ),
              KeyValueRow(
                label: 'Per kilometre',
                value: money(supplier.deliveryPerKm),
              ),
              KeyValueRow(
                label: 'Per kilogram',
                value: money(supplier.deliveryPerKg),
              ),
              KeyValueRow(
                label: 'Per cubic metre',
                value: money(supplier.deliveryPerCubicMeter),
              ),
              KeyValueRow(
                label: 'Pickup location',
                value: supplier.hasLocation ? 'Set' : 'Not set',
                valueColor: supplier.hasLocation
                    ? SupplierColors.success
                    : SupplierColors.warning,
                bold: true,
              ),
              const SizedBox(height: 10),
              if (!supplier.hasLocation)
                const InfoBanner(
                  icon: Icons.location_on_outlined,
                  color: SupplierColors.warning,
                  message:
                      'Add your latitude and longitude so shops get automatic distance-based delivery quotes.',
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Quick actions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: SupplierColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onOpenCatalog,
                icon: const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('Add a catalog product'),
              ),
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: onOpenListings,
                icon: const Icon(Icons.sell_outlined, size: 18),
                label: const Text('Publish a listing'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
