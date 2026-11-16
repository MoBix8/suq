import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
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
  static const _pageSize = 10;

  String _filter = 'ALL';
  List<SupplierOrder> _orders = const [];
  int _page = 1;
  int _total = 0;
  late DateTime _from;
  late DateTime _to;
  bool _loading = true;
  String? _error;

  static const _filters = [
    ('ALL', 'All'),
    ('PENDING', 'Pending'),
    ('ACCEPTED', 'Accepted'),
    ('READY', 'Ready'),
    ('DELIVERED', 'Delivered'),
    ('REJECTED', 'Rejected'),
  ];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _to = DateTime(today.year, today.month, today.day);
    _from = _to.subtract(const Duration(days: 30));
    _load();
  }

  String get _fromIso =>
      DateTime(_from.year, _from.month, _from.day).toUtc().toIso8601String();

  String get _toIso => DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999)
      .toUtc()
      .toIso8601String();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      if (_orders.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiProvider).get(
            '/supplier/orders',
            query: {
              'page': '$_page',
              'pageSize': '$_pageSize',
              if (_filter != 'ALL') 'status': _filter,
              'from': _fromIso,
              'to': _toIso,
            },
          );
      if (!mounted) return;
      final orders = (response['orders'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => SupplierOrder.fromJson(asMap(row)))
          .toList();
      setState(() {
        _orders = orders;
        _total = asInt(response['total']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : error.toString();
      });
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(summaryProvider);
    ref.invalidate(recentOrdersProvider);
    await _load();
  }

  void _selectFilter(String filter) {
    setState(() {
      _filter = filter;
      _page = 1;
    });
    _load();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'Orders between',
      saveText: 'Apply',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _to = DateTime(picked.end.year, picked.end.month, picked.end.day);
      _page = 1;
    });
    await _load();
  }

  Future<void> _openOrder(SupplierOrder order) async {
    await showDialog<void>(
      context: context,
      builder: (_) => OrderDetailDialog(order: order),
    );
    if (!mounted) return;
    ref.invalidate(summaryProvider);
    ref.invalidate(recentOrdersProvider);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(summaryProvider).asData?.value;
    final pending = summary?.pendingOrderCount;

    return RefreshIndicator(
      onRefresh: _refresh,
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
                    subtitle: pending == null
                        ? '$_total order${_total == 1 ? '' : 's'}'
                        : pending == 0
                            ? 'No orders are waiting for review.'
                            : '$pending order${pending == 1 ? '' : 's'} waiting for a delivery quote.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.date_range_rounded,
                        size: 18,
                        color: SupplierColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${formatDate(_from)} – ${formatDate(_to)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: SupplierColors.muted,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _pickRange,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
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
                                    ? 'All ($_total)'
                                    : filter.$2,
                              ),
                              selected: _filter == filter.$1,
                              onSelected: (_) => _selectFilter(filter.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: SupplierColors.danger),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_loading && _orders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_orders.isEmpty)
                    EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: _total == 0
                          ? (_filter == 'ALL'
                              ? 'No orders in this period'
                              : 'Nothing in this filter')
                          : 'Nothing in this filter',
                      message: _total == 0
                          ? 'Orders placed between ${formatDate(_from)} and ${formatDate(_to)} will appear here.'
                          : 'Try a different status filter.',
                    )
                  else ...[
                    for (final order in _orders) ...[
                      _OrderCard(
                        order: order,
                        onOpen: () => _openOrder(order),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _pagination(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagination() {
    final start = (_page - 1) * _pageSize + 1;
    final end = math.min(_page * _pageSize, _total);
    final pages = math.max(1, (_total / _pageSize).ceil());
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: _page > 1
              ? () {
                  setState(() => _page -= 1);
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            '$start–$end of $_total · page $_page of $pages',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: SupplierColors.muted),
          ),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: _page < pages
              ? () {
                  setState(() => _page += 1);
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
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
