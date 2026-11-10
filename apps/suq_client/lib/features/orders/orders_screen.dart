import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _orders = [];
  String? _supplierId;
  final Map<String, int> _cart = {};
  double? _latitude;
  double? _longitude;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final results = await Future.wait([
        api.get('/orders/suppliers'),
        api.get('/orders'),
      ]);
      if (!mounted) return;
      setState(() {
        _suppliers = (results[0]['suppliers'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _orders = (results[1]['orders'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (_supplierId == null && _suppliers.isNotEmpty)
          _supplierId = _suppliers.first['id'] as String?;
        if (_supplierId != null &&
            !_suppliers.any((s) => s['id'] == _supplierId))
          _supplierId = _suppliers.isEmpty
              ? null
              : _suppliers.first['id'] as String?;
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error is ApiException ? error.message : error.toString();
        });
    }
  }

  Map<String, dynamic>? get _selectedSupplier {
    for (final supplier in _suppliers) {
      if (supplier['id'] == _supplierId) return supplier;
    }
    return null;
  }

  List<Map<String, dynamic>> get _listings =>
      ((_selectedSupplier?['listings'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => e['active'] == true)
          .toList();
  double get _subtotal => _listings.fold<double>(
    0,
    (sum, item) =>
        sum +
        ((item['pricePerUnit'] as num?)?.toDouble() ?? 0) *
            (_cart[item['id']] ?? 0),
  );

  int _minOrder(Map<String, dynamic> listing) =>
      ((listing['minOrderQty'] as num?)?.toInt() ?? 1).clamp(1, 10000).toInt();

  Future<void> _useLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled())
        throw Exception('Turn on location services first.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        throw Exception(
          'Location permission was not granted. You can still order without a pin.',
        );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (mounted)
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
    } catch (error) {
      if (mounted)
        showAppSnack(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
    }
  }

  Future<void> _submitOrder() async {
    if (_supplierId == null || _cart.isEmpty) return;
    setState(() => _busy = true);
    try {
      final response = await ref
          .read(apiProvider)
          .post(
            '/orders',
            body: {
              'supplierId': _supplierId,
              if (_latitude != null && _longitude != null)
                'latitude': _latitude,
              if (_latitude != null && _longitude != null)
                'longitude': _longitude,
              'items': _cart.entries
                  .where((e) => e.value > 0)
                  .map((e) => {'listingId': e.key, 'quantity': e.value})
                  .toList(),
            },
          );
      final order = Map<String, dynamic>.from(response['order'] as Map);
      if (!mounted) return;
      setState(() => _cart.clear());
      showAppSnack(
        context,
        'Order sent: ${money((order['total'] as num?) ?? 0)}${response['needsDistanceQuote'] == true ? ' · supplier will confirm distance delivery' : ''}',
      );
      await _load();
    } catch (error) {
      if (mounted)
        showAppSnack(context, 'Could not send order: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          if (_suppliers.isEmpty)
            EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No supplier listings yet',
              message:
                  'Suppliers will appear here when they publish wholesale listings. Tap refresh after they publish.',
              action: OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _supplierId,
                    decoration: const InputDecoration(
                      labelText: 'Choose supplier',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    items: [
                      for (final supplier in _suppliers)
                        DropdownMenuItem(
                          value: supplier['id'] as String?,
                          child: Text('${supplier['businessName']}'),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _supplierId = value;
                      _cart.clear();
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Refresh supplier listings',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final listing in _listings) _listingCard(listing),
            if (_listings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('This supplier has no active listings.'),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _useLocation,
              icon: const Icon(Icons.my_location_rounded),
              label: Text(
                _latitude == null
                    ? 'Add shop delivery location (optional)'
                    : 'Location added',
              ),
            ),
            if (_latitude != null)
              Text(
                'Delivery pin: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            if (_cart.isNotEmpty) ...[
              const Divider(height: 28),
              KeyValueRow(label: 'Products', value: money(_subtotal)),
              const SizedBox(height: 4),
              const Text(
                'Delivery is calculated from route distance, order weight, and package volume.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _busy ? null : _submitOrder,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Place supplier order'),
              ),
            ],
          ],
          const SizedBox(height: 24),
          const Text(
            'My supplier orders',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_orders.isEmpty)
            const Text(
              'Orders you place will appear here.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            for (final order in _orders) _orderCard(order),
        ],
      ),
    );
  }

  Widget _listingCard(Map<String, dynamic> listing) {
    final id = listing['id'].toString();
    final name = listing['name']?.toString() ?? 'Listing';
    final saleUnit = listing['saleUnit']?.toString() ?? 'piece';
    final category = listing['category']?.toString() ?? '';
    final price = (listing['pricePerUnit'] as num?)?.toDouble() ?? 0;
    final pieces = (listing['piecesPerUnit'] as num?)?.toInt() ?? 1;
    final pack = pieces > 1 ? ' · $pieces pcs / $saleUnit' : '';
    final weight = (listing['weightPerUnitKg'] as num?)?.toDouble() ?? 0;
    final volume = (listing['volumePerUnitM3'] as num?)?.toDouble() ?? 0;
    final length = (listing['lengthCm'] as num?)?.toDouble() ?? 0;
    final width = (listing['widthCm'] as num?)?.toDouble() ?? 0;
    final height = (listing['heightCm'] as num?)?.toDouble() ?? 0;
    final minOrder = _minOrder(listing);
    final count = _cart[id] ?? 0;
    final dimensions = length > 0 && width > 0 && height > 0
        ? ' · ${length.toStringAsFixed(0)}×${width.toStringAsFixed(0)}×${height.toStringAsFixed(0)} cm'
        : '';
    final publisher = listing['publishedBy'] is Map
        ? (listing['publishedBy'] as Map)['name']?.toString() ?? ''
        : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFE5F2EE),
              child: Icon(Icons.sell_outlined, color: AppColors.seed),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${category.isEmpty ? '' : '$category · '}${money(price)} / $saleUnit$pack · min $minOrder',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    '${weight.toStringAsFixed(weight == weight.roundToDouble() ? 0 : 2)} kg · ${volume.toStringAsFixed(4)} m³$dimensions',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  if (publisher.isNotEmpty)
                    Text(
                      'Published by $publisher',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: count == 0
                  ? null
                  : () => setState(() {
                      if (count <= minOrder) {
                        _cart.remove(id);
                      } else {
                        _cart[id] = count - 1;
                      }
                    }),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
            IconButton(
              onPressed: () => setState(() {
                _cart[id] = count == 0 ? minOrder : count + 1;
              }),
              icon: const Icon(Icons.add_circle_outline, color: AppColors.seed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final supplier = Map<String, dynamic>.from(
      order['supplier'] as Map? ?? const {},
    );
    final acceptedBy = order['acceptedBy'] is Map
        ? (order['acceptedBy'] as Map)['name']?.toString() ?? ''
        : '';
    final items = order['items'] as List? ?? [];
    return Card(
      child: ExpansionTile(
        title: Text(supplier['businessName']?.toString() ?? 'Supplier order'),
        subtitle: Text(
          '${order['status']} · ${money((order['total'] as num?) ?? 0)}',
        ),
        children: [
          for (final raw in items)
            ListTile(
              dense: true,
              title: Text(
                '${raw['quantity']} × ${raw['listingName']}',
              ),
              subtitle: Text(
                '${money((raw['unitPrice'] as num?) ?? 0)} per ${raw['saleUnit'] ?? 'unit'}',
              ),
            ),
          if (acceptedBy.isNotEmpty)
            ListTile(
              dense: true,
              leading: const Icon(
                Icons.verified_outlined,
                size: 18,
                color: AppColors.seed,
              ),
              title: Text('Accepted by $acceptedBy'),
            ),
          if (order['deliveryQuoted'] != true)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Distance based delivery is awaiting supplier confirmation.',
                style: TextStyle(color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}
