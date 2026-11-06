import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/export_import.dart';

class BanksTab extends ConsumerWidget {
  const BanksTab({super.key});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    BankAccount? account,
  }) async {
    final draft = await showDialog<_BankDraft>(
      context: context,
      builder: (context) => _BankDialog(account: account),
    );
    if (draft == null) return;

    try {
      final api = ref.read(apiProvider);
      if (account == null) {
        await api.post('/admin/bank-accounts', body: draft.toJson());
      } else {
        await api.patch('/admin/bank-accounts/${account.id}', body: draft.toJson());
      }
      ref.invalidate(banksProvider);
      if (context.mounted) {
        showAppSnack(context, account == null ? 'Bank account added.' : 'Bank account updated.');
      }
    } on ApiException catch (error) {
      if (context.mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    BankAccount account,
  ) async {
    final deactivating = account.active;
    if (deactivating) {
      final confirmed = await confirmAction(
        context,
        title: 'Deactivate ${account.bankName}?',
        message:
            'Shops will no longer see this account when paying. '
            'Past payments keep their reference.',
        confirmLabel: 'Deactivate',
        destructive: true,
      );
      if (!confirmed) return;
    }

    try {
      final api = ref.read(apiProvider);
      if (deactivating) {
        await api.delete('/admin/bank-accounts/${account.id}');
      } else {
        await api.patch('/admin/bank-accounts/${account.id}', body: {'active': true});
      }
      ref.invalidate(banksProvider);
      if (context.mounted) {
        showAppSnack(context, deactivating ? 'Bank account deactivated.' : 'Bank account reactivated.');
      }
    } on ApiException catch (error) {
      if (context.mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(banksProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Accounts shown to shops when they pay by bank transfer.',
                style: TextStyle(fontSize: 12.5, color: AdminColors.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openEditor(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('Add account'),
                  ),
                  ExportImportButtons(
                    exportPath: '/admin/export/bank-accounts',
                    importPath: '/admin/import/bank-accounts',
                    onImported: () => ref.invalidate(banksProvider),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<List<BankAccount>>(
            value: accounts,
            onRetry: () => ref.invalidate(banksProvider),
            loadingMessage: 'Loading bank accounts…',
            builder: (records) {
              if (records.isEmpty) {
                return const EmptyState(
                  icon: Icons.account_balance_rounded,
                  title: 'No bank accounts',
                  message: 'Add the account that receives subscription payments.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: records.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final account = records[index];
                  return SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AdminColors.seed.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.account_balance_rounded,
                                size: 20,
                                color: AdminColors.seed,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          account.bankName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AdminColors.ink,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusChip(
                                        label: account.active ? 'ACTIVE' : 'INACTIVE',
                                        color: account.active
                                            ? AdminColors.success
                                            : AdminColors.muted,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    account.accountName,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AdminColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              account.accountNumber,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AdminColors.ink,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        if ((account.branch ?? '').isNotEmpty ||
                            (account.instructions ?? '').isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: AdminColors.background,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Column(
                              children: [
                                if ((account.branch ?? '').isNotEmpty)
                                  KeyValueRow(label: 'Branch', value: account.branch!),
                                if ((account.instructions ?? '').isNotEmpty)
                                  KeyValueRow(
                                    label: 'Instructions',
                                    value: account.instructions!,
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              '${account.paymentCount} payment${account.paymentCount == 1 ? '' : 's'} · '
                              'sort ${account.sortOrder}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AdminColors.muted,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _toggleActive(context, ref, account),
                              style: TextButton.styleFrom(
                                foregroundColor: account.active
                                    ? AdminColors.danger
                                    : AdminColors.success,
                              ),
                              icon: Icon(
                                account.active
                                    ? Icons.pause_circle_outline_rounded
                                    : Icons.play_circle_outline_rounded,
                                size: 18,
                              ),
                              label: Text(account.active ? 'Deactivate' : 'Reactivate'),
                            ),
                            const SizedBox(width: 4),
                            OutlinedButton.icon(
                              onPressed: () => _openEditor(context, ref, account: account),
                              icon: const Icon(Icons.edit_outlined, size: 17),
                              label: const Text('Edit'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BankDraft {
  const _BankDraft({
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.branch,
    required this.instructions,
    required this.sortOrder,
    required this.active,
  });

  final String bankName;
  final String accountName;
  final String accountNumber;
  final String? branch;
  final String? instructions;
  final int sortOrder;
  final bool active;

  Map<String, dynamic> toJson() => {
        'bankName': bankName,
        'accountName': accountName,
        'accountNumber': accountNumber,
        'branch': branch,
        'instructions': instructions,
        'sortOrder': sortOrder,
        'active': active,
      };
}

class _BankDialog extends StatefulWidget {
  const _BankDialog({this.account});

  final BankAccount? account;

  @override
  State<_BankDialog> createState() => _BankDialogState();
}

class _BankDialogState extends State<_BankDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bankName;
  late final TextEditingController _accountName;
  late final TextEditingController _accountNumber;
  late final TextEditingController _branch;
  late final TextEditingController _instructions;
  late final TextEditingController _sortOrder;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _bankName = TextEditingController(text: account?.bankName ?? '');
    _accountName = TextEditingController(text: account?.accountName ?? '');
    _accountNumber = TextEditingController(text: account?.accountNumber ?? '');
    _branch = TextEditingController(text: account?.branch ?? '');
    _instructions = TextEditingController(text: account?.instructions ?? '');
    _sortOrder = TextEditingController(text: '${account?.sortOrder ?? 0}');
    _active = account?.active ?? true;
  }

  @override
  void dispose() {
    _bankName.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    _branch.dispose();
    _instructions.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final branch = _branch.text.trim();
    final instructions = _instructions.text.trim();
    Navigator.of(context).pop(
      _BankDraft(
        bankName: _bankName.text.trim(),
        accountName: _accountName.text.trim(),
        accountNumber: _accountNumber.text.trim(),
        branch: branch.isEmpty ? null : branch,
        instructions: instructions.isEmpty ? null : instructions,
        sortOrder: int.parse(_sortOrder.text.trim()),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.account == null ? 'Add bank account' : 'Edit bank account'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _bankName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Bank name'),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'Enter at least 2 characters.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Account name'),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'Enter at least 2 characters.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountNumber,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Account number'),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.length < 4) return 'Enter at least 4 characters.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _branch,
                  decoration: const InputDecoration(labelText: 'Branch (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instructions,
                  maxLines: 2,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Instructions (optional)',
                    hintText: 'Shown under the account details',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _sortOrder,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Sort order',
                    helperText: 'Lower numbers appear first.',
                  ),
                  validator: (value) => int.tryParse((value ?? '').trim()) == null
                      ? 'Enter a whole number.'
                      : null,
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text('Inactive accounts are hidden from shops.'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.account == null ? 'Add account' : 'Save changes'),
        ),
      ],
    );
  }
}
