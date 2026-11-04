import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key, this.state, this.error});

  final EntitlementState? state;
  final String? error;

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _transactionRef = TextEditingController();
  final _note = TextEditingController();

  String? _selectedPackageId;
  String? _selectedBankId;
  bool _submitting = false;
  String? _formError;

  @override
  void dispose() {
    _transactionRef.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    ref.invalidate(packagesProvider);
    ref.invalidate(banksProvider);
    ref.invalidate(paymentsProvider);
    await ref.read(entitlementProvider.notifier).refresh();
  }

  Future<void> _submitPayment(PackagePlan plan, BankAccount bank) async {
    final reference = _transactionRef.text.trim();
    if (reference.length < 4) {
      setState(() => _formError = 'Enter the transaction number from your bank SMS.');
      return;
    }

    setState(() {
      _submitting = true;
      _formError = null;
    });

    try {
      await ref.read(apiProvider).post(
        '/payments',
        body: {
          'packageId': plan.id,
          'bankAccountId': bank.id,
          'transactionRef': reference,
          if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        },
      );
      _transactionRef.clear();
      _note.clear();
      ref.invalidate(paymentsProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Payment submitted'),
          content: const Text(
            'The SUQ admin will verify your transaction and activate your shop. '
            'This usually takes less than one working day. You can tap “Refresh status” after approval.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _formError = error.message);
    } catch (error) {
      if (mounted) setState(() => _formError = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) showAppSnack(context, '$label copied');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final state = widget.state;
    final message = widget.error ?? state?.message;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (Navigator.of(context).canPop()) ...[
                          IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 2),
                        ],
                        const AppLogo(size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Activate SUQ',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                session.shop?.name ?? 'Your shop',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh status',
                          onPressed: _refreshAll,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        IconButton(
                          tooltip: 'Log out',
                          onPressed: () => ref.read(sessionProvider.notifier).logout(),
                          icon: const Icon(Icons.logout_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (message != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (state?.clockTampered ?? false
                                  ? AppColors.loss
                                  : AppColors.warning)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: (state?.clockTampered ?? false
                                    ? AppColors.loss
                                    : AppColors.warning)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              state?.clockTampered ?? false
                                  ? Icons.warning_amber_rounded
                                  : Icons.info_outline_rounded,
                              color: state?.clockTampered ?? false
                                  ? AppColors.loss
                                  : AppColors.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                message,
                                style: const TextStyle(fontSize: 13, height: 1.4),
                              ),
                            ),
                            TextButton(
                              onPressed: _refreshAll,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    if (message != null) const SizedBox(height: 18),
                    _PlanSection(
                      selectedPackageId: _selectedPackageId,
                      onSelected: (id) => setState(() => _selectedPackageId = id),
                    ),
                    const SizedBox(height: 18),
                    _BankSection(
                      selectedBankId: _selectedBankId,
                      onSelected: (id) => setState(() => _selectedBankId = id),
                      onCopy: _copy,
                    ),
                    const SizedBox(height: 18),
                    _PaymentForm(
                      packages: ref.watch(packagesProvider),
                      banks: ref.watch(banksProvider),
                      selectedPackageId: _selectedPackageId,
                      selectedBankId: _selectedBankId,
                      transactionRef: _transactionRef,
                      note: _note,
                      submitting: _submitting,
                      formError: _formError,
                      onSubmit: _submitPayment,
                    ),
                    const SizedBox(height: 18),
                    _PaymentHistory(onRefresh: _refreshAll),
                    const SizedBox(height: 26),
                    const Text(
                      'Subscription dates are controlled by the SUQ server. '
                      'The app verifies a signed offline lease, so changing the phone date does not extend access.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanSection extends ConsumerWidget {
  const _PlanSection({
    required this.selectedPackageId,
    required this.onSelected,
  });

  final String? selectedPackageId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(packagesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: '1. Choose a package',
          subtitle: 'Pay for one month or save with a longer plan.',
        ),
        const SizedBox(height: 12),
        AsyncValueView<List<PackagePlan>>(
          value: packages,
          onRetry: () => ref.invalidate(packagesProvider),
          builder: (plans) {
            if (plans.isEmpty) {
              return const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No packages available',
                message: 'Ask the SUQ admin to publish a package.',
              );
            }
            final selected = selectedPackageId ?? plans.first.id;
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 620;
                final cards = plans.map((plan) {
                  final active = plan.id == selected;
                  return _SelectableCard(
                    active: active,
                    onTap: () => onSelected(plan.id),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: (active ? AppColors.seed : AppColors.muted)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            color: active ? AppColors.seed : AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              if (plan.description != null)
                                Text(
                                  plan.description!,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
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
                              money(plan.priceEtb),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${plan.months} month${plan.months == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList();

                if (wide) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards
                        .map((card) => SizedBox(width: 390, child: card))
                        .toList(),
                  );
                }
                return Column(
                  children: cards
                      .map((card) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: card,
                          ))
                      .toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _BankSection extends ConsumerWidget {
  const _BankSection({
    required this.selectedBankId,
    required this.onSelected,
    required this.onCopy,
  });

  final String? selectedBankId;
  final ValueChanged<String> onSelected;
  final Future<void> Function(String value, String label) onCopy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banks = ref.watch(banksProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: '2. Send the money',
          subtitle: 'Use one of these accounts, then submit the transaction number.',
        ),
        const SizedBox(height: 12),
        AsyncValueView<List<BankAccount>>(
          value: banks,
          onRetry: () => ref.invalidate(banksProvider),
          builder: (accounts) {
            if (accounts.isEmpty) {
              return const EmptyState(
                icon: Icons.account_balance_outlined,
                title: 'No bank accounts yet',
                message: 'Contact the SUQ admin for payment details.',
              );
            }
            final selected = selectedBankId ?? accounts.first.id;
            final bank = accounts.firstWhere(
              (account) => account.id == selected,
              orElse: () => accounts.first,
            );
            return SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (accounts.length > 1) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: accounts
                          .map(
                            (account) => ChoiceChip(
                              label: Text(account.bankName),
                              selected: account.id == selected,
                              onSelected: (_) => onSelected(account.id),
                            ),
                          )
                          .toList(),
                    ),
                    const Divider(height: 26),
                  ],
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.seed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: AppColors.seed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          bank.bankName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _CopyRow(
                    label: 'Account name',
                    value: bank.accountName,
                    onCopy: () => onCopy(bank.accountName, 'Account name'),
                  ),
                  _CopyRow(
                    label: 'Account number',
                    value: bank.accountNumber,
                    onCopy: () => onCopy(bank.accountNumber, 'Account number'),
                  ),
                  if (bank.branch != null)
                    KeyValueRow(label: 'Branch', value: bank.branch!),
                  if (bank.instructions != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      bank.instructions!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PaymentForm extends StatelessWidget {
  const _PaymentForm({
    required this.packages,
    required this.banks,
    required this.selectedPackageId,
    required this.selectedBankId,
    required this.transactionRef,
    required this.note,
    required this.submitting,
    required this.formError,
    required this.onSubmit,
  });

  final AsyncValue<List<PackagePlan>> packages;
  final AsyncValue<List<BankAccount>> banks;
  final String? selectedPackageId;
  final String? selectedBankId;
  final TextEditingController transactionRef;
  final TextEditingController note;
  final bool submitting;
  final String? formError;
  final Future<void> Function(PackagePlan plan, BankAccount bank) onSubmit;

  @override
  Widget build(BuildContext context) {
    final plans = packages.asData?.value ?? const <PackagePlan>[];
    final accounts = banks.asData?.value ?? const <BankAccount>[];
    if (plans.isEmpty || accounts.isEmpty) return const SizedBox.shrink();

    final plan = plans.firstWhere(
      (item) => item.id == selectedPackageId,
      orElse: () => plans.first,
    );
    final bank = accounts.firstWhere(
      (item) => item.id == selectedBankId,
      orElse: () => accounts.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: '3. Submit the transaction',
          subtitle: 'Enter the transaction number exactly as it appears in the SMS.',
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.seed.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: AppColors.seed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Transfer ${money(plan.priceEtb)} to ${bank.bankName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: transactionRef,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Transaction number',
                  hintText: 'e.g. FT24ABC12345',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note for the admin (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              if (formError != null) ...[
                const SizedBox(height: 12),
                Text(
                  formError!,
                  style: const TextStyle(color: AppColors.loss, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: submitting ? null : () => onSubmit(plan, bank),
                icon: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(submitting ? 'Submitting…' : 'Submit payment'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentHistory extends ConsumerWidget {
  const _PaymentHistory({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(paymentsProvider);
    return AsyncValueView<List<PaymentRecord>>(
      value: payments,
      onRetry: () => ref.invalidate(paymentsProvider),
      builder: (records) {
        if (records.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              title: 'Your payments',
              subtitle: 'The admin reviews these manually.',
            ),
            const SizedBox(height: 12),
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: records.map((record) {
                  final color = record.approved
                      ? AppColors.profit
                      : record.pending
                          ? AppColors.warning
                          : AppColors.loss;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      record.approved
                          ? Icons.check_circle_rounded
                          : record.pending
                              ? Icons.schedule_rounded
                              : Icons.cancel_rounded,
                      color: color,
                    ),
                    title: Text(
                      record.packageName ?? 'Package',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${record.transactionRef} • ${formatDateTime(record.submittedAt)}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusChip(
                          label: record.status,
                          color: color,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          money(record.amountEtb),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.active,
    required this.onTap,
    required this.child,
  });

  final bool active;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.seed.withValues(alpha: 0.045) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? AppColors.seed : AppColors.border,
              width: active ? 1.8 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}
