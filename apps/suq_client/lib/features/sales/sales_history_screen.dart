import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  String _filter = 'all';
  String _dateFilter = 'all';
  DateTime? _customDate;

  Future<void> _refresh() async {
    ref.invalidate(salesHistoryProvider);
    await ref.read(salesHistoryProvider.future);
  }

  bool _inDateRange(SaleRecord sale) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final saleDay = DateTime(sale.soldAt.year, sale.soldAt.month, sale.soldAt.day);
    switch (_dateFilter) {
      case 'today':
        return saleDay == today;
      case 'yesterday':
        return saleDay == today.subtract(const Duration(days: 1));
      case 'week':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return !saleDay.isBefore(weekStart) && !saleDay.isAfter(today);
      case 'month':
        return sale.soldAt.year == now.year && sale.soldAt.month == now.month;
      case 'custom':
        if (_customDate == null) return true;
        final custom = DateTime(_customDate!.year, _customDate!.month, _customDate!.day);
        return saleDay == custom;
      default:
        return true;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _customDate = picked;
        _dateFilter = 'custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sales history')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: AsyncValueView<List<SaleRecord>>(
          value: salesAsync,
          loadingMessage: 'Loading sales…',
          onRetry: () => ref.invalidate(salesHistoryProvider),
          builder: (sales) {
            final filtered = sales.where((sale) {
              final hasCustomer = sale.customerName != null && sale.customerName!.trim().isNotEmpty;
              if (_filter == 'registered' && !hasCustomer) return false;
              if (_filter == 'walkin' && hasCustomer) return false;
              if (!_inDateRange(sale)) return false;
              return true;
            }).toList();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('All dates'),
                              selected: _dateFilter == 'all',
                              onSelected: (_) => setState(() => _dateFilter = 'all'),
                            ),
                            ChoiceChip(
                              label: const Text('Today'),
                              selected: _dateFilter == 'today',
                              onSelected: (_) => setState(() => _dateFilter = 'today'),
                            ),
                            ChoiceChip(
                              label: const Text('Yesterday'),
                              selected: _dateFilter == 'yesterday',
                              onSelected: (_) => setState(() => _dateFilter = 'yesterday'),
                            ),
                            ChoiceChip(
                              label: const Text('This week'),
                              selected: _dateFilter == 'week',
                              onSelected: (_) => setState(() => _dateFilter = 'week'),
                            ),
                            ChoiceChip(
                              label: const Text('This month'),
                              selected: _dateFilter == 'month',
                              onSelected: (_) => setState(() => _dateFilter = 'month'),
                            ),
                            ActionChip(
                              label: Text(
                                _dateFilter == 'custom' && _customDate != null
                                    ? '${_customDate!.day}/${_customDate!.month}/${_customDate!.year}'
                                    : 'Pick date',
                              ),
                              avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                              onPressed: _pickDate,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('All customers'),
                              selected: _filter == 'all',
                              onSelected: (_) => setState(() => _filter = 'all'),
                            ),
                            ChoiceChip(
                              label: const Text('Registered'),
                              selected: _filter == 'registered',
                              onSelected: (_) => setState(() => _filter = 'registered'),
                            ),
                            ChoiceChip(
                              label: const Text('Walk-in'),
                              selected: _filter == 'walkin',
                              onSelected: (_) => setState(() => _filter = 'walkin'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (filtered.isEmpty)
                          const EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No sales yet',
                            message: 'Sales you make will appear here with their items.',
                          )
                        else
                          ...filtered.map((sale) => _SaleTile(sale: sale)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SaleTile extends ConsumerStatefulWidget {
  const _SaleTile({required this.sale});

  final SaleRecord sale;

  @override
  ConsumerState<_SaleTile> createState() => _SaleTileState();
}

class _SaleTileState extends ConsumerState<_SaleTile> {
  bool _expanded = false;
  List<SaleItemRecord>? _items;
  bool _loading = false;

  Future<void> _loadItems() async {
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          setState(() => _expanded = expanded);
          if (expanded) _loadItems();
        },
        title: Text(
          sale.customerName ?? 'Walk-in customer',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${sale.receiptNo} • ${formatDateTime(sale.soldAt)}',
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(sale.total),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            if (sale.returned)
              const Text('Returned', style: TextStyle(fontSize: 10.5, color: AppColors.warning))
            else if (sale.credit > 0)
              Text(
                '${money(sale.credit)} credit',
                style: const TextStyle(fontSize: 10.5, color: AppColors.warning),
              ),
          ],
        ),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_items == null || _items!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No items recorded.', style: TextStyle(color: AppColors.muted)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: _items!.map((item) => _ItemRow(item: item)).toList(),
              ),
            ),
          if (!widget.sale.returned)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Return this sale?'),
                        content: const Text(
                          'Stock will be restocked and credit adjusted. This cannot be undone.',
                        ),
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
                      ref.invalidate(salesHistoryProvider);
                      ref.invalidate(customersProvider);
                      ref.invalidate(dashboardProvider);
                      ref.invalidate(reportProvider);
                      if (mounted) {
                        showAppSnack(context, 'Sale returned.');
                      }
                    } catch (e) {
                      if (mounted) showAppSnack(context, 'Could not return: $e', error: true);
                    }
                  },
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Return sale'),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Returned', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final SaleItemRecord item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${item.name} (${qty(item.qty)} ${item.unit})',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          Text(
            '${money(item.unitPrice)} × ${qty(item.qty)} = ${money(item.lineTotal)}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}