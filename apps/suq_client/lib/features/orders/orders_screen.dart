import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/location_picker.dart';
import 'delivery_quote.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with WidgetsBindingObserver {
  static const _pageSize = 10;
  // Favorites are intentionally device-local (SharedPreferences). They are not
  // written to SQLite and never sent to the server.
  static const _favoritesKey = 'supplier.favorites';
  static const _cartKey = 'supplier.cart';

  List<Map<String, dynamic>> _listings = [];
  // Every listing this session has seen, keyed by id. Used to keep cart items
  // from earlier pages in sync without re-downloading the whole catalog.
  final Map<String, Map<String, dynamic>> _listingCache = {};
  List<Map<String, dynamic>> _orders = [];
  final Map<String, _CartEntry> _cart = {};
  final Set<String> _favorites = {};
  // Warehouse and transport rates per supplier, loaded with the listings.
  final Map<String, DeliveryRates> _suppliers = {};
  // Transport estimate per supplier, calculated on the client.
  final Map<String, DeliveryQuote> _quotes = {};
  final TextEditingController _search = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  bool _favoritesOnly = false;
  int _listingPage = 1;
  int _listingTotal = 0;
  int _ordersPage = 1;
  int _ordersTotal = 0;
  late DateTime _ordersFrom;
  late DateTime _ordersTo;
  double? _latitude;
  double? _longitude;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _ordersTo = DateTime(today.year, today.month, today.day);
    _ordersFrom = _ordersTo.subtract(const Duration(days: 30));
    WidgetsBinding.instance.addObserver(this);
    _restoreLocalState();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  void _restoreLocalState() {
    final prefs = ref.read(prefsProvider);
    final shop = ref.read(sessionProvider).shop;
    _latitude = shop?.latitude ?? prefs.getDouble('shop.latitude');
    _longitude = shop?.longitude ?? prefs.getDouble('shop.longitude');
    _favorites
      ..clear()
      ..addAll(prefs.getStringList(_favoritesKey) ?? const <String>[]);

    final raw = prefs.getString(_cartKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final value in decoded.values) {
        if (value is! Map) continue;
        final entry = _CartEntry.fromJson(Map<String, dynamic>.from(value));
        if (entry.listingId.isEmpty ||
            entry.supplierId.isEmpty ||
            entry.qty <= 0) {
          continue;
        }
        _cart[entry.listingId] = entry;
      }
    } catch (_) {
      _cart.clear();
    }
  }

  Future<void> _load() async {
    await Future.wait([_loadListings(), _loadOrders()]);
  }

  Future<void> _loadListings() async {
    if (!mounted) return;
    setState(() {
      if (_listings.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiProvider).get(
            '/orders/suppliers',
            query: {
              'page': '$_listingPage',
              'pageSize': '$_pageSize',
              if (_query.trim().isNotEmpty) 'q': _query.trim(),
              if (_favoritesOnly)
                'ids': _favorites.isEmpty ? '__none__' : _favorites.join(','),
            },
          );
      if (!mounted) return;

      final flattened = <Map<String, dynamic>>[];
      final suppliers = <String, DeliveryRates>{};
      for (final raw in (response['suppliers'] as List? ?? [])) {
        if (raw is! Map) continue;
        final supplier = Map<String, dynamic>.from(raw);
        final supplierId = supplier['id']?.toString() ?? '';
        final supplierName =
            supplier['businessName']?.toString() ?? 'Supplier';
        if (supplierId.isNotEmpty) {
          suppliers[supplierId] = DeliveryRates.fromJson(supplier);
        }
        for (final item in (supplier['listings'] as List? ?? [])) {
          if (item is! Map) continue;
          final listing = Map<String, dynamic>.from(item);
          if (listing['active'] != true) continue;
          listing['supplierId'] = supplierId;
          listing['supplierName'] = supplierName;
          flattened.add(listing);
          final id = listing['id']?.toString() ?? '';
          if (id.isNotEmpty) _listingCache[id] = listing;
        }
      }

      setState(() {
        _listings = flattened;
        _listingTotal = asInt(response['total']);
        // Keep rates from other pages: a cart can span several pages.
        _suppliers.addAll(suppliers);
        _reconcileCart();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error is ApiException ? error.message : error.toString();
        });
      }
    }
  }

  Future<void> _loadOrders() async {
    try {
      final response = await ref.read(apiProvider).get(
            '/orders',
            query: {
              'page': '$_ordersPage',
              'pageSize': '$_pageSize',
              'from': _ordersFromIso,
              'to': _ordersToIso,
            },
          );
      if (!mounted) return;
      final orders = (response['orders'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _orders = orders;
        _ordersTotal = asInt(response['total']);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ApiException ? error.message : error.toString();
        });
      }
    }
  }

  void _reconcileCart() {
    for (final id in _cart.keys.toList()) {
      final listing = _listingCache[id];
      if (listing == null) {
        // The listing may simply be on a page we have not opened this session.
        // Keep the cart line instead of dropping it; the server validates
        // availability again when the order is submitted.
        continue;
      }
      final entry = _cart[id]!;
      final minOrder = _minOrder(listing);
      _cart[id] = entry.copyWith(
        supplierId: listing['supplierId']?.toString() ?? entry.supplierId,
        supplierName:
            listing['supplierName']?.toString() ?? entry.supplierName,
        name: listing['name']?.toString() ?? entry.name,
        saleUnit: listing['saleUnit']?.toString() ?? entry.saleUnit,
        price: ((listing['pricePerUnit']) is num ? (listing['pricePerUnit'] as num).toDouble() : null) ?? entry.price,
        minOrder: minOrder,
        qty: entry.qty < minOrder ? minOrder : entry.qty,
        weightPerUnitKg: ((listing['weightPerUnitKg']) is num ? (listing['weightPerUnitKg'] as num).toDouble() : null) ??
            entry.weightPerUnitKg,
        volumePerUnitM3: ((listing['volumePerUnitM3']) is num ? (listing['volumePerUnitM3'] as num).toDouble() : null) ??
            entry.volumePerUnitM3,
        lengthCm: ((listing['lengthCm']) is num ? (listing['lengthCm'] as num).toDouble() : null) ?? entry.lengthCm,
        widthCm: ((listing['widthCm']) is num ? (listing['widthCm'] as num).toDouble() : null) ?? entry.widthCm,
        heightCm: ((listing['heightCm']) is num ? (listing['heightCm'] as num).toDouble() : null) ?? entry.heightCm,
      );
    }

    _persistCart();
    _recalculateQuotes();
  }

  void _persistCart() {
    unawaited(
      ref.read(prefsProvider).setString(
            _cartKey,
            jsonEncode({
              for (final entry in _cart.entries)
                entry.key: entry.value.toJson(),
            }),
          ),
    );
  }

  void _persistFavorites() {
    final values = _favorites.toList()..sort();
    unawaited(ref.read(prefsProvider).setStringList(_favoritesKey, values));
  }

  int _minOrder(Map<String, dynamic> listing) =>
      (((listing['minOrderQty']) is num ? (listing['minOrderQty'] as num) : null)?.toInt() ?? 1).clamp(1, 10000).toInt();

  List<Map<String, dynamic>> get _filteredListings => _listings;

  int get _pageCount => math.max(1, (_listingTotal / _pageSize).ceil());

  int get _currentPage => math.min(math.max(_listingPage, 1), _pageCount);

  List<Map<String, dynamic>> get _pagedListings => _listings;

  String get _ordersFromIso =>
      DateTime(_ordersFrom.year, _ordersFrom.month, _ordersFrom.day)
          .toUtc()
          .toIso8601String();

  String get _ordersToIso =>
      DateTime(_ordersTo.year, _ordersTo.month, _ordersTo.day, 23, 59, 59, 999)
          .toUtc()
          .toIso8601String();

  void _searchChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _listingPage = 1);
      _loadListings();
    });
  }

  void _setFavoritesOnly(bool value) {
    setState(() {
      _favoritesOnly = value;
      _listingPage = 1;
    });
    _loadListings();
  }

  void _goToListingPage(int page) {
    setState(() => _listingPage = page);
    _loadListings();
  }

  void _goToOrdersPage(int page) {
    setState(() => _ordersPage = page);
    _loadOrders();
  }

  Future<void> _pickOrdersRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _ordersFrom, end: _ordersTo),
      helpText: 'Orders between',
      saveText: 'Apply',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _ordersFrom =
          DateTime(picked.start.year, picked.start.month, picked.start.day);
      _ordersTo =
          DateTime(picked.end.year, picked.end.month, picked.end.day);
      _ordersPage = 1;
    });
    await _loadOrders();
  }

  double get _cartSubtotal =>
      _cart.values.fold<double>(0, (sum, entry) => sum + entry.total);

  int get _cartCount =>
      _cart.values.fold<int>(0, (sum, entry) => sum + entry.qty);

  void _toggleFavorite(String id) {
    setState(() {
      if (!_favorites.add(id)) _favorites.remove(id);
      _persistFavorites();
    });
  }

  void _setQty(String id, int quantity) {
    final entry = _cart[id];
    if (entry == null) return;
    setState(() {
      if (quantity <= 0) {
        _cart.remove(id);
      } else {
        // The API accepts at most 10,000 units per line.
        _cart[id] = entry.copyWith(qty: quantity.clamp(1, 10000).toInt());
      }
      _persistCart();
      _recalculateQuotes();
    });
  }

  void _addListing(Map<String, dynamic> listing) {
    final id = listing['id'].toString();
    final existing = _cart[id];
    if (existing != null) {
      _setQty(id, existing.qty + 1);
      return;
    }
    final supplierId = listing['supplierId']?.toString() ?? '';
    if (supplierId.isEmpty) {
      showAppSnack(
        context,
        'This listing is missing supplier details. Refresh and try again.',
        error: true,
      );
      return;
    }
    final minOrder = _minOrder(listing);
    setState(() {
      _cart[id] = _CartEntry(
        listingId: id,
        supplierId: supplierId,
        supplierName: listing['supplierName']?.toString() ?? 'Supplier',
        name: listing['name']?.toString() ?? 'Listing',
        saleUnit: listing['saleUnit']?.toString() ?? 'unit',
        price: ((listing['pricePerUnit']) is num ? (listing['pricePerUnit'] as num).toDouble() : null) ?? 0,
        minOrder: minOrder,
        qty: minOrder,
        weightPerUnitKg:
            ((listing['weightPerUnitKg']) is num ? (listing['weightPerUnitKg'] as num).toDouble() : null) ?? 0,
        volumePerUnitM3:
            ((listing['volumePerUnitM3']) is num ? (listing['volumePerUnitM3'] as num).toDouble() : null) ?? 0,
        lengthCm: ((listing['lengthCm']) is num ? (listing['lengthCm'] as num).toDouble() : null) ?? 0,
        widthCm: ((listing['widthCm']) is num ? (listing['widthCm'] as num).toDouble() : null) ?? 0,
        heightCm: ((listing['heightCm']) is num ? (listing['heightCm'] as num).toDouble() : null) ?? 0,
      );
      _persistCart();
      _recalculateQuotes();
    });
  }

  void _decrementListing(Map<String, dynamic> listing) {
    final id = listing['id'].toString();
    final entry = _cart[id];
    if (entry == null) return;
    _setQty(id, entry.qty <= entry.minOrder ? 0 : entry.qty - 1);
  }

  Map<String, List<_CartEntry>> _groupCart() {
    final groups = <String, List<_CartEntry>>{};
    for (final entry in _cart.values) {
      if (entry.supplierId.isEmpty) continue;
      groups.putIfAbsent(entry.supplierId, () => []).add(entry);
    }
    return groups;
  }

  /// Recalculates the transport estimate for every supplier in the cart.
  ///
  /// The calculation is synchronous and purely local, so it is safe to call
  /// from `setState` and from callbacks that may run after the screen has been
  /// disposed. The server still recalculates the fee when the order is sent.
  void _recalculateQuotes() {
    final next = <String, DeliveryQuote>{};
    if (_latitude != null && _longitude != null) {
      for (final group in _groupCart().entries) {
        final rates = _suppliers[group.key];
        if (rates == null) continue;
        final quote = quoteDelivery(
          supplier: rates,
          shopLatitude: _latitude,
          shopLongitude: _longitude,
          lines: group.value.map((entry) => entry.deliveryLine),
        );
        if (quote != null) next[group.key] = quote;
      }
    }
    _quotes
      ..clear()
      ..addAll(next);
  }

  double get _deliveryTotal => _quotes.values.fold<double>(
        0,
        (sum, quote) => sum + quote.deliveryFee,
      );

  double get _grandTotal => _cartSubtotal + _deliveryTotal;

  Future<void> _setLocation(double latitude, double longitude) async {
    if (!mounted) return;
    setState(() {
      _latitude = latitude;
      _longitude = longitude;
      _recalculateQuotes();
    });
    // Persist locally first; the session controller syncs the pin to the
    // server in the background and never blocks ordering offline.
    await ref.read(sessionProvider.notifier).updateShopLocation(
          latitude: latitude,
          longitude: longitude,
        );
  }

  Future<void> _pickLocation() async {
    final initial = _latitude != null && _longitude != null
        ? LatLng(_latitude!, _longitude!)
        : merkato;
    final picked = await showShopLocationPicker(context, initial: initial);
    if (picked == null || !mounted) return;
    await _setLocation(picked.latitude, picked.longitude);
  }

  Future<void> _useLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on location services first.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission was not granted. You can still pick a point on the map.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      await _setLocation(position.latitude, position.longitude);
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }

  Future<bool> _submitOrder() async {
    if (_busy || _cart.isEmpty) return false;

    final groups = <String, List<_CartEntry>>{};
    for (final entry in _cart.values) {
      if (entry.supplierId.isEmpty) continue;
      groups.putIfAbsent(entry.supplierId, () => []).add(entry);
    }
    if (groups.isEmpty) {
      showAppSnack(
        context,
        'None of the cart items has supplier details. Refresh and try again.',
        error: true,
      );
      return false;
    }

    setState(() => _busy = true);
    final sentIds = <String>[];
    var sentOrders = 0;
    var total = 0.0;
    var needsDistanceQuote = false;
    Object? firstError;

    for (final group in groups.values) {
      try {
        final response = await ref.read(apiProvider).post(
          '/orders',
          body: {
            'supplierId': group.first.supplierId,
            if (_latitude != null && _longitude != null) 'latitude': _latitude,
            if (_latitude != null && _longitude != null)
              'longitude': _longitude,
            'items': group
                .map(
                  (entry) => {
                    'listingId': entry.listingId,
                    'quantity': entry.qty,
                  },
                )
                .toList(),
          },
        );
        final order = Map<String, dynamic>.from(
          response['order'] as Map? ?? const {},
        );
        total += ((order['total']) is num ? (order['total'] as num).toDouble() : null) ?? 0;
        if (response['needsDistanceQuote'] == true) needsDistanceQuote = true;
        sentIds.addAll(group.map((entry) => entry.listingId));
        sentOrders++;
      } catch (error) {
        firstError ??= error;
      }
    }

    if (!mounted) return false;
    setState(() {
      for (final id in sentIds) {
        _cart.remove(id);
      }
      _quotes.clear();
      _busy = false;
      _persistCart();
    });

    if (sentOrders > 0 && firstError == null) {
      showAppSnack(
        context,
        'Sent $sentOrders order${sentOrders == 1 ? '' : 's'} · ${money(total)}'
        '${needsDistanceQuote ? ' · delivery will be quoted' : ''}',
      );
    } else if (sentOrders > 0) {
      showAppSnack(
        context,
        'Sent $sentOrders of ${groups.length} orders · ${money(total)}. '
        'The rest could not be sent: $firstError',
        error: true,
      );
    } else if (firstError != null) {
      showAppSnack(
        context,
        'Could not send the order: $firstError',
        error: true,
      );
    }
    if (sentOrders > 0) {
      setState(() {
        _listingPage = 1;
        _ordersPage = 1;
      });
      await _load();
    }
    return sentOrders == groups.length;
  }

  Future<void> _openCart() async {
    if (_cart.isEmpty) return;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void refresh() {
              if (!mounted) return;
              if (_cart.isEmpty) {
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                return;
              }
              setState(() {});
              setSheetState(() {});
            }

            return _cartSheet(sheetContext, refresh);
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  Widget _cartSheet(BuildContext sheetContext, VoidCallback refresh) {
    final groups = _groupCart();
    final grandTotal = _cartSubtotal + _deliveryTotal;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your cart',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                StatusChip(
                  label: '$_cartCount item${_cartCount == 1 ? '' : 's'}',
                  color: AppColors.supplier,
                  icon: Icons.shopping_bag_outlined,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _cartLocationRow(refresh),
            for (final group in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 2),
                child: Text(
                  group.value.first.supplierName,
                  style: const TextStyle(
                    color: AppColors.supplier,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final entry in group.value)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${money(entry.price)} / ${entry.saleUnit} · min ${entry.minOrder}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _setQty(
                            entry.listingId,
                            entry.qty <= entry.minOrder ? 0 : entry.qty - 1,
                          );
                          refresh();
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${entry.qty}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        onPressed: () {
                          _setQty(entry.listingId, entry.qty + 1);
                          refresh();
                        },
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.supplier,
                        ),
                      ),
                    ],
                  ),
                ),
              _quoteBreakdown(group.key),
            ],
            const Divider(height: 28),
            KeyValueRow(
              label: 'Products',
              value: money(_cartSubtotal),
              bold: true,
            ),
            KeyValueRow(
              label: 'Transport',
              value: _quotes.isNotEmpty ? money(_deliveryTotal) : 'Pending',
              valueColor: _quotes.isNotEmpty ? null : AppColors.warning,
            ),
            const Divider(height: 18),
            KeyValueRow(
              label: 'Total',
              value: money(grandTotal),
              bold: true,
            ),
            const SizedBox(height: 4),
            const Text(
              'Estimated transport = base fee + (distance from the warehouse × '
              'rate per km) + (order weight × rate per kg) + (order volume × '
              'rate per m³). Each supplier sets its own rates and ships from '
              'its own warehouse. The supplier confirms the final fee when '
              'accepting your order.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.supplier,
              ),
              onPressed: _busy
                  ? null
                  : () async {
                      final sent = await _submitOrder();
                      if (sent && sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      } else if (sheetContext.mounted) {
                        refresh();
                      }
                    },
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                'Send ${groups.length} order${groups.length == 1 ? '' : 's'} · ${money(grandTotal)}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartLocationRow(VoidCallback refresh) {
    final hasLocation = _latitude != null && _longitude != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.supplier.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            color: hasLocation ? AppColors.supplier : AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery to',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                Text(
                  hasLocation
                      ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                      : 'Choose your shop on the map',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await _pickLocation();
              refresh();
            },
            child: Text(hasLocation ? 'Change' : 'Choose'),
          ),
        ],
      ),
    );
  }

  Widget _quoteBreakdown(String supplierId) {
    final quote = _quotes[supplierId];
    if (quote == null) {
      final hasPin = _latitude != null && _longitude != null;
      return Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child: Text(
          hasPin
              ? 'Transport will be quoted by the supplier.'
              : 'Add your delivery pin on the map to get an automatic transport estimate.',
          style: TextStyle(
            fontSize: 12,
            color: hasPin ? AppColors.muted : AppColors.warning,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.supplier.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                size: 16,
                color: AppColors.supplier,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Transport from ${quote.warehouseName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.supplier,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          KeyValueRow(label: 'Base fee', value: money(quote.baseFee)),
          KeyValueRow(
            label: 'Distance · ${quote.distanceKm.toStringAsFixed(1)} km',
            value: money(quote.distanceFee),
          ),
          KeyValueRow(
            label: 'Weight · ${qty(quote.weightKg)} kg',
            value: money(quote.weightFee),
          ),
          KeyValueRow(
            label: 'Volume · ${qty(quote.volumeM3)} m³',
            value: money(quote.volumeFee),
          ),
          const Divider(height: 14),
          KeyValueRow(
            label: 'Transport total',
            value: money(quote.deliveryFee),
            bold: true,
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Estimate from your delivery pin. The supplier confirms the final fee.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppColors.supplier,
            indicatorColor: AppColors.supplier,
            unselectedLabelColor: AppColors.muted,
            tabs: [
              Tab(icon: Icon(Icons.storefront_outlined), text: 'Listings'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'My orders'),
            ],
          ),
          Expanded(
            child: Stack(
              children: [
                TabBarView(
                  children: [
                    _listingsTab(),
                    _ordersTab(),
                  ],
                ),
                if (_cart.isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _cartBar(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listingsTab() {
    if (_loading && _listings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _listings.isEmpty) {
      return _errorView();
    }

    final filtered = _filteredListings;
    final pageItems = _pagedListings;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const PageStorageKey('supplier-listings'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search listings, categories, suppliers',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        _searchDebounce?.cancel();
                        setState(() {
                          _query = '';
                          _listingPage = 1;
                        });
                        _loadListings();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: _searchChanged,
          ),
          const SizedBox(height: 10),
          _locationCard(),
          const SizedBox(height: 10),
          Row(
            children: [
              FilterChip(
                selected: _favoritesOnly,
                selectedColor: AppColors.supplier.withValues(alpha: 0.14),
                checkmarkColor: AppColors.supplier,
                avatar: Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: _favoritesOnly
                      ? AppColors.supplier
                      : AppColors.accent,
                ),
                label: Text('Favorites (${_favorites.length})'),
                onSelected: _setFavoritesOnly,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh listings',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            _inlineError(_error!),
          ],
          const SizedBox(height: 4),
          if (pageItems.isEmpty)
            _emptyListings(filtered)
          else
            for (final listing in pageItems) _listingCard(listing),
          if (_listingTotal > 0) _pagination(_listingTotal),
        ],
      ),
    );
  }

  Widget _ordersDateFilter() {
    return Row(
      children: [
        const Icon(Icons.date_range_rounded, size: 18, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${formatDate(_ordersFrom)} – ${formatDate(_ordersTo)}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
        TextButton(
          onPressed: _pickOrdersRange,
          child: const Text('Change'),
        ),
      ],
    );
  }

  Widget _ordersTab() {
    if (_loading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _orders.isEmpty) {
      return _errorView();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const PageStorageKey('supplier-orders'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _ordersDateFilter(),
          if (_error != null) ...[
            _inlineError(_error!),
            const SizedBox(height: 10),
          ],
          if (_orders.isEmpty)
            EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No orders in this period',
              message:
                  'Orders placed between ${formatDate(_ordersFrom)} and ${formatDate(_ordersTo)} will appear here.',
              action: TextButton.icon(
                onPressed: _pickOrdersRange,
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: const Text('Change dates'),
              ),
            )
          else ...[
            for (final order in _orders) _orderCard(order),
            if (_ordersTotal > 0) _ordersPagination(),
          ],
        ],
      ),
    );
  }

  Widget _ordersPagination() {
    final pages = math.max(1, (_ordersTotal / _pageSize).ceil());
    final page = math.min(math.max(_ordersPage, 1), pages);
    final start = (page - 1) * _pageSize + 1;
    final end = math.min(page * _pageSize, _ordersTotal);
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: page > 1 ? () => _goToOrdersPage(page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            '$start–$end of $_ordersTotal · page $page of $pages',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: page < pages ? () => _goToOrdersPage(page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _emptyListings(List<Map<String, dynamic>> filtered) {
    if (_favoritesOnly && filtered.isEmpty) {
      return EmptyState(
        icon: Icons.star_border_rounded,
        title: 'No favorites yet',
        message:
            'Tap the star on a listing to keep it here for quick access.',
        action: TextButton(
          onPressed: () {
            setState(() {
              _favoritesOnly = false;
              _listingPage = 1;
            });
            _loadListings();
          },
          child: const Text('Show all listings'),
        ),
      );
    }
    if (_query.trim().isNotEmpty && filtered.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No listings match your search',
        message: 'Try a different product name, category, or supplier.',
      );
    }
    return EmptyState(
      icon: Icons.local_shipping_outlined,
      title: 'No supplier listings yet',
      message:
          'Suppliers will appear here when they publish wholesale listings. Tap refresh after they publish.',
      action: OutlinedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Refresh'),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: AppColors.muted,
            ),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _inlineError(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.loss.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.loss),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.loss),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationCard() {
    final hasLocation = _latitude != null && _longitude != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Icon(
              hasLocation
                  ? Icons.location_on_rounded
                  : Icons.location_off_outlined,
              color: hasLocation ? AppColors.supplier : AppColors.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLocation
                        ? 'Delivery location saved'
                        : 'Set your delivery location',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    hasLocation
                        ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)} · transport is estimated from this pin'
                        : 'Pick your shop on the map so transport is included in the cart.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Pick on map',
              onPressed: _pickLocation,
              icon: const Icon(Icons.map_outlined),
            ),
            IconButton(
              tooltip: 'Use my current location',
              onPressed: _useLocation,
              icon: const Icon(Icons.my_location_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagination(int total) {
    final page = _currentPage;
    final start = (page - 1) * _pageSize + 1;
    final end = math.min(page * _pageSize, total);
    final pages = _pageCount;
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: page > 1 ? () => _goToListingPage(page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            '$start–$end of $total · page $page of $pages',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: page < pages ? () => _goToListingPage(page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _cartBar() {
    return Material(
      elevation: 8,
      color: AppColors.supplier,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openCart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$_cartCount item${_cartCount == 1 ? '' : 's'} · '
                  '${money(_quotes.isNotEmpty ? _grandTotal : _cartSubtotal)}'
                  '${_quotes.isNotEmpty ? ' incl. transport' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Text(
                'View cart',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listingCard(Map<String, dynamic> listing) {
    final id = listing['id'].toString();
    final name = listing['name']?.toString() ?? 'Listing';
    final saleUnit = listing['saleUnit']?.toString() ?? 'piece';
    final category = listing['category']?.toString() ?? '';
    final supplierName = listing['supplierName']?.toString() ?? 'Supplier';
    final price = ((listing['pricePerUnit']) is num ? (listing['pricePerUnit'] as num).toDouble() : null) ?? 0;
    final pieces = ((listing['piecesPerUnit']) is num ? (listing['piecesPerUnit'] as num) : null)?.toInt() ?? 1;
    final pack = pieces > 1 ? ' · $pieces pcs / $saleUnit' : '';
    final minOrder = _minOrder(listing);
    final count = _cart[id]?.qty ?? 0;
    final favorite = _favorites.contains(id);
    final publisher = listing['publishedBy'] is Map
        ? (listing['publishedBy'] as Map)['name']?.toString() ?? ''
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.supplier.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: AppColors.supplier,
                  ),
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
                      const SizedBox(height: 2),
                      Text(
                        supplierName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.supplier,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${category.isEmpty ? '' : '$category · '}${money(price)} / $saleUnit$pack',
                        style: const TextStyle(
                          fontSize: 12,
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
                  tooltip: favorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  onPressed: () => _toggleFavorite(id),
                  icon: Icon(
                    favorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: favorite ? AppColors.accent : AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Minimum $minOrder $saleUnit',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                if (count == 0)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.supplier,
                      side: BorderSide(
                        color: AppColors.supplier.withValues(alpha: 0.45),
                      ),
                    ),
                    onPressed: () => _addListing(listing),
                    icon: const Icon(
                      Icons.add_shopping_cart_rounded,
                      size: 18,
                    ),
                    label: const Text('Add to cart'),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Remove one',
                        onPressed: () => _decrementListing(listing),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$count',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        tooltip: 'Add one',
                        onPressed: () => _addListing(listing),
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.supplier,
                        ),
                      ),
                    ],
                  ),
              ],
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
    final status = order['status']?.toString() ?? 'PENDING';
    final createdAt = DateTime.tryParse(order['createdAt']?.toString() ?? '');
    final subtotal = ((order['subtotal']) is num ? (order['subtotal'] as num).toDouble() : null) ?? 0;
    final deliveryFee = ((order['deliveryFee']) is num ? (order['deliveryFee'] as num).toDouble() : null) ?? 0;
    final deliveryQuoted = order['deliveryQuoted'] == true;
    final deliveryBaseFee = ((order['deliveryBaseFee']) is num ? (order['deliveryBaseFee'] as num).toDouble() : null) ?? 0;
    final deliveryDistanceFee =
        ((order['deliveryDistanceFee']) is num ? (order['deliveryDistanceFee'] as num).toDouble() : null) ?? 0;
    final deliveryWeightFee =
        ((order['deliveryWeightFee']) is num ? (order['deliveryWeightFee'] as num).toDouble() : null) ?? 0;
    final deliveryVolumeFee =
        ((order['deliveryVolumeFee']) is num ? (order['deliveryVolumeFee'] as num).toDouble() : null) ?? 0;
    final deliveryDistanceKm =
        ((order['deliveryDistanceKm']) is num ? (order['deliveryDistanceKm'] as num).toDouble() : null);
    final shippingWeightKg =
        ((order['shippingWeightKg']) is num ? (order['shippingWeightKg'] as num).toDouble() : null) ?? 0;
    final shippingVolumeM3 =
        ((order['shippingVolumeM3']) is num ? (order['shippingVolumeM3'] as num).toDouble() : null) ?? 0;
    final warehouseName = order['warehouseName']?.toString() ??
        supplier['warehouseName']?.toString() ??
        '';
    final breakdownTotal = deliveryBaseFee +
        deliveryDistanceFee +
        deliveryWeightFee +
        deliveryVolumeFee;
    // A supplier override changes deliveryFee without rewriting the stored
    // components, so only show the breakdown while it still matches.
    final showBreakdown = deliveryQuoted &&
        breakdownTotal > 0 &&
        (breakdownTotal - deliveryFee).abs() < 0.01;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          children: [
            Expanded(
              child: Text(
                supplier['businessName']?.toString() ?? 'Supplier order',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(label: status, color: _statusColor(status)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${money(((order['total']) is num ? (order['total'] as num) : null) ?? 0)} · ${items.length} item${items.length == 1 ? '' : 's'}'
            '${createdAt == null ? '' : ' · ${formatDateTime(createdAt)}'}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        children: [
          for (final raw in items)
            ListTile(
              dense: true,
              title: Text('${raw['quantity']} × ${raw['listingName']}'),
              subtitle: Text(
                '${money(((raw['unitPrice']) is num ? (raw['unitPrice'] as num) : null) ?? 0)} per ${raw['saleUnit'] ?? 'unit'}',
              ),
              trailing: Text(
                money(((raw['lineTotal']) is num ? (raw['lineTotal'] as num) : null) ?? 0),
                style: const TextStyle(fontWeight: FontWeight.w600),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              children: [
                KeyValueRow(label: 'Products', value: money(subtotal)),
                KeyValueRow(
                  label: 'Delivery',
                  value: deliveryQuoted
                      ? money(deliveryFee)
                      : 'Awaiting supplier quote',
                  valueColor: deliveryQuoted ? null : AppColors.warning,
                ),
                if (showBreakdown) ...[
                  if (warehouseName.isNotEmpty)
                    KeyValueRow(
                      label: 'From warehouse',
                      value: warehouseName,
                      valueColor: AppColors.supplier,
                    ),
                  KeyValueRow(
                    label: 'Base fee',
                    value: money(deliveryBaseFee),
                  ),
                  KeyValueRow(
                    label: 'Distance'
                        '${deliveryDistanceKm != null ? ' · ${deliveryDistanceKm.toStringAsFixed(1)} km' : ''}',
                    value: money(deliveryDistanceFee),
                  ),
                  KeyValueRow(
                    label: 'Weight · ${qty(shippingWeightKg)} kg',
                    value: money(deliveryWeightFee),
                  ),
                  KeyValueRow(
                    label: 'Volume · ${qty(shippingVolumeM3)} m³',
                    value: money(deliveryVolumeFee),
                  ),
                ],
                const Divider(height: 18),
                KeyValueRow(
                  label: 'Total',
                  value: money(((order['total']) is num ? (order['total'] as num) : null) ?? 0),
                  bold: true,
                ),
                if (!deliveryQuoted)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Distance based delivery is awaiting supplier confirmation.',
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        return AppColors.seed;
      case 'READY':
        return AppColors.supplier;
      case 'DELIVERED':
        return AppColors.profit;
      case 'REJECTED':
      case 'CANCELLED':
        return AppColors.loss;
      default:
        return AppColors.warning;
    }
  }
}

class _CartEntry {
  const _CartEntry({
    required this.listingId,
    required this.supplierId,
    required this.supplierName,
    required this.name,
    required this.saleUnit,
    required this.price,
    required this.minOrder,
    required this.qty,
    this.weightPerUnitKg = 0,
    this.volumePerUnitM3 = 0,
    this.lengthCm = 0,
    this.widthCm = 0,
    this.heightCm = 0,
  });

  final String listingId;
  final String supplierId;
  final String supplierName;
  final String name;
  final String saleUnit;
  final double price;
  final int minOrder;
  final int qty;
  final double weightPerUnitKg;
  final double volumePerUnitM3;
  final double lengthCm;
  final double widthCm;
  final double heightCm;

  double get total => price * qty;

  DeliveryLine get deliveryLine => DeliveryLine(
        quantity: qty,
        weightPerUnitKg: weightPerUnitKg,
        lengthCm: lengthCm,
        widthCm: widthCm,
        heightCm: heightCm,
        volumePerUnitM3: volumePerUnitM3,
      );

  _CartEntry copyWith({
    String? supplierId,
    String? supplierName,
    String? name,
    String? saleUnit,
    double? price,
    int? minOrder,
    int? qty,
    double? weightPerUnitKg,
    double? volumePerUnitM3,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
  }) {
    return _CartEntry(
      listingId: listingId,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      name: name ?? this.name,
      saleUnit: saleUnit ?? this.saleUnit,
      price: price ?? this.price,
      minOrder: minOrder ?? this.minOrder,
      qty: qty ?? this.qty,
      weightPerUnitKg: weightPerUnitKg ?? this.weightPerUnitKg,
      volumePerUnitM3: volumePerUnitM3 ?? this.volumePerUnitM3,
      lengthCm: lengthCm ?? this.lengthCm,
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
    );
  }

  Map<String, dynamic> toJson() => {
        'listingId': listingId,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'name': name,
        'saleUnit': saleUnit,
        'price': price,
        'minOrder': minOrder,
        'qty': qty,
        'weightPerUnitKg': weightPerUnitKg,
        'volumePerUnitM3': volumePerUnitM3,
        'lengthCm': lengthCm,
        'widthCm': widthCm,
        'heightCm': heightCm,
      };

  factory _CartEntry.fromJson(Map<String, dynamic> json) {
    return _CartEntry(
      listingId: json['listingId']?.toString() ?? '',
      supplierId: json['supplierId']?.toString() ?? '',
      supplierName: json['supplierName']?.toString() ?? 'Supplier',
      name: json['name']?.toString() ?? 'Listing',
      saleUnit: json['saleUnit']?.toString() ?? 'unit',
      price: ((json['price']) is num ? (json['price'] as num).toDouble() : null) ?? 0,
      minOrder: ((json['minOrder']) is num ? (json['minOrder'] as num) : null)?.toInt() ?? 1,
      qty: ((json['qty']) is num ? (json['qty'] as num) : null)?.toInt() ?? 1,
      weightPerUnitKg: ((json['weightPerUnitKg']) is num ? (json['weightPerUnitKg'] as num).toDouble() : null) ?? 0,
      volumePerUnitM3: ((json['volumePerUnitM3']) is num ? (json['volumePerUnitM3'] as num).toDouble() : null) ?? 0,
      lengthCm: ((json['lengthCm']) is num ? (json['lengthCm'] as num).toDouble() : null) ?? 0,
      widthCm: ((json['widthCm']) is num ? (json['widthCm'] as num).toDouble() : null) ?? 0,
      heightCm: ((json['heightCm']) is num ? (json['heightCm'] as num).toDouble() : null) ?? 0,
    );
  }
}
