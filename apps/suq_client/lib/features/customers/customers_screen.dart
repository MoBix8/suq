import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addCustomer() async {
    final draft = await showDialog<_CustomerDraft>(
      context: context,
      builder: (context) => const _CustomerDialog(),
    );
    if (draft == null || !mounted) return;

    try {
      final customer = await ref.read(customerRepositoryProvider).create(
            name: draft.name,
            phone: draft.phone,
          );
      ref.invalidate(customersProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(reportProvider);
      if (mounted) showAppSnack(context, '${customer.name} added.');
    } catch (error) {
      if (mounted) showAppSnack(context, 'Could not add customer: $error', error: true);
    }
  }

  void _openCustomer(Customer customer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(customerId: customer.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return AsyncValueView<List<Customer>>(
      value: customersAsync,
      loadingMessage: 'Loading customers…',
      onRetry: () => ref.invalidate(customersProvider),
      builder: (customers) {
        final query = _query.trim().toLowerCase();
        final filtered = customers.where((customer) {
          if (query.isEmpty) return true;
          return customer.name.toLowerCase().contains(query) ||
              (customer.phone ?? '').toLowerCase().contains(query);
        }).toList();
        final outstanding = customers.fold<double>(
          0,
          (sum, customer) => sum + customer.creditBalance,
        );
        final owing = customers.where((customer) => customer.owes).length;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(customersProvider);
            await ref.read(customersProvider.future);
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
                      SectionCard(
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.handshake_rounded,
                                color: AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Outstanding credit',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    money(outstanding),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.warning,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  Text(
                                    '$owing customer${owing == 1 ? '' : 's'} owe you • ${customers.length} registered',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _addCustomer,
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _search,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (customers.isEmpty)
                        EmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'No customers yet',
                          message:
                              'Register customers to track credit (ዱቤ), part payments and repayments.',
                          action: FilledButton.icon(
                            onPressed: _addCustomer,
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                            label: const Text('Add your first customer'),
                          ),
                        )
                      else if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 44),
                          child: Center(
                            child: Text(
                              'No customers match this search.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        )
                      else
                        SectionCard(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: filtered
                                .map(
                                  (customer) => _CustomerRow(
                                    customer: customer,
                                    onTap: () => _openCustomer(customer),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
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

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer, required this.onTap});

  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = customer.name.trim().isEmpty
        ? '?'
        : customer.name.trim().substring(0, 1).toUpperCase();

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: (customer.owes ? AppColors.warning : AppColors.seed)
            .withValues(alpha: 0.1),
        child: Text(
          initial,
          style: TextStyle(
            color: customer.owes ? AppColors.warning : AppColors.seed,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        customer.name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        customer.phone ?? 'No phone number',
        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                customer.owes ? money(customer.creditBalance) : 'No credit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: customer.owes ? AppColors.warning : AppColors.muted,
                ),
              ),
              Text(
                customer.owes ? 'owes you' : 'settled',
                style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _CustomerDraft {
  const _CustomerDraft({required this.name, this.phone});

  final String name;
  final String? phone;
}

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog();

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
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
      _CustomerDraft(name: name, phone: phone.isEmpty ? null : phone),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New customer'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Customers are used for credit (ዱቤ). You can record full or partial payments later.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
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
        FilledButton(onPressed: _submit, child: const Text('Add customer')),
      ],
    );
  }
}
