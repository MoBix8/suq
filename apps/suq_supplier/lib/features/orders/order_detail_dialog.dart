import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/order_status.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class OrderDetailDialog extends ConsumerStatefulWidget {
  const OrderDetailDialog({super.key, required this.order});

  final SupplierOrder order;

  @override
  ConsumerState<OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends ConsumerState<OrderDetailDialog> {
  late String _status;
  late bool _quoted;
  late double _deliveryFee;
  late final TextEditingController _fee;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = widget.order.status;
    _quoted = widget.order.deliveryQuoted;
    _deliveryFee = widget.order.deliveryFee;
    _fee = TextEditingController(text: _deliveryFee.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  Future<void> _saveQuote() async {
    final fee = double.tryParse(_fee.text.trim());
    if (fee == null || fee < 0) {
      showAppSnack(context, 'Enter a valid delivery fee.', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).patch(
        '/supplier/orders/${widget.order.id}/delivery',
        body: {'deliveryFee': fee},
      );
      if (!mounted) return;
      ref.invalidate(ordersProvider);
      setState(() {
        _deliveryFee = fee;
        _quoted = true;
      });
      showAppSnack(context, 'Delivery quote saved.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    if (status == 'REJECTED') {
      final confirmed = await confirmAction(
        context,
        title: 'Reject this order?',
        message:
            '${widget.order.shop.name} will be told the order cannot be fulfilled.',
        confirmLabel: 'Reject order',
        destructive: true,
      );
      if (!confirmed) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).patch(
        '/supplier/orders/${widget.order.id}/status',
        body: {'status': status},
      );
      if (!mounted) return;
      ref.invalidate(ordersProvider);
      setState(() => _status = status);
      showAppSnack(context, 'Order moved to ${orderStatusLabel(status)}.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final color = orderStatusColor(_status);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 660, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 10, 16),
              decoration: const BoxDecoration(
                color: SupplierColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(orderStatusIcon(_status), color: color, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.shop.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: SupplierColors.ink,
                          ),
                        ),
                        Text(
                          'Order ${formatDateTime(order.createdAt)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: SupplierColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: orderStatusLabel(_status),
                    color: color,
                    icon: orderStatusIcon(_status),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            size: 19,
                            color: SupplierColors.seed,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.shop.location,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: SupplierColors.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if ((order.shop.phone ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      order.shop.phone!,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: SupplierColors.muted,
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    order.deliveryDistanceKm == null
                                        ? 'Distance unknown — quote delivery manually.'
                                        : 'Delivery distance: ${order.deliveryDistanceKm!.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: SupplierColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Items',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: SupplierColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SectionCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < order.items.length; i++) ...[
                            if (i > 0) const Divider(height: 18),
                            _ItemRow(item: order.items[i]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SectionCard(
                      child: Column(
                        children: [
                          KeyValueRow(
                            label: 'Subtotal',
                            value: money(order.subtotal),
                          ),
                          KeyValueRow(
                            label: 'Delivery',
                            value: money(_deliveryFee),
                          ),
                          const Divider(height: 14),
                          KeyValueRow(
                            label: 'Total',
                            value: money(order.subtotal + _deliveryFee),
                            bold: true,
                          ),
                          const Divider(height: 14),
                          KeyValueRow(
                            label: 'Shipping weight',
                            value: weightLabel(order.shippingWeightKg),
                          ),
                          KeyValueRow(
                            label: 'Shipping volume',
                            value: volumeLabel(order.shippingVolumeM3),
                          ),
                          if ((order.acceptedByName ?? '').isNotEmpty) ...[
                            const Divider(height: 14),
                            KeyValueRow(
                              label: 'Accepted by',
                              value: order.acceptedByName!,
                            ),
                            if (order.acceptedAt != null)
                              KeyValueRow(
                                label: 'Accepted at',
                                value: formatDateTime(order.acceptedAt!),
                              ),
                          ],
                        ],
                      ),
                    ),
                    if ((order.note ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      InfoBanner(
                        icon: Icons.sticky_note_2_outlined,
                        message: 'Shop note: ${order.note}',
                      ),
                    ],
                    if (_status == 'PENDING') ...[
                      const SizedBox(height: 14),
                      SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Delivery quote',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: SupplierColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _quoted
                                  ? 'The quote is saved. You can accept this order.'
                                  : 'This is the fee suggested by your delivery rates. Adjust it if needed before accepting the order.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: SupplierColors.muted,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _fee,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Delivery fee (Br)',
                                      prefixIcon: Icon(
                                        Icons.local_shipping_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  height: 50,
                                  child: FilledButton.icon(
                                    onPressed: _busy ? null : _saveQuote,
                                    icon: const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _quoted ? 'Update quote' : 'Save quote',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: SupplierColors.border)),
              ),
              child: _buildActions(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (_status == 'PENDING') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _changeStatus('REJECTED'),
              style: OutlinedButton.styleFrom(
                foregroundColor: SupplierColors.danger,
                side: BorderSide(
                  color: SupplierColors.danger.withValues(alpha: 0.4),
                ),
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: (_busy || !_quoted) ? null : () => _changeStatus('ACCEPTED'),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(_quoted ? 'Accept order' : 'Quote delivery first'),
            ),
          ),
        ],
      );
    }
    if (_status == 'ACCEPTED') {
      return FilledButton.icon(
        onPressed: _busy ? null : () => _changeStatus('READY'),
        icon: const Icon(Icons.inventory_rounded, size: 18),
        label: const Text('Mark ready for delivery'),
      );
    }
    if (_status == 'READY') {
      return FilledButton.icon(
        onPressed: _busy ? null : () => _changeStatus('DELIVERED'),
        icon: const Icon(Icons.local_shipping_rounded, size: 18),
        label: const Text('Mark delivered'),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final SupplierOrderItem item;

  @override
  Widget build(BuildContext context) {
    final unit = saleUnitLabel(item.saleUnit);
    final dimensions = [
      item.lengthCm,
      item.widthCm,
      item.heightCm,
    ].every((value) => value > 0)
        ? ' · ${qty(item.lengthCm)}×${qty(item.widthCm)}×${qty(item.heightCm)} cm'
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.listingName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: SupplierColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.quantity} × $unit · ${weightLabel(item.weightKg)} · ${volumeLabel(item.volumeCubicM)}$dimensions',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: SupplierColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(item.lineTotal),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: SupplierColors.ink,
              ),
            ),
            Text(
              '${money(item.unitPrice)} / $unit',
              style: const TextStyle(
                fontSize: 10.5,
                color: SupplierColors.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
