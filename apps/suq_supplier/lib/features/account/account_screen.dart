import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _baseFee = TextEditingController();
  final _perKm = TextEditingController();
  final _perKg = TextEditingController();
  final _perCubicMeter = TextEditingController();

  bool _initialised = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(profileProvider).asData?.value;
    if (cached != null) {
      _initialised = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _populate(cached));
      });
    }
  }

  @override
  void dispose() {
    _businessName.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _baseFee.dispose();
    _perKm.dispose();
    _perKg.dispose();
    _perCubicMeter.dispose();
    super.dispose();
  }

  String _numberText(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();

  void _populate(SupplierProfile profile) {
    _businessName.text = profile.businessName;
    _latitude.text = profile.latitude == null
        ? ''
        : profile.latitude!.toStringAsFixed(6);
    _longitude.text = profile.longitude == null
        ? ''
        : profile.longitude!.toStringAsFixed(6);
    _baseFee.text = _numberText(profile.deliveryBaseFee);
    _perKm.text = _numberText(profile.deliveryPerKm);
    _perKg.text = _numberText(profile.deliveryPerKg);
    _perCubicMeter.text = _numberText(profile.deliveryPerCubicMeter);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final latitude = _latitude.text.trim();
    final longitude = _longitude.text.trim();

    final body = <String, dynamic>{
      'businessName': _businessName.text.trim(),
      'latitude': latitude.isEmpty ? null : double.parse(latitude),
      'longitude': longitude.isEmpty ? null : double.parse(longitude),
      'deliveryBaseFee': double.tryParse(_baseFee.text.trim()) ?? 0,
      'deliveryPerKm': double.tryParse(_perKm.text.trim()) ?? 0,
      'deliveryPerKg': double.tryParse(_perKg.text.trim()) ?? 0,
      'deliveryPerCubicMeter':
          double.tryParse(_perCubicMeter.text.trim()) ?? 0,
    };

    setState(() => _saving = true);
    try {
      final response = await ref.read(apiProvider).patch(
            '/supplier/profile',
            body: body,
          );
      final updated = SupplierProfile.fromJson(asMap(response['supplier']));
      if (!mounted) return;
      ref.read(sessionProvider.notifier).updateSupplier(updated);
      ref.invalidate(profileProvider);
      _populate(updated);
      showAppSnack(context, 'Account details saved.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await confirmAction(
      context,
      title: 'Sign out?',
      message:
          'You will need your supplier phone number and PIN to sign in again.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed) return;
    if (!mounted) return;
    await ref.read(sessionProvider.notifier).logout();
  }

  String? _coordinateError(String? value, {required bool latitude}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter a number';
    if (latitude && (parsed < -90 || parsed > 90)) {
      return 'Must be between -90 and 90';
    }
    if (!latitude && (parsed < -180 || parsed > 180)) {
      return 'Must be between -180 and 180';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final session = ref.watch(sessionProvider);
    final categories = ref.watch(categoriesProvider).asData?.value;
    final products = ref.watch(productsProvider).asData?.value;
    final listings = ref.watch(listingsProvider).asData?.value;
    final orders = ref.watch(ordersProvider).asData?.value;

    ref.listen<AsyncValue<SupplierProfile>>(profileProvider, (previous, next) {
      final data = next.asData?.value;
      if (data != null && !_initialised) {
        _initialised = true;
        _populate(data);
      }
    });

    final profile = profileAsync.asData?.value;

    if (profileAsync.hasError && profile == null) {
      return ErrorView(
        message: profileAsync.error.toString(),
        onRetry: () => ref.invalidate(profileProvider),
      );
    }
    if (profile == null) {
      return const LoadingView(message: 'Loading your account…');
    }

    final form = _ProfileForm(
      formKey: _formKey,
      businessName: _businessName,
      latitude: _latitude,
      longitude: _longitude,
      baseFee: _baseFee,
      perKm: _perKm,
      perKg: _perKg,
      perCubicMeter: _perCubicMeter,
      coordinateError: _coordinateError,
      saving: _saving,
      onSave: _save,
    );

    final side = _AccountSidePanel(
      user: session.user,
      profile: profile,
      categoryCount: categories
          ?.where((category) => category.supplierId == profile.id)
          .length,
      productCount: products
          ?.where((product) => product.supplierId == profile.id)
          .length,
      listingCount: listings?.length,
      activeListingCount:
          listings?.where((listing) => listing.active).length,
      orderCount: orders?.length,
      pendingOrderCount: orders?.where((order) => order.isPending).length,
      onSignOut: _signOut,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(profileProvider);
        ref.invalidate(categoriesProvider);
        ref.invalidate(productsProvider);
        ref.invalidate(listingsProvider);
        ref.invalidate(ordersProvider);
        await ref.read(profileProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PageHeader(
                    title: 'Account',
                    subtitle:
                        'Your business identity, pickup location and delivery pricing.',
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 860) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            form,
                            const SizedBox(height: 16),
                            side,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: form),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: side),
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
  }
}

class _ProfileForm extends StatelessWidget {
  const _ProfileForm({
    required this.formKey,
    required this.businessName,
    required this.latitude,
    required this.longitude,
    required this.baseFee,
    required this.perKm,
    required this.perKg,
    required this.perCubicMeter,
    required this.coordinateError,
    required this.saving,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController businessName;
  final TextEditingController latitude;
  final TextEditingController longitude;
  final TextEditingController baseFee;
  final TextEditingController perKm;
  final TextEditingController perKg;
  final TextEditingController perCubicMeter;
  final String? Function(String?, {required bool latitude}) coordinateError;
  final bool saving;
  final Future<void> Function() onSave;

  String? _validateFee(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null || parsed < 0) return 'Enter a valid amount';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionTitle(
                  icon: Icons.storefront_outlined,
                  title: 'Business profile',
                  subtitle: 'How shops recognise you on their orders.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: businessName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Business name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter your business name'
                      : null,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pickup location',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: SupplierColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Shops get an automatic delivery estimate from this point. Leave both fields empty to quote deliveries manually.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: SupplierColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: latitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[-0-9.]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          hintText: 'e.g. 9.0108',
                        ),
                        validator: (value) =>
                            coordinateError(value, latitude: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: longitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[-0-9.]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          hintText: 'e.g. 38.7613',
                        ),
                        validator: (value) =>
                            coordinateError(value, latitude: false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionTitle(
                  icon: Icons.local_shipping_outlined,
                  title: 'Delivery pricing',
                  subtitle:
                      'You decide the rates used to suggest a fee for every shop order.',
                ),
                const SizedBox(height: 14),
                const InfoBanner(
                  icon: Icons.calculate_outlined,
                  message:
                      'Suggested fee = base fee + (distance × rate per km) + (order weight × rate per kg) + (order space × rate per m³). You can override the fee on any order.',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: baseFee,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Base fee (Br)',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        validator: _validateFee,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: perKm,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Rate per km (Br)',
                          prefixIcon: Icon(Icons.route_outlined),
                        ),
                        validator: _validateFee,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: perKg,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Rate per kg (Br)',
                          prefixIcon: Icon(Icons.scale_outlined),
                        ),
                        validator: _validateFee,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: perCubicMeter,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Rate per m³ (Br)',
                          prefixIcon: Icon(Icons.view_in_ar_outlined),
                        ),
                        validator: _validateFee,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _DeliveryPreview(
                  baseFee: baseFee,
                  perKm: perKm,
                  perKg: perKg,
                  perCubicMeter: perCubicMeter,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: saving ? null : () => onSave(),
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 19),
                  label: Text(saving ? 'Saving…' : 'Save changes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryPreview extends StatelessWidget {
  const _DeliveryPreview({
    required this.baseFee,
    required this.perKm,
    required this.perKg,
    required this.perCubicMeter,
  });

  final TextEditingController baseFee;
  final TextEditingController perKm;
  final TextEditingController perKg;
  final TextEditingController perCubicMeter;

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([baseFee, perKm, perKg, perCubicMeter]),
      builder: (context, _) {
        final fee = _value(baseFee) +
            (5 * _value(perKm)) +
            (10 * _value(perKg)) +
            (0.05 * _value(perCubicMeter));
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SupplierColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SupplierColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 18,
                color: SupplierColors.seed,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Example: 5 km · 10 kg · 0.05 m³ → ${money(fee)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: SupplierColors.ink,
                    fontWeight: FontWeight.w600,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: SupplierColors.seed.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: SupplierColors.seed),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: SupplierColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: SupplierColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountSidePanel extends StatelessWidget {
  const _AccountSidePanel({
    required this.user,
    required this.profile,
    required this.categoryCount,
    required this.productCount,
    required this.listingCount,
    required this.activeListingCount,
    required this.orderCount,
    required this.pendingOrderCount,
    required this.onSignOut,
  });

  final SupplierUser? user;
  final SupplierProfile profile;
  final int? categoryCount;
  final int? productCount;
  final int? listingCount;
  final int? activeListingCount;
  final int? orderCount;
  final int? pendingOrderCount;
  final Future<void> Function() onSignOut;

  String _count(int? value) => value == null ? '—' : '$value';

  @override
  Widget build(BuildContext context) {
    final initials = user?.initials ?? 'S';
    final name = user?.name ?? profile.businessName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        SupplierColors.seed.withValues(alpha: 0.12),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: SupplierColors.seed,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: SupplierColors.ink,
                          ),
                        ),
                        Text(
                          profile.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: SupplierColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              KeyValueRow(
                label: 'Phone number',
                value: user?.phone.isNotEmpty == true ? user!.phone : '—',
              ),
              KeyValueRow(
                label: 'Account type',
                value: 'Supplier',
              ),
              KeyValueRow(
                label: 'Pickup location',
                value: profile.hasLocation ? 'Set' : 'Not set',
                valueColor: profile.hasLocation
                    ? SupplierColors.success
                    : SupplierColors.warning,
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionTitle(
                icon: Icons.insights_outlined,
                title: 'Workspace summary',
                subtitle: 'Everything connected to this supplier account.',
              ),
              const SizedBox(height: 12),
              KeyValueRow(
                label: 'Catalog products',
                value: _count(productCount),
              ),
              KeyValueRow(
                label: 'Categories',
                value: _count(categoryCount),
              ),
              KeyValueRow(
                label: 'Listings',
                value: listingCount == null
                    ? '—'
                    : '${_count(activeListingCount)} visible of ${_count(listingCount)}',
              ),
              KeyValueRow(
                label: 'Shop orders',
                value: orderCount == null
                    ? '—'
                    : '${_count(orderCount)} total',
              ),
              KeyValueRow(
                label: 'Orders awaiting review',
                value: _count(pendingOrderCount),
                valueColor: (pendingOrderCount ?? 0) > 0
                    ? SupplierColors.warning
                    : null,
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Session',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: SupplierColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Signing out clears this device. Your catalog and listings stay on the SUQ server.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: SupplierColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => onSignOut(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SupplierColors.danger,
                  side: BorderSide(
                    color: SupplierColors.danger.withValues(alpha: 0.4),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
