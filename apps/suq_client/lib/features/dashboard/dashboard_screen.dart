import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../sales/sales_history_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.onStartSale});

  final VoidCallback? onStartSale;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final dashboard = ref.watch(dashboardProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        await ref.read(dashboardProvider.future);
      },
      child: AsyncValueView<DashboardData>(
        value: dashboard,
        loadingMessage: 'Reading today’s sales…',
        onRetry: () => ref.invalidate(dashboardProvider),
        builder: (data) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Greeting(
                        greeting: _greeting(),
                        name: session.user?.name.split(' ').first ?? 'owner',
                        shopName: session.shop?.name ?? 'Your shop',
                        onStartSale: onStartSale,
                      ),
                      const SizedBox(height: 18),
                      _StatsGrid(summary: data.today),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 820;
                          final chart = SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Last 7 days',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${data.last7.fold<int>(0, (sum, point) => sum + point.count)} sales',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _SalesBarChart(points: data.last7),
                              ],
                            ),
                          );

                          final credit = SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Outstanding credit',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  money(data.outstandingCredit),
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.warning,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${data.customerCount} customers registered',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 17,
                                        color: AppColors.warning,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Credit given today: see the cards above. Open Customers to record a repayment.',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            height: 1.35,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (!wide) {
                            return Column(
                              children: [
                                chart,
                                const SizedBox(height: 14),
                                credit,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: chart),
                              const SizedBox(width: 14),
                              Expanded(child: credit),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 820;
                          final top = SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Top products today',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (data.topToday.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 18),
                                    child: Text(
                                      'No sales yet today.',
                                      style: TextStyle(color: AppColors.muted),
                                    ),
                                  )
                                else
                                  ...data.topToday.map(
                                    (product) => _TopProductRow(product: product),
                                  ),
                              ],
                            ),
                          );

                          final lowStock = SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Low stock',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${data.lowStock.length}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (data.lowStock.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 18),
                                    child: Text(
                                      'Nothing is running low.',
                                      style: TextStyle(color: AppColors.muted),
                                    ),
                                  )
                                else
                                  ...data.lowStock.take(5).map(
                                        (product) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.warning_amber_rounded,
                                                size: 17,
                                                color: AppColors.warning,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  product.name,
                                                  style: const TextStyle(fontSize: 13),
                                                ),
                                              ),
                                              Text(
                                                '${qty(product.stockQty)} ${product.unit}',
                                                style: const TextStyle(
                                                  color: AppColors.warning,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          );

                          if (!wide) {
                            return Column(
                              children: [
                                top,
                                const SizedBox(height: 14),
                                lowStock,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: top),
                              const SizedBox(width: 14),
                              Expanded(child: lowStock),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Recent sales',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${data.today.salesCount} today',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SalesHistoryScreen(),
                                    ),
                                  ),
                                  child: const Text('View all'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (data.recentSales.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: Text(
                                  'Your first sale will appear here.',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              )
                            else
                              ...data.recentSales.map(
                                (sale) => _RecentSaleRow(sale: sale),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.greeting,
    required this.name,
    required this.shopName,
    this.onStartSale,
  });

  final String greeting;
  final String name;
  final String shopName;
  final VoidCallback? onStartSale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $name',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$shopName • ${formatDate(DateTime.now())}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        if (onStartSale != null)
          FilledButton.icon(
            onPressed: onStartSale,
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 19),
            label: const Text('New sale'),
          ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900 ? 4 : 2;
        final spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cards = [
          StatCard(
            label: 'Sales today',
            value: money(summary.revenue),
            icon: Icons.payments_rounded,
            color: AppColors.seed,
            subtitle: '${summary.salesCount} transaction${summary.salesCount == 1 ? '' : 's'}',
          ),
          StatCard(
            label: 'Profit today',
            value: money(summary.profit),
            icon: Icons.trending_up_rounded,
            color: summary.profit >= 0 ? AppColors.profit : AppColors.loss,
            subtitle: summary.hasEstimatedProfit
                ? 'Estimated — some costs missing'
                : 'Margin ${percent(summary.margin)}',
          ),
          StatCard(
            label: 'Cash collected',
            value: money(summary.cashCollected),
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF2E5EAA),
            subtitle: 'Includes partial payments',
          ),
          StatCard(
            label: 'Credit given',
            value: money(summary.creditGiven),
            icon: Icons.handshake_rounded,
            color: AppColors.warning,
            subtitle: 'Unpaid part of today’s sales',
          ),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }
}

class _SalesBarChart extends StatelessWidget {
  const _SalesBarChart({required this.points});

  final List<DailyPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxRevenue = points.fold<double>(0, (max, point) => math.max(max, point.revenue));
    return SizedBox(
      height: 185,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((point) {
          final height = maxRevenue <= 0 ? 6.0 : 8 + (point.revenue / maxRevenue) * 110;
          final isToday = point.day.day == DateTime.now().day;
          return Expanded(
            child: Tooltip(
              message: '${money(point.revenue)} • ${point.count} sales',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 22,
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: isToday
                            ? [AppColors.seed, const Color(0xFF2DBB88)]
                            : [AppColors.seed.withValues(alpha: 0.25), AppColors.seed.withValues(alpha: 0.6)],
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatWeekday(point.day),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isToday ? AppColors.seed : AppColors.muted,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    point.revenue <= 0 ? '—' : moneyCompact(point.revenue),
                    style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({required this.product});

  final TopProduct product;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.seed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              product.name.characters.first.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.seed,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${qty(product.qty)} sold',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            money(product.revenue),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RecentSaleRow extends StatelessWidget {
  const _RecentSaleRow({required this.sale});

  final SaleRecord sale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (sale.credit > 0 ? AppColors.warning : AppColors.profit)
                  .withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              sale.credit > 0 ? Icons.schedule_rounded : Icons.check_rounded,
              size: 18,
              color: sale.credit > 0 ? AppColors.warning : AppColors.profit,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.customerName ?? 'Walk-in customer',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${sale.receiptNo} • ${formatTime(sale.soldAt)}'
                  '${sale.returned ? ' • Returned' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(sale.total),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              if (sale.credit > 0)
                Text(
                  '${money(sale.credit)} credit',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.warning),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
