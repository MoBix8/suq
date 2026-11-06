import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  void _invalidate(WidgetRef ref) {
    ref.invalidate(customerDetailProvider(customerId));
    ref.invalidate(customersProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(reportProvider);
  }

  Future<void> _receivePayment(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => _ReceivePaymentDialog(customer: customer),
    );
    if (amount == null) return;

    try {
      final newBalance = await ref.read(customerRepositoryProvider).receivePayment(
            customerId: customer.id,
            amount: amount,
          );
      _invalidate(ref);
      if (context.mounted) {
        showAppSnack(
          context,
          newBalance <= 0.009
              ? 'Payment recorded. ${customer.name} is fully settled.'
              : 'Payment recorded. Remaining balance ${money(newBalance)}.',
        );
      }
    } on CheckoutException catch (error) {
      if (context.mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, 'Could not record payment: $error', error: true);
      }
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final edit = await showDialog<_CustomerEdit>(
      context: context,
      builder: (context) => _EditCustomerDialog(customer: customer),
    );
    if (edit == null) return;

    try {
      await ref.read(customerRepositoryProvider).save(
            customer.copyWith(
              name: edit.name,
              phone: edit.phone,
              clearPhone: edit.phone == null,
              updatedAt: DateTime.now(),
            ),
          );
      _invalidate(ref);
      if (context.mounted) showAppSnack(context, 'Customer updated.');
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, 'Could not update: $error', error: true);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove customer?'),
        content: Text(
          customer.owes
              ? '${customer.name} still owes ${money(customer.creditBalance)}. '
                  'The customer will be hidden from your list, but past sales and credit entries are kept.'
              : '${customer.name} will be hidden from your list. Past sales are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(customerRepositoryProvider).softDelete(customer.id);
      _invalidate(ref);
      if (context.mounted) Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, 'Could not remove: $error', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(customerDetailProvider(customerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Customer')),
      body: AsyncValueView<CustomerDetail>(
        value: detail,
        loadingMessage: 'Loading customer…',
        onRetry: () => ref.invalidate(customerDetailProvider(customerId)),
        builder: (data) {
          final customer = data.customer;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(customerDetailProvider(customerId));
              await ref.read(customerDetailProvider(customerId).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CustomerHeader(
                          customer: customer,
                          onReceive: customer.owes
                              ? () => _receivePayment(context, ref, customer)
                              : null,
                          onEdit: () => _edit(context, ref, customer),
                          onDelete: () => _delete(context, ref, customer),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth > 760;
                            final ledger = _LedgerCard(entries: data.ledger);
                            final sales = _SalesCard(sales: data.sales);
                            if (!wide) {
                              return Column(
                                children: [
                                  ledger,
                                  const SizedBox(height: 14),
                                  sales,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: ledger),
                                const SizedBox(width: 14),
                                Expanded(child: sales),
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
        },
      ),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({
    required this.customer,
    required this.onReceive,
    required this.onEdit,
    required this.onDelete,
  });

  final Customer customer;
  final VoidCallback? onReceive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final initial = customer.name.trim().isEmpty
        ? '?'
        : customer.name.trim().substring(0, 1).toUpperCase();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: (customer.owes ? AppColors.warning : AppColors.seed)
                    .withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: customer.owes ? AppColors.warning : AppColors.seed,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phone ?? 'No phone number',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                    Text(
                      'Customer since ${formatDate(customer.createdAt)}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: customer.owes ? 'Owes you' : 'Settled',
                color: customer.owes ? AppColors.warning : AppColors.profit,
                icon: customer.owes
                    ? Icons.schedule_rounded
                    : Icons.check_circle_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (customer.owes ? AppColors.warning : AppColors.profit)
                  .withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  customer.owes
                      ? Icons.account_balance_wallet_outlined
                      : Icons.verified_rounded,
                  color: customer.owes ? AppColors.warning : AppColors.profit,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Outstanding balance',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      Text(
                        money(customer.creditBalance),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: customer.owes
                              ? AppColors.warning
                              : AppColors.profit,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onReceive,
                icon: const Icon(Icons.payments_outlined, size: 19),
                label: const Text('Receive payment'),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                style: TextButton.styleFrom(foregroundColor: AppColors.loss),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.entries});

  final List<CreditEntry> entries;

  String _title(CreditEntry entry) {
    switch (entry.type) {
      case 'PAYMENT':
        return 'Payment received';
      case 'CREDIT':
        return 'Credit sale';
      default:
        return 'Adjustment';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Credit ledger',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${entries.length} entr${entries.length == 1 ? 'y' : 'ies'}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No credit history yet.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            ...entries.map((entry) {
              final isDebt = entry.isDebt;
              final color = isDebt ? AppColors.warning : AppColors.profit;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDebt
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 17,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title(entry),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${formatDateTime(entry.createdAt)}'
                            '${entry.note == null ? '' : ' • ${entry.note}'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isDebt ? '+' : '-'} ${money(entry.amount.abs())}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
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

class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.sales});

  final List<SaleRecord> sales;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Sales history',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${sales.length} sale${sales.length == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sales.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No sales recorded for this customer.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            ...sales.map(
              (sale) => _CustomerSaleTile(sale: sale),
            ),
        ],
      ),
    );
  }
}

class _CustomerSaleTile extends ConsumerStatefulWidget {
  const _CustomerSaleTile({required this.sale});

  final SaleRecord sale;

  @override
  ConsumerState<_CustomerSaleTile> createState() => _CustomerSaleTileState();
}

class _CustomerSaleTileState extends ConsumerState<_CustomerSaleTile> {
  List<SaleItemRecord>? _items;
  bool _loading = false;

  Future<void> _load() async {
    if (_items != null) return;
    setState(() => _loading = true);
    try {
      final items = await ref.read(salesRepositoryProvider).itemsForSale(widget.sale.id);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        onExpansionChanged: (expanded) {
          if (expanded) _load();
        },
        title: Text(
          sale.receiptNo,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
        subtitle: Text(
          formatDateTime(sale.soldAt),
          style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(sale.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            Text(
              sale.credit > 0 ? '${money(sale.credit)} on credit' : 'Paid in full',
              style: TextStyle(
                fontSize: 10.5,
                color: sale.credit > 0 ? AppColors.warning : AppColors.muted,
              ),
            ),
          ],
        ),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_items == null || _items!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No items recorded.', style: TextStyle(color: AppColors.muted)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: _items!
                    .map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.name} (${qty(item.qty)} ${item.unit})',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                '${money(item.unitPrice)} × ${qty(item.qty)} = ${money(item.lineTotal)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          if (!widget.sale.returned)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Return this sale?'),
                        content: const Text('Stock will be restocked and credit adjusted.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Return'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    try {
                      await ref.read(salesRepositoryProvider).returnSale(widget.sale.id);
                      ref.invalidate(customersProvider);
                      ref.invalidate(dashboardProvider);
                      ref.invalidate(reportProvider);
                      ref.invalidate(salesHistoryProvider);
                      if (mounted) showAppSnack(context, 'Sale returned.');
                    } catch (e) {
                      if (mounted) showAppSnack(context, 'Could not return: $e', error: true);
                    }
                  },
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text('Return'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
class _ReceivePaymentDialog extends StatefulWidget {
  const _ReceivePaymentDialog({required this.customer});

  final Customer customer;

  @override
  State<_ReceivePaymentDialog> createState() => _ReceivePaymentDialogState();
}

class _ReceivePaymentDialogState extends State<_ReceivePaymentDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.customer.creditBalance.toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (amount > widget.customer.creditBalance + 0.009) {
      setState(() => _error = 'Amount is more than the outstanding balance.');
      return;
    }
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.customer.creditBalance;
    return AlertDialog(
      title: const Text('Receive payment'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.customer.name} owes ${money(balance)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount received',
                prefixText: 'Br ',
                helperText: 'You can accept a partial payment.',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: Text('Full ${money(balance)}'),
                  onPressed: () {
                    _amount.text = balance.toStringAsFixed(2);
                    setState(() {});
                  },
                ),
                ActionChip(
                  label: const Text('Half'),
                  onPressed: () {
                    _amount.text = (balance / 2).toStringAsFixed(2);
                    setState(() {});
                  },
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.loss, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Record payment')),
      ],
    );
  }
}

class _CustomerEdit {
  const _CustomerEdit({required this.name, this.phone});

  final String name;
  final String? phone;
}

class _EditCustomerDialog extends StatefulWidget {
  const _EditCustomerDialog({required this.customer});

  final Customer customer;

  @override
  State<_EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends State<_EditCustomerDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.customer.name);
  late final TextEditingController _phone =
      TextEditingController(text: widget.customer.phone ?? '');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter the customer name.');
      return;
    }
    final phone = _phone.text.trim();
    Navigator.of(context).pop(
      _CustomerEdit(name: name, phone: phone.isEmpty ? null : phone),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit customer'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number (optional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.loss, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
