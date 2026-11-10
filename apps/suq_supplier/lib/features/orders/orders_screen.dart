import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/order_status.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import 'order_detail_dialog.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _filter = 'ALL';

  static const _filters = [
    ('ALL', 'All'),
    ('PENDING', 'Pending'),
    ('ACCEPTED', 'Accepted'),
    ('READY', 'Ready'),
    ('DELIVERED', 'Delivered'),
    ('REJECTED', 'Rejected'),
  ];

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return AsyncValueView<List<SupplierOrder>>(
      value: ordersAsync,
      onRetry: () => ref.invalidate(ordersProvider),
      loadingMessage: 'Loading shop orders…',
      builder: (orders) {
        final pending = orders.where((order) => order.isPending).length;
        final filtered = _filter == 'ALL'
            ? orders
            : orders.where((order) => order.status == _filter).toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ordersProvider);
            await ref.read(ordersProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PageHeader(
                        title: 'Shop orders',
                        subtitle: pending == 0
                            ? 'No orders are waiting for review.'
                            : '$pending order${pending == 1 ? '' : 's'} waiting for a delivery quote.',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final filter in _filters)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    filter.$1 == 'ALL'
                                        ? 'All (${orders.length})'
                                        : '${filter.$2} (${orders.where((o) => o.status == filter.$1).length})',
                                  ),
                                  selected: _filter == filter.$1,
                                  onSelected: (_) =>
                                      setState(() => _filter = filter.$1),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (filtered.isEmpty)
                        EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: orders.isEmpty
                              ? 'No orders yet'
                              : 'Nothing in this filter',
                          message: orders.isEmpty
                              ? 'When a shop orders one of your listings it will appear here.'
                              : 'Try a different status filter.',
                        )
                      else
                        for (final order in filtered) ...[
                          _OrderCard(
                            order: order,
                            onOpen: () => showDialog<void>(
                              context: context,
                              builder: (_) => OrderDetailDialog(order: order),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onOpen});

  final SupplierOrder order;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(order.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: SectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(orderStatusIcon(order.status), color: color, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.shop.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: SupplierColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatDate(order.createdAt)} · ${order.shop.location}',
                          style: const TextStyle(
                            color: SupplierColors.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(
                    label: orderStatusLabel(order.status),
                    color: color,
                    icon: orderStatusIcon(order.status),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                order.items
                    .take(2)
                    .map((item) =>
                        '${item.quantity} × ${item.listingName}')
                    .join('  ·  '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: SupplierColors.ink,
                  height: 1.35,
                ),
              ),
              if (order.items.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '+ ${order.items.length - 2} more item${order.items.length - 2 == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: SupplierColors.muted,
                    ),
                  ),
                ),
              if ((order.acceptedByName ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Accepted by ${order.acceptedByName}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: SupplierColors.muted,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(
                          label: order.deliveryQuoted
                              ? 'Delivery quoted'
                              : 'Quote needed',
                          color: order.deliveryQuoted
                              ? SupplierColors.success
                              : SupplierColors.warning,
                          icon: order.deliveryQuoted
                              ? Icons.check_rounded
                              : Icons.pending_actions_rounded,
                        ),
                        Text(
                          order.deliveryDistanceKm == null
                              ? 'Distance unknown'
                              : distanceLabel(order.deliveryDistanceKm),
                          style: const TextStyle(
                            fontSize: 11,
                            color: SupplierColors.muted,
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
                          fontSize: 15,
                          color: SupplierColors.ink,
                        ),
                      ),
                      Text(
                        'incl. ${money(order.deliveryFee)} delivery',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: SupplierColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: SupplierColors.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
