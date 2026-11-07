import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _chooseCustomer(CartTab tab) async {
    final customers =
        ref.read(customersProvider).asData?.value ??
        await ref.read(customerRepositoryProvider).list();
    if (!mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Customer for ${tab.label}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Credit sales need a customer.'),
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).pop(''),
                    child: const Text('Walk-in'),
                  ),
                ),
                const Divider(height: 1),
                if (customers.isEmpty)
                  const EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No customers yet',
                    message:
                        'Add customers from the Customers tab to track credit.',
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: customers.length,
                      itemBuilder: (context, index) {
                        final customer = customers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.seed.withValues(
                              alpha: 0.1,
                            ),
                            child: Text(
                              customer.name.isEmpty
                                  ? '?'
                                  : customer.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.seed,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(customer.name),
                          subtitle: Text(
                            customer.owes
                                ? 'Owes ${money(customer.creditBalance)}'
                                : customer.phone ?? 'No phone',
                            style: TextStyle(
                              color: customer.owes
                                  ? AppColors.warning
                                  : AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          trailing: tab.customerId == customer.id
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.seed,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(customer.id),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    if (result.isEmpty) {
      ref.read(cartProvider.notifier).setCustomer(null);
      return;
    }
    final customer = customers.firstWhere((item) => item.id == result);
    ref.read(cartProvider.notifier).setCustomer(customer);
  }

  Future<void> _editDiscount(CartTab tab) async {
    final controller = TextEditingController(
      text: tab.discount > 0 ? tab.discount.toStringAsFixed(2) : '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discount'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Discount amount',
            prefixText: 'Br ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim()) ?? 0;
              Navigator.of(
                context,
              ).pop(parsed.clamp(0, tab.subtotal).toDouble());
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      ref.read(cartProvider.notifier).setDiscount(value);
    }
  }

  Future<void> _checkout(CartTab cart) async {
    Customer? customer;
    if (cart.customerId != null) {
      customer = await ref
          .read(customerRepositoryProvider)
          .byId(cart.customerId!);
    }
    if (!mounted) return;

    final paid = await showDialog<double>(
      context: context,
      builder: (context) => _PaymentDialog(
        total: cart.total,
        customerName: customer?.name ?? cart.customerName,
        hasCustomer: customer != null,
      ),
    );
    if (paid == null || !mounted) return;

    try {
      final result = await ref
          .read(salesRepositoryProvider)
          .checkout(
            cart: cart,
            customer: customer,
            walkInName: customer == null ? 'Walk-in customer' : null,
            paidInput: paid,
          );

      ref.read(cartProvider.notifier).clearActive();
      ref.invalidate(dashboardProvider);
      ref.invalidate(productsProvider);
      ref.invalidate(customersProvider);
      ref.invalidate(pendingSyncProvider);
      if (customer != null) {
        ref.invalidate(customerDetailProvider(customer.id));
      }
      unawaited(ref.read(syncRepositoryProvider).flush().catchError((_) => 0));

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _ReceiptDialog(result: result),
      );
    } on CheckoutException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cart = cartState.active;
    const allProductsQuery = ProductQuery(pageSize: 1000);
    final products =
        ref.watch(productsProvider(allProductsQuery)).asData?.value ??
        const <Product>[];
    final query = _query.trim().toLowerCase();
    final results =
        (query.isEmpty
                ? products
                : products.where((product) {
                    return product.name.toLowerCase().contains(query) ||
                        (product.barcode ?? '').contains(query);
                  }).toList())
            .take(30)
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CartTabs(state: cartState),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 900;
                    final left = _ProductPicker(
                      search: _search,
                      query: _query,
                      onQueryChanged: (value) => setState(() => _query = value),
                      products: results,
                      allProductCount: products.length,
                      cart: cart,
                      onAdd: (product) =>
                          ref.read(cartProvider.notifier).addProduct(product),
                    );
                    final right = _CartPanel(
                      cart: cart,
                      onCustomer: () => _chooseCustomer(cart),
                      onDiscount: () => _editDiscount(cart),
                      onQty: (id, qty) =>
                          ref.read(cartProvider.notifier).setQuantity(id, qty),
                      onRemove: (id) =>
                          ref.read(cartProvider.notifier).removeLine(id),
                      onCheckout: () => _checkout(cart),
                      onClear: () =>
                          ref.read(cartProvider.notifier).clearActive(),
                    );
                    if (!wide) {
                      return Column(
                        children: [left, const SizedBox(height: 14), right],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: left),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: right),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CartTabs extends ConsumerWidget {
  const _CartTabs({required this.state});

  final CartState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(cartProvider.notifier);
    return SectionCard(
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            ...state.tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              final selected = index == state.activeIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InputChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: Icon(
                    Icons.shopping_basket_outlined,
                    size: 17,
                    color: selected ? AppColors.seed : AppColors.muted,
                  ),
                  label: Text(
                    tab.customerName == null
                        ? tab.label
                        : '${tab.label} • ${tab.customerName}',
                  ),
                  labelStyle: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? AppColors.seed : AppColors.ink,
                    fontSize: 12.5,
                  ),
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.seed.withValues(alpha: 0.1),
                  side: BorderSide(
                    color: selected ? AppColors.seed : AppColors.border,
                  ),
                  onPressed: () => controller.selectTab(index),
                  onDeleted: state.tabs.length > 1
                      ? () => controller.closeTab(tab.id)
                      : null,
                  deleteIconColor: AppColors.muted,
                ),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New cart'),
              onPressed: controller.addTab,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({
    required this.search,
    required this.query,
    required this.onQueryChanged,
    required this.products,
    required this.allProductCount,
    required this.cart,
    required this.onAdd,
  });

  final TextEditingController search;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final List<Product> products;
  final int allProductCount;
  final CartTab cart;
  final ValueChanged<Product> onAdd;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: search,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search product or barcode…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        search.clear();
                        onQueryChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (allProductCount == 0)
            const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No products yet',
              message:
                  'Open the Products tab and download the SUQ library to start selling.',
            )
          else if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No matching products.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: products.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = products[index];
                  final inCart = cart.lines
                      .where((line) => line.productId == product.id)
                      .fold<double>(0, (sum, line) => sum + line.qty);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => onAdd(product),
                    title: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${money(product.sellingPrice)} / ${product.unit}'
                      '${product.trackStock ? ' • ${qty(product.stockQty)} in stock' : ''}'
                      '${product.buyingPrice == null ? ' • no cost set' : ''}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (inCart > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.seed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${qty(inCart)} in cart',
                              style: const TextStyle(
                                color: AppColors.seed,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.add_circle_rounded,
                          color: AppColors.seed,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.cart,
    required this.onCustomer,
    required this.onDiscount,
    required this.onQty,
    required this.onRemove,
    required this.onCheckout,
    required this.onClear,
  });

  final CartTab cart;
  final VoidCallback onCustomer;
  final VoidCallback onDiscount;
  final void Function(String productId, double qty) onQty;
  final ValueChanged<String> onRemove;
  final VoidCallback onCheckout;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                cart.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (cart.lines.isNotEmpty)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                  label: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onCustomer,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.seed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cart.customerName ?? 'Walk-in customer',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Text(
                    'Change',
                    style: TextStyle(
                      color: AppColors.seed,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (cart.lines.isEmpty)
            const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Cart is empty',
              message: 'Tap a product on the left to add it.',
            )
          else ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 330),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cart.lines.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final line = cart.lines[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${money(line.unitPrice)} / ${line.unit}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _QtyStepper(
                          value: line.qty,
                          unit: line.unit,
                          onChanged: (value) => onQty(line.productId, value),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: Text(
                            money(line.total),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onRemove(line.productId),
                          icon: const Icon(Icons.close_rounded, size: 17),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 24),
            KeyValueRow(label: 'Subtotal', value: money(cart.subtotal)),
            InkWell(
              onTap: onDiscount,
              child: KeyValueRow(
                label: 'Discount',
                value: cart.discount > 0
                    ? '- ${money(cart.discount)}'
                    : 'Add discount',
                valueColor: cart.discount > 0 ? AppColors.loss : AppColors.seed,
              ),
            ),
            const Divider(height: 18),
            Row(
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  money(cart.total),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              cart.hasMissingCost
                  ? 'Estimated profit ${money(cart.profit)} (some costs missing)'
                  : 'Estimated profit ${money(cart.profit)}',
              style: TextStyle(
                fontSize: 11.5,
                color: cart.profit >= 0 ? AppColors.profit : AppColors.loss,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: cart.lines.isEmpty ? null : onCheckout,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text('Charge ${money(cart.total)}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final double value;
  final String unit;
  final ValueChanged<double> onChanged;

  double get _step {
    final normalized = unit.trim().toLowerCase();
    if ([
      'g',
      'gram',
      'grams',
      'ml',
      'milliliter',
      'millilitre',
    ].contains(normalized))
      return 50;
    if ([
      'kg',
      'kilogram',
      'kilograms',
      'l',
      'liter',
      'litre',
      'liters',
      'litres',
      'm',
    ].contains(normalized))
      return 0.05;
    return 1;
  }

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: qty(value));
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantity in $unit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(labelText: 'Amount ($unit)'),
          onSubmitted: (_) =>
              Navigator.pop(ctx, double.tryParse(controller.text.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: const Text('Set quantity'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount != null && amount > 0) onChanged(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onChanged(
              (value - _step).clamp(0.0, double.infinity).toDouble(),
            ),
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(Icons.remove_rounded, size: 16),
            ),
          ),
          SizedBox(
            width: 42,
            child: InkWell(
              onTap: () => _edit(context),
              child: Text(
                qty(value),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: () => onChanged(value + _step),
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(Icons.add_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.total,
    required this.customerName,
    required this.hasCustomer,
  });

  final double total;
  final String? customerName;
  final bool hasCustomer;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController _paid = TextEditingController(
    text: widget.total.toStringAsFixed(2),
  );

  @override
  void dispose() {
    _paid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paidInput = double.tryParse(_paid.text.trim()) ?? 0;
    final paid = paidInput.clamp(0, widget.total).toDouble();
    final change = (paidInput - widget.total)
        .clamp(0, double.infinity)
        .toDouble();
    final credit = widget.total - paid;
    final creditBlocked = credit > 0.009 && !widget.hasCustomer;

    return AlertDialog(
      title: const Text('Take payment'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.seed.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.customerName ?? 'Walk-in customer',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    money(widget.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _paid,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Amount received',
                prefixText: 'Br ',
                helperText:
                    'Enter the full amount for cash, or less for credit.',
              ),
            ),
            const SizedBox(height: 12),
            KeyValueRow(label: 'Paid', value: money(paid)),
            KeyValueRow(
              label: 'Change',
              value: money(change),
              valueColor: change > 0 ? AppColors.profit : null,
            ),
            KeyValueRow(
              label: 'Credit (ዱቤ)',
              value: money(credit),
              valueColor: credit > 0 ? AppColors.warning : null,
              bold: credit > 0,
            ),
            if (creditBlocked) ...[
              const SizedBox(height: 8),
              const Text(
                'Choose a customer first to record credit.',
                style: TextStyle(color: AppColors.loss, fontSize: 12),
              ),
            ],
            if (credit > 0 && widget.hasCustomer) ...[
              const SizedBox(height: 8),
              Text(
                'This will be added to ${widget.customerName}’s balance.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
        FilledButton(
          onPressed: creditBlocked
              ? null
              : () => Navigator.of(context).pop(paidInput),
          child: const Text('Confirm sale'),
        ),
      ],
    );
  }
}

class _ReceiptDialog extends StatelessWidget {
  const _ReceiptDialog({required this.result});

  final CheckoutResult result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.profit),
          SizedBox(width: 8),
          Text('Sale recorded'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.profit.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    result.receiptNo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    money(result.total),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            KeyValueRow(
              label: 'Customer',
              value: result.customerName ?? 'Walk-in',
            ),
            KeyValueRow(label: 'Paid', value: money(result.paid)),
            if (result.change > 0)
              KeyValueRow(
                label: 'Change',
                value: money(result.change),
                valueColor: AppColors.profit,
              ),
            if (result.credit > 0)
              KeyValueRow(
                label: 'Added to credit',
                value: money(result.credit),
                valueColor: AppColors.warning,
                bold: true,
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
