import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'common.dart';

Color paymentStatusColor(String status) {
  switch (status) {
    case 'APPROVED':
      return AdminColors.success;
    case 'REJECTED':
      return AdminColors.danger;
    default:
      return AdminColors.warning;
  }
}

IconData paymentStatusIcon(String status) {
  switch (status) {
    case 'APPROVED':
      return Icons.check_circle_rounded;
    case 'REJECTED':
      return Icons.cancel_rounded;
    default:
      return Icons.hourglass_top_rounded;
  }
}

class PaymentTile extends StatelessWidget {
  const PaymentTile({
    super.key,
    required this.payment,
    this.actions = const [],
    this.compact = false,
  });

  final PaymentRecord payment;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final statusColor = paymentStatusColor(payment.status);

    return SectionCard(
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(paymentStatusIcon(payment.status), color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.shopName ?? 'Unknown shop',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if ((payment.ownerName ?? '').isNotEmpty) payment.ownerName!,
                        if ((payment.ownerPhone ?? '').isNotEmpty) payment.ownerPhone!,
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, color: AdminColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(payment.amountEtb),
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusChip(
                    label: payment.status,
                    color: statusColor,
                    icon: paymentStatusIcon(payment.status),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AdminColors.background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                KeyValueRow(label: 'Transaction ref', value: payment.transactionRef, bold: true),
                KeyValueRow(
                  label: 'Package',
                  value: payment.packageName == null
                      ? '—'
                      : '${payment.packageName} · ${payment.packageMonths} month${payment.packageMonths == 1 ? '' : 's'}',
                ),
                KeyValueRow(label: 'Submitted', value: formatDateTime(payment.submittedAt)),
                if (payment.reviewedAt != null)
                  KeyValueRow(label: 'Reviewed', value: formatDateTime(payment.reviewedAt!)),
                if (!compact && (payment.bankName ?? '').isNotEmpty)
                  KeyValueRow(
                    label: 'Bank',
                    value: '${payment.bankName} · ${payment.bankAccountNumber ?? ''}',
                  ),
                if ((payment.note ?? '').isNotEmpty)
                  KeyValueRow(label: 'Shop note', value: payment.note!),
                if ((payment.adminNote ?? '').isNotEmpty)
                  KeyValueRow(
                    label: 'Admin note',
                    value: payment.adminNote!,
                    valueColor: payment.rejected ? AdminColors.danger : null,
                  ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
