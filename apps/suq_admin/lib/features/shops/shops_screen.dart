import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class ShopsScreen extends ConsumerStatefulWidget {
  const ShopsScreen({super.key});

  @override
  ConsumerState<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends ConsumerState<ShopsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ShopRecord> _filter(List<ShopRecord> shops) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return shops;
    return shops.where((shop) {
      return shop.name.toLowerCase().contains(query) ||
          (shop.ownerName ?? '').toLowerCase().contains(query) ||
          (shop.ownerPhone ?? '').contains(query) ||
          (shop.city ?? '').toLowerCase().contains(query) ||
          (shop.subcity ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _grant(ShopRecord shop) async {
    final result = await showDialog<_GrantResult>(
      context: context,
      builder: (context) => _GrantDialog(shop: shop),
    );
    if (result == null) return;

    try {
      await ref.read(apiProvider).post(
        '/admin/shops/${shop.id}/grant',
        body: {
          'months': result.months,
          if (result.note.trim().isNotEmpty) 'note': result.note.trim(),
        },
      );
      ref.invalidate(shopsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) {
        showAppSnack(
          context,
          '${shop.name} received ${result.months} month${result.months == 1 ? '' : 's'}.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shops = ref.watch(shopsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shops & subscriptions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Monitor every SUQ shop and grant time when a payment is confirmed outside the queue.',
                      style: TextStyle(fontSize: 12.5, color: AdminColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(shopsProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search by shop, owner, phone, or city',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        Expanded(
          child: AsyncValueView<List<ShopRecord>>(
            value: shops,
            onRetry: () => ref.invalidate(shopsProvider),
            loadingMessage: 'Loading shops…',
            builder: (records) {
              final filtered = _filter(records);
              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.storefront_rounded,
                  title: _query.isEmpty ? 'No shops yet' : 'No shops match your search',
                  message: _query.isEmpty
                      ? 'Shops appear here after the owner creates an account in the SUQ shop app.'
                      : 'Try a different name, phone number, or city.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(shopsProvider);
                  await ref.read(shopsProvider.future);
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _ShopCard(
                    shop: filtered[index],
                    onGrant: () => _grant(filtered[index]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop, required this.onGrant});

  final ShopRecord shop;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final subscription = shop.subscription;
    final active = shop.active;
    final statusColor = active
        ? (subscription!.daysLeft <= 5 ? AdminColors.warning : AdminColors.success)
        : AdminColors.danger;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AdminColors.seed.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.storefront_rounded, color: AdminColors.seed, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if ((shop.ownerName ?? '').isNotEmpty) shop.ownerName!,
                        if ((shop.ownerPhone ?? '').isNotEmpty) shop.ownerPhone!,
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, color: AdminColors.muted),
                    ),
                    if ((shop.city ?? '').isNotEmpty || (shop.subcity ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        [shop.city, shop.subcity].whereType<String>().where((v) => v.isNotEmpty).join(', '),
                        style: const TextStyle(fontSize: 11.5, color: AdminColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: active ? daysLeftLabel(subscription!.endsAt) : 'Inactive',
                color: statusColor,
                icon: active ? Icons.verified_rounded : Icons.block_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final details = _SubscriptionDetails(shop: shop);
              final counts = _CountsRow(shop: shop);
              if (!wide) {
                return Column(
                  children: [
                    details,
                    const SizedBox(height: 12),
                    counts,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: details),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: counts),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Joined ${formatDate(shop.createdAt)}',
                  style: const TextStyle(fontSize: 11.5, color: AdminColors.muted),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onGrant,
                icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                label: const Text('Grant time'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubscriptionDetails extends StatelessWidget {
  const _SubscriptionDetails({required this.shop});

  final ShopRecord shop;

  @override
  Widget build(BuildContext context) {
    final subscription = shop.subscription;
    if (subscription == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminColors.danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 17, color: AdminColors.danger),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No subscription yet. Grant time to activate this shop.',
                style: TextStyle(fontSize: 12, color: AdminColors.danger),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          KeyValueRow(label: 'Package', value: subscription.packageName ?? '—', bold: true),
          KeyValueRow(
            label: 'Current term',
            value: subscription.startsAt == null || subscription.endsAt == null
                ? '—'
                : '${formatDate(subscription.startsAt!)} → ${formatDate(subscription.endsAt!)}',
          ),
          KeyValueRow(
            label: 'Status',
            value: subscription.active ? 'Active' : subscription.status,
            valueColor: subscription.active ? AdminColors.success : AdminColors.danger,
          ),
        ],
      ),
    );
  }
}

class _CountsRow extends StatelessWidget {
  const _CountsRow({required this.shop});

  final ShopRecord shop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Expanded(child: _Count(label: 'Sales', value: shop.salesCount)),
          Expanded(child: _Count(label: 'Customers', value: shop.customersCount)),
          Expanded(child: _Count(label: 'Payments', value: shop.paymentsCount)),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AdminColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
      ],
    );
  }
}

class _GrantResult {
  const _GrantResult({required this.months, required this.note});

  final int months;
  final String note;
}

class _GrantDialog extends StatefulWidget {
  const _GrantDialog({required this.shop});

  final ShopRecord shop;

  @override
  State<_GrantDialog> createState() => _GrantDialogState();
}

class _GrantDialogState extends State<_GrantDialog> {
  final _months = TextEditingController(text: '1');
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _months.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final months = int.tryParse(_months.text.trim());
    if (months == null || months < 1 || months > 36) {
      setState(() => _error = 'Enter a whole number of months between 1 and 36.');
      return;
    }
    Navigator.of(context).pop(_GrantResult(months: months, note: _note.text));
  }

  @override
  Widget build(BuildContext context) {
    final currentEnd = widget.shop.subscription?.endsAt;

    return AlertDialog(
      title: Text('Grant time to ${widget.shop.name}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentEnd == null
                    ? 'This shop has no active term. Granting time starts a new subscription.'
                    : 'The new months are appended to the current end date '
                        '(${formatDate(currentEnd)}).',
                style: const TextStyle(fontSize: 12.5, color: AdminColors.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _months,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Months'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final quick in [1, 3, 6, 12])
                    ActionChip(
                      label: Text('$quick month${quick == 1 ? '' : 's'}'),
                      onPressed: () => setState(() {
                        _months.text = '$quick';
                        _error = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 2,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Cash payment received at the office',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: AdminColors.danger),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Grant time')),
      ],
    );
  }
}
