import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/payment_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.onOpenPayments});

  final VoidCallback? onOpenPayments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return AsyncValueView<AdminDashboard>(
      value: dashboard,
      onRetry: () => ref.invalidate(dashboardProvider),
      loadingMessage: 'Loading dashboard…',
      builder: (data) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          await ref.read(dashboardProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _Header(
              serverTime: data.serverTime,
              onRefresh: () => ref.invalidate(dashboardProvider),
            ),
            const SizedBox(height: 18),
            _StatsGrid(stats: data.stats),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 940;
                final expiring = _ExpiringPanel(shops: data.expiring);
                final recent = _RecentPayments(
                  payments: data.recentPayments,
                  onViewAll: onOpenPayments,
                );
                if (!wide) {
                  return Column(
                    children: [
                      expiring,
                      const SizedBox(height: 18),
                      recent,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: expiring),
                    const SizedBox(width: 18),
                    Expanded(flex: 5, child: recent),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.serverTime, required this.onRefresh});

  final DateTime serverTime;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Service overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Server time ${formatDateTime(serverTime)} · all dates are authoritative',
                style: const TextStyle(fontSize: 12.5, color: AdminColors.muted),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1080
            ? 5
            : width >= 800
                ? 3
                : width >= 480
                    ? 2
                    : 1;
        const spacing = 12.0;
        final itemWidth = (width - spacing * (columns - 1)) / columns;

        final cards = [
          StatCard(
            label: 'Total shops',
            value: '${stats.totalShops}',
            subtitle: '${stats.activeShops} active subscription${stats.activeShops == 1 ? '' : 's'}',
            icon: Icons.storefront_rounded,
            color: AdminColors.seed,
          ),
          StatCard(
            label: 'Pending payments',
            value: '${stats.pendingPayments}',
            subtitle: stats.pendingPayments == 0 ? 'Nothing to review' : 'Waiting for approval',
            icon: Icons.pending_actions_rounded,
            color: stats.pendingPayments == 0 ? AdminColors.success : AdminColors.warning,
          ),
          StatCard(
            label: 'Approved revenue',
            value: moneyCompact(stats.revenueEtb),
            subtitle: '${stats.totalPayments} payment${stats.totalPayments == 1 ? '' : 's'} received',
            icon: Icons.payments_rounded,
            color: AdminColors.success,
          ),
          StatCard(
            label: 'Expiring in 7 days',
            value: '${stats.expiringSoon}',
            subtitle: stats.expiringSoon == 0 ? 'No renewals due' : 'Follow up with these shops',
            icon: Icons.event_busy_rounded,
            color: stats.expiringSoon == 0 ? AdminColors.seed : AdminColors.danger,
          ),
          StatCard(
            label: 'Active shops',
            value: '${stats.activeShops}',
            subtitle: 'Paid and inside their term',
            icon: Icons.verified_rounded,
            color: const Color(0xFF0E7490),
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: itemWidth, child: card),
          ],
        );
      },
    );
  }
}

class _ExpiringPanel extends StatelessWidget {
  const _ExpiringPanel({required this.shops});

  final List<ExpiringShop> shops;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.event_busy_rounded,
            title: 'Renewals due soon',
            subtitle: 'Subscriptions ending within 7 days',
          ),
          const SizedBox(height: 14),
          if (shops.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  'No subscriptions are expiring this week.',
                  style: TextStyle(color: AdminColors.muted, fontSize: 12.5),
                ),
              ),
            )
          else
            for (var i = 0; i < shops.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              _ExpiringRow(shop: shops[i]),
            ],
        ],
      ),
    );
  }
}

class _ExpiringRow extends StatelessWidget {
  const _ExpiringRow({required this.shop});

  final ExpiringShop shop;

  @override
  Widget build(BuildContext context) {
    final days = shop.endsAt == null
        ? 0
        : shop.endsAt!.difference(DateTime.now()).inMinutes / (60 * 24);
    final color = days <= 2 ? AdminColors.danger : AdminColors.warning;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.storefront_rounded, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shop.shopName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${shop.ownerName} · ${shop.phone}',
                style: const TextStyle(fontSize: 11.5, color: AdminColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                '${shop.packageName} · ends ${shop.endsAt == null ? '—' : formatDate(shop.endsAt!)}',
                style: const TextStyle(fontSize: 11.5, color: AdminColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        StatusChip(label: daysLeftLabel(shop.endsAt), color: color),
      ],
    );
  }
}

class _RecentPayments extends StatelessWidget {
  const _RecentPayments({required this.payments, this.onViewAll});

  final List<PaymentRecord> payments;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _PanelTitle(
                  icon: Icons.receipt_long_rounded,
                  title: 'Recent payments',
                  subtitle: 'Latest bank transfers submitted by shops',
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View queue'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (payments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  'No payments have been submitted yet.',
                  style: TextStyle(color: AdminColors.muted, fontSize: 12.5),
                ),
              ),
            )
          else
            for (var i = 0; i < payments.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              PaymentTile(payment: payments[i], compact: true),
            ],
        ],
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AdminColors.seed),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: AdminColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
