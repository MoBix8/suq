import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _days = 7;

  Future<void> _refresh() async {
    ref.invalidate(reportProvider(_days));
    await ref.read(reportProvider(_days).future);
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(reportProvider(_days));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: AsyncValueView<SalesReport>(
        value: report,
        loadingMessage: 'Building your report…',
        onRetry: () => ref.invalidate(reportProvider(_days)),
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
                      _RangeSelector(
                        days: _days,
                        rangeLabel:
                            '${formatDate(data.from)} – ${formatDate(data.to)}',
                        onChanged: (days) => setState(() => _days = days),
                      ),
                      const SizedBox(height: 16),
                      _SummaryGrid(summary: data.summary),
                      const SizedBox(height: 16),
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
                                      'Sales & profit trend',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    const _LegendDot(
                                      color: AppColors.seed,
                                      label: 'Sales',
                                    ),
                                    const SizedBox(width: 10),
                                    const _LegendDot(
                                      color: AppColors.accent,
                                      label: 'Profit',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _TrendChart(points: data.daily, days: _days),
                              ],
                            ),
                          );
                          final profit = _ProfitLossCard(summary: data.summary);
                          if (!wide) {
                            return Column(
                              children: [
                                chart,
                                const SizedBox(height: 14),
                                profit,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: chart),
                              const SizedBox(width: 14),
                              Expanded(flex: 2, child: profit),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 820;
                          final top = _TopProductsCard(products: data.top);
                          final side = Column(
                            children: [
                              _CreditCard(
                                outstanding: data.outstandingCredit,
                                customers: data.customerCount,
                              ),
                              const SizedBox(height: 14),
                              _LowStockCard(products: data.lowStock),
                            ],
                          );
                          if (!wide) {
                            return Column(
                              children: [
                                top,
                                const SizedBox(height: 14),
                                side,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: top),
                              const SizedBox(width: 14),
                              Expanded(flex: 2, child: side),
                            ],
                          );
                        },
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

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.days,
    required this.rangeLabel,
    required this.onChanged,
  });

  final int days;
  final String rangeLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const ranges = [(1, 'Today'), (7, '7 days'), (30, '30 days')];

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Report range',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  rangeLabel,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ranges
                .map(
                  (range) => ChoiceChip(
                    label: Text(range.$2),
                    selected: days == range.$1,
                    onSelected: (_) => onChanged(range.$1),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900 ? 4 : 2;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cards = [
          StatCard(
            label: 'Sales',
            value: money(summary.revenue),
            icon: Icons.payments_rounded,
            color: AppColors.seed,
            subtitle:
                '${summary.salesCount} transaction${summary.salesCount == 1 ? '' : 's'}',
          ),
          StatCard(
            label: 'Cost of goods',
            value: money(summary.cost),
            icon: Icons.shopping_bag_outlined,
            color: const Color(0xFF2E5EAA),
            subtitle: summary.hasEstimatedProfit
                ? 'Some buying prices missing'
                : 'Based on buying prices',
          ),
          StatCard(
            label: 'Profit',
            value: money(summary.profit),
            icon: Icons.trending_up_rounded,
            color: summary.profit >= 0 ? AppColors.profit : AppColors.loss,
            subtitle: 'Margin ${percent(summary.margin)}',
          ),
          StatCard(
            label: 'Credit given',
            value: money(summary.creditGiven),
            icon: Icons.handshake_outlined,
            color: AppColors.warning,
            subtitle: 'Unpaid part of these sales',
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

class _ProfitLossCard extends StatelessWidget {
  const _ProfitLossCard({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Profit & loss',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          KeyValueRow(label: 'Revenue', value: money(summary.revenue)),
          KeyValueRow(
            label: 'Cost of goods sold',
            value: '- ${money(summary.cost)}',
            valueColor: AppColors.muted,
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Text(
                'Net profit',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                money(summary.profit),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: summary.profit >= 0 ? AppColors.profit : AppColors.loss,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Margin ${percent(summary.margin)}',
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
          const Divider(height: 20),
          KeyValueRow(
            label: 'Cash collected',
            value: money(summary.cashCollected),
            valueColor: AppColors.profit,
          ),
          KeyValueRow(
            label: 'Credit given',
            value: money(summary.creditGiven),
            valueColor: AppColors.warning,
          ),
          if (summary.hasEstimatedProfit) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${summary.missingCostItems} sold item${summary.missingCostItems == 1 ? '' : 's'} '
                      'have no buying price, so profit is slightly overestimated. '
                      'Add buying prices in Products for exact numbers.',
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points, required this.days});

  final List<DailyPoint> points;
  final int days;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<double>(
      0,
      (value, point) => math.max(value, math.max(point.revenue, point.profit)),
    );
    final barWidth = days <= 7 ? 14.0 : 8.0;
    final showEvery = days <= 7 ? 1 : (days <= 30 ? 5 : 10);

    double heightFor(double value) {
      if (maxValue <= 0) return 4;
      return math.max(3, (value / maxValue) * 140);
    }

    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.asMap().entries.map((entry) {
          final index = entry.key;
          final point = entry.value;
          final showLabel =
              index % showEvery == 0 || index == points.length - 1;

          return Expanded(
            child: Tooltip(
              message:
                  '${formatDate(point.day)}\nSales: ${money(point.revenue)}\n'
                  'Profit: ${money(point.profit)}\n${point.count} sale${point.count == 1 ? '' : 's'}',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: barWidth,
                        height: heightFor(point.revenue),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [AppColors.seed, Color(0xFF2DBB88)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Container(
                        width: barWidth,
                        height: heightFor(point.profit),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  SizedBox(
                    height: 14,
                    child: Text(
                      showLabel ? formatDayMonth(point.day) : '',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.muted,
                      ),
                    ),
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

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.products});

  final List<TopProduct> products;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Top products',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  'No sales in this period.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            ...products.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index < 3
                            ? AppColors.accent.withValues(alpha: 0.18)
                            : AppColors.seed.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: index < 3 ? AppColors.warning : AppColors.muted,
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
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${qty(product.qty)} sold',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.muted,
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
                          money(product.revenue),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${money(product.profit)} profit',
                          style: TextStyle(
                            fontSize: 10,
                            color: product.profit >= 0
                                ? AppColors.profit
                                : AppColors.loss,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.outstanding, required this.customers});

  final double outstanding;
  final int customers;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Outstanding credit',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            money(outstanding),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.warning,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            'Across $customers registered customer${customers == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          const Text(
            'Open the Customers tab to record a repayment. Credit does not count as cash until it is collected.',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Low stock',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${products.length}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Nothing is running low.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            ...products.take(8).map(
                  (product) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        Text(
                          '${qty(product.stockQty)} ${product.unit}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
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
