import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/pager.dart';
import '../../widgets/payment_tile.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  static const _filters = <(String?, String)>[
    ('PENDING', 'Pending'),
    ('APPROVED', 'Approved'),
    ('REJECTED', 'Rejected'),
    (null, 'All'),
  ];

  String? _status = 'PENDING';
  String? _bankFilter;
  int _page = 1;
  final Set<String> _busy = {};

  Future<void> _refresh() async {
    ref.invalidate(paymentsProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> _approve(PaymentRecord payment) async {
    final daysController = TextEditingController(
      text: (payment.packageMonths * 30).toString(),
    );
    final days = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve this payment?'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${payment.shopName ?? 'This shop'} sent ${money(payment.amountEtb)} '
                'for the ${payment.packageName ?? 'selected'} package.\n'
                'Reference: ${payment.transactionRef}',
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Days to grant',
                  helperText: 'Default = package months × 30. Adjust for partial payments.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(daysController.text.trim());
              if (value == null || value < 1) {
                showAppSnack(context, 'Enter a valid number of days.', error: true);
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    daysController.dispose();
    if (days == null) return;

    setState(() => _busy.add(payment.id));
    try {
      await ref.read(apiProvider).post(
        '/admin/payments/${payment.id}/approve',
        body: {'days': days},
      );
      ref.invalidate(paymentsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(shopsProvider);
      if (mounted) {
        showAppSnack(context, 'Payment approved. $days day${days == 1 ? '' : 's'} granted.');
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(payment.id));
    }
  }

  Future<void> _reject(PaymentRecord payment) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => _RejectDialog(payment: payment),
    );
    if (note == null) return;

    setState(() => _busy.add(payment.id));
    try {
      await ref.read(apiProvider).post(
        '/admin/payments/${payment.id}/reject',
        body: {if (note.trim().isNotEmpty) 'note': note.trim()},
      );
      ref.invalidate(paymentsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) {
        showAppSnack(context, 'Payment rejected. The shop owner can submit a new reference.');
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(payment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(
      paymentsProvider(
        PaymentQuery(status: _status, bankAccountId: _bankFilter, page: _page),
      ),
    );

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
                      'Manual payment verification',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Match each transaction reference with your bank statement before approving.',
                      style: TextStyle(fontSize: 12.5, color: AdminColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in _filters)
                  ChoiceChip(
                    label: Text(filter.$2),
                    selected: _status == filter.$1,
                    onSelected: (_) => setState(() {
                        _status = filter.$1;
                        _page = 1;
                      }),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final banks = ref.watch(banksProvider);
                    final accounts = banks.asData?.value ?? const <BankAccount>[];
                    return DropdownButtonFormField<String?>(
                      value: _bankFilter,
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All accounts'),
                        ),
                        for (final account in accounts)
                          DropdownMenuItem<String?>(
                            value: account.id,
                            child: Text(
                              '${account.bankName} · ${account.accountNumber}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _bankFilter = value;
                        _page = 1;
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<PagedPayments>(
            value: payments,
            onRetry: _refresh,
            loadingMessage: 'Loading payments…',
            builder: (pageData) {
              final records = pageData.items;
              if (records.isEmpty) {
                return EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: _status == 'PENDING' ? 'No payments to review' : 'No payments here',
                  message: _status == 'PENDING'
                      ? 'New bank transfer submissions will appear here for manual approval.'
                      : 'Nothing matches this filter yet.',
                  action: OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(
                    paymentsProvider(
                      PaymentQuery(status: _status, bankAccountId: _bankFilter, page: _page),
                    ),
                  );
                  await ref.read(
                    paymentsProvider(
                      PaymentQuery(status: _status, bankAccountId: _bankFilter, page: _page),
                    ).future,
                  );
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: records.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final payment = records[index];
                    final busy = _busy.contains(payment.id);
                    return PaymentTile(
                      payment: payment,
                      actions: payment.pending
                          ? [
                              OutlinedButton.icon(
                                onPressed: busy ? null : () => _reject(payment),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AdminColors.danger,
                                ),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text('Reject'),
                              ),
                              FilledButton.icon(
                                onPressed: busy ? null : () => _approve(payment),
                                icon: busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_rounded, size: 18),
                                label: const Text('Approve'),
                              ),
                            ]
                          : const [],
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (payments.asData?.value != null)
          CatalogPager(
            page: payments.asData!.value!.page,
            pageSize: payments.asData!.value!.pageSize,
            total: payments.asData!.value!.total,
            onPrevious: payments.asData!.value!.page > 1
                ? () => setState(() => _page -= 1)
                : null,
            onNext: payments.asData!.value!.hasMore
                ? () => setState(() => _page += 1)
                : null,
          ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.payment});

  final PaymentRecord payment;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject payment'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.payment.shopName ?? 'This shop'} · ${money(widget.payment.amountEtb)}\n'
              'Reference ${widget.payment.transactionRef}',
              style: const TextStyle(fontSize: 12.5, color: AdminColors.muted, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Reference not found on the bank statement',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
          onPressed: () => Navigator.of(context).pop(_note.text),
          child: const Text('Reject payment'),
        ),
      ],
    );
  }
}
