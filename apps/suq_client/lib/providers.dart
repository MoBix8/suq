import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/entitlement.dart';
import 'core/trusted_clock.dart';
import 'data/database.dart';
import 'data/models.dart';
import 'data/repositories/cache_repository.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/library_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/sales_repository.dart';
import 'data/repositories/sync_repository.dart';

// ─── Infrastructure ──────────────────────────────────────────────────────────

final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final apiProvider = Provider<ApiClient>((ref) => ApiClient());

final trustedClockProvider = Provider<TrustedClock>(
  (ref) => TrustedClock(ref.watch(prefsProvider)),
);

final deviceIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(prefsProvider);
  final existing = prefs.getString('device.id');
  if (existing != null && existing.isNotEmpty) return existing;
  final id = const Uuid().v4();
  unawaited(prefs.setString('device.id', id));
  return id;
});

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(databaseProvider)),
);

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(ref.watch(databaseProvider)),
);

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => SalesRepository(ref.watch(databaseProvider)),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    ref.watch(apiProvider),
    ref.watch(databaseProvider),
  ),
);

final cacheRepositoryProvider = Provider<CacheRepository>(
  (ref) => CacheRepository(ref.watch(databaseProvider)),
);

final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => SyncRepository(
    ref.watch(databaseProvider),
    ref.watch(apiProvider),
    ref.watch(prefsProvider),
  ),
);

// ─── Session ─────────────────────────────────────────────────────────────────

class SessionState {
  const SessionState({this.token, this.user, this.shop});

  final String? token;
  final AppUser? user;
  final ShopInfo? shop;

  bool get isLoggedIn => token != null && token!.isNotEmpty && user != null && shop != null;
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    final prefs = ref.watch(prefsProvider);
    final api = ref.watch(apiProvider);
    final token = prefs.getString('auth.token');
    api.setToken(token);
    return SessionState(
      token: token,
      user: _userFromPrefs(prefs),
      shop: _shopFromPrefs(prefs),
    );
  }

  AppUser? _userFromPrefs(SharedPreferences prefs) {
    final raw = prefs.getString('auth.user');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return AppUser.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {}
    return null;
  }

  ShopInfo? _shopFromPrefs(SharedPreferences prefs) {
    final raw = prefs.getString('auth.shop');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return ShopInfo.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {}
    return null;
  }

  Future<void> login({required String phone, required String pin}) async {
    final api = ref.read(apiProvider);
    final response = await api.post(
      '/auth/login',
      body: {
        'phone': phone.trim(),
        'pin': pin,
        'deviceId': ref.read(deviceIdProvider),
      },
    );
    await _applyAuth(response);
  }

  Future<void> register({
    required String name,
    required String shopName,
    required String phone,
    required String pin,
    String? city,
  }) async {
    final api = ref.read(apiProvider);
    final response = await api.post(
      '/auth/register',
      body: {
        'name': name.trim(),
        'shopName': shopName.trim(),
        'phone': phone.trim(),
        'pin': pin,
        'deviceId': ref.read(deviceIdProvider),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      },
    );
    await _applyAuth(response);
  }

  Future<void> _applyAuth(Map<String, dynamic> response) async {
    final token = response['token'] as String?;
    final userJson = response['user'];
    final shopJson = response['shop'];
    if (token == null || userJson is! Map || shopJson is! Map) {
      throw ApiException('The server returned an incomplete account.');
    }
    final user = AppUser.fromJson(Map<String, dynamic>.from(userJson));
    final shop = ShopInfo.fromJson(Map<String, dynamic>.from(shopJson));
    final prefs = ref.read(prefsProvider);

    await prefs.setString('auth.token', token);
    await prefs.setString('auth.user', jsonEncode(user.toJson()));
    await prefs.setString('auth.shop', jsonEncode(shop.toJson()));
    ref.read(apiProvider).setToken(token);

    state = SessionState(token: token, user: user, shop: shop);
  }

  Future<void> logout() async {
    final token = state.token;
    if (token != null && token.isNotEmpty) {
      await ref.read(apiProvider).post('/auth/logout');
    }

    final prefs = ref.read(prefsProvider);
    await prefs.remove('auth.token');
    await prefs.remove('auth.user');
    await prefs.remove('auth.shop');
    await prefs.remove('entitlement.token');
    await prefs.remove('carts.state');
    ref.read(apiProvider).setToken(null);
    state = const SessionState();
  }
}

// ─── Entitlement / subscription lease ───────────────────────────────────────

final entitlementProvider =
    AsyncNotifierProvider<EntitlementController, EntitlementState>(
  EntitlementController.new,
);

class EntitlementController extends AsyncNotifier<EntitlementState> {
  @override
  Future<EntitlementState> build() async {
    ref.watch(sessionProvider);
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<EntitlementState> _load() async {
    final session = ref.read(sessionProvider);
    if (!session.isLoggedIn) {
      return const EntitlementState.locked(message: 'Log in to activate SUQ.');
    }

    final api = ref.read(apiProvider);
    final prefs = ref.read(prefsProvider);
    final clock = ref.read(trustedClockProvider);
    final shopId = session.shop!.id;
    final cachedToken = prefs.getString('entitlement.token');
    final cached = cachedToken == null
        ? null
        : await _evaluate(cachedToken, shopId, clock);

    try {
      final response = await api.post(
        '/subscription/entitlement',
        body: {
          'deviceId': ref.read(deviceIdProvider),
          'appVersion': AppConfig.version,
        },
        timeout: const Duration(seconds: 8),
      );

      final serverTime = DateTime.tryParse(response['serverTime'] as String? ?? '');
      if (serverTime != null) await clock.anchor(serverTime);
      await clock.clearTamper();

      if (response['active'] == true && response['token'] is String) {
        final token = response['token'] as String;
        await prefs.setString('entitlement.token', token);
        final evaluated = await _evaluate(
          token,
          shopId,
          clock,
          ignoreTamper: true,
        );
        if (evaluated != null) return evaluated;
        return const EntitlementState.locked(
          message: 'The subscription token could not be verified.',
        );
      }

      final subscription = response['subscription'];
      final subMap = subscription is Map
          ? Map<String, dynamic>.from(subscription)
          : null;
      return EntitlementState.locked(
        packageName: subMap?['packageName'] as String?,
        endsAt: asDateOrNull(subMap?['endsAt']),
        message: 'No active subscription yet. Choose a package below.',
      );
    } on ApiException catch (error) {
      if (cached != null && cached.active && !clock.tampered) return cached;
      return EntitlementState.locked(
        needsOnline: true,
        clockTampered: clock.tampered,
        message: error.message,
      );
    } catch (_) {
      if (cached != null && cached.active && !clock.tampered) return cached;
      return const EntitlementState.locked(
        needsOnline: true,
        message: 'Could not verify your subscription. Check your internet.',
      );
    }
  }

  Future<EntitlementState?> _evaluate(
    String token,
    String shopId,
    TrustedClock clock, {
    bool ignoreTamper = false,
  }) async {
    final payload = await EntitlementVerifier.verify(token);
    if (payload == null) return null;
    if (payload['shopId'] != shopId) return null;

    final startsAt = DateTime.tryParse(payload['startsAt'] as String? ?? '')?.toLocal();
    final endsAt = DateTime.tryParse(payload['endsAt'] as String? ?? '')?.toLocal();
    final leaseUntil = DateTime.tryParse(payload['leaseUntil'] as String? ?? '')?.toLocal();
    if (startsAt == null || endsAt == null || leaseUntil == null) return null;

    final now = clock.now();
    final tampered = !ignoreTamper && clock.tampered;
    final packageName = payload['packageName'] as String?;

    if (tampered) {
      return EntitlementState.locked(
        needsOnline: true,
        clockTampered: true,
        packageName: packageName,
        endsAt: endsAt,
        leaseUntil: leaseUntil,
        message: 'A device date change was detected. Connect to the internet to verify.',
      );
    }

    final active = now.isAfter(startsAt.subtract(const Duration(minutes: 2))) &&
        now.isBefore(leaseUntil) &&
        now.isBefore(endsAt);

    final daysLeft = _ceilDays(endsAt.difference(now));
    final offlineDaysLeft = _ceilDays(leaseUntil.difference(now));

    if (!active) {
      return EntitlementState.locked(
        needsOnline: true,
        packageName: packageName,
        endsAt: endsAt,
        leaseUntil: leaseUntil,
        message: 'Your offline subscription check expired. Connect to the internet.',
      );
    }

    return EntitlementState(
      active: true,
      packageName: packageName,
      startsAt: startsAt,
      endsAt: endsAt,
      leaseUntil: leaseUntil,
      daysLeft: daysLeft,
      offlineDaysLeft: offlineDaysLeft,
    );
  }

  int _ceilDays(Duration duration) {
    if (duration.isNegative) return 0;
    return (duration.inMinutes / (60 * 24)).ceil();
  }
}

// ─── Data providers ──────────────────────────────────────────────────────────

final productsProvider = FutureProvider<List<Product>>(
  (ref) => ref.watch(productRepositoryProvider).list(),
);

final customersProvider = FutureProvider<List<Customer>>(
  (ref) => ref.watch(customerRepositoryProvider).list(),
);

final localLibraryIdsProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(productRepositoryProvider).libraryIds(),
);

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final products = ref.watch(productRepositoryProvider);
  final customers = ref.watch(customerRepositoryProvider);
  final sales = ref.watch(salesRepositoryProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));

  final todaySummary = await sales.summary(today, tomorrow);
  final last7 = await sales.dailySeries(7);
  final topToday = await sales.topProducts(today, tomorrow, limit: 4);
  final lowStock = await products.lowStock();
  final outstanding = await customers.totalOutstanding();
  final recent = await sales.recent(limit: 6);
  final productCount = await products.count();
  final customerCount = await customers.count();

  return DashboardData(
    today: todaySummary,
    last7: last7,
    topToday: topToday,
    lowStock: lowStock,
    outstandingCredit: outstanding,
    recentSales: recent,
    productCount: productCount,
    customerCount: customerCount,
  );
});

final reportProvider = FutureProvider.family<SalesReport, int>((ref, days) async {
  final sales = ref.watch(salesRepositoryProvider);
  final customers = ref.watch(customerRepositoryProvider);
  final products = ref.watch(productRepositoryProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final from = today.subtract(Duration(days: days - 1));
  final to = today.add(const Duration(days: 1));

  return SalesReport(
    from: from,
    to: to,
    summary: await sales.summary(from, to),
    daily: await sales.dailySeries(days),
    top: await sales.topProducts(from, to, limit: 8),
    outstandingCredit: await customers.totalOutstanding(),
    lowStock: await products.lowStock(),
    customerCount: await customers.count(),
  );
});

final lastSyncedProvider = FutureProvider<DateTime?>(
  (ref) => ref.watch(syncRepositoryProvider).lastSyncedAt(),
);

final customerDetailProvider =
    FutureProvider.family<CustomerDetail, String>((ref, customerId) async {
  final customers = ref.watch(customerRepositoryProvider);
  final sales = ref.watch(salesRepositoryProvider);
  final customer = await customers.byId(customerId);
  if (customer == null) {
    throw StateError('Customer not found');
  }
  return CustomerDetail(
    customer: customer,
    ledger: await customers.ledger(customerId),
    sales: await sales.salesForCustomer(customerId),
  );
});

final libraryCategoriesProvider = FutureProvider<List<LibraryCategory>>(
  (ref) => ref.watch(libraryRepositoryProvider).categories(),
);

final libraryFeedProvider = AsyncNotifierProvider.family<LibraryFeedController,
    LibraryFeedState, LibraryFeedQuery>(
  LibraryFeedController.new,
);

class LibraryFeedController extends AsyncNotifier<LibraryFeedState> {
  LibraryFeedController(this.query);

  final LibraryFeedQuery query;
  static const _pageSize = 40;

  @override
  Future<LibraryFeedState> build() async {
    final page = await ref.watch(libraryRepositoryProvider).products(
          categoryId: query.categoryId,
          search: query.search,
          page: 1,
          pageSize: _pageSize,
        );
    return LibraryFeedState(
      items: page.items,
      total: page.total,
      page: page.page,
      pageSize: page.pageSize,
    );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore) return;

    final page = await ref.read(libraryRepositoryProvider).products(
          categoryId: query.categoryId,
          search: query.search,
          page: current.page + 1,
          pageSize: current.pageSize,
        );
    final seen = current.items.map((item) => item.id).toSet();
    state = AsyncData(
      current.copyWith(
        items: [
          ...current.items,
          ...page.items.where((item) => !seen.contains(item.id)),
        ],
        total: page.total,
        page: page.page,
        pageSize: page.pageSize,
      ),
    );
  }

  Future<List<LibraryProduct>> allMatching() {
    return ref.read(libraryRepositoryProvider).allProducts(
          categoryId: query.categoryId,
          search: query.search,
        );
  }
}

bool _isAuthError(Object error) =>
    error is ApiException &&
    (error.statusCode == 401 || error.statusCode == 403);

/// Reads from the network and stores the response locally. When the device is
/// offline the last successful response is used instead.
Future<Map<String, dynamic>> _cachedGet(
  Ref ref,
  String path,
  String cacheKey, {
  Map<String, dynamic>? query,
}) async {
  final api = ref.watch(apiProvider);
  final cache = ref.watch(cacheRepositoryProvider);
  try {
    final response = await api.get(path, query: query);
    await cache.write(cacheKey, response);
    return response;
  } catch (error) {
    if (_isAuthError(error)) rethrow;
    final cached = await cache.read(cacheKey);
    if (cached != null) return cached;
    rethrow;
  }
}

final packagesProvider = FutureProvider<List<PackagePlan>>((ref) async {
  final response = await _cachedGet(ref, '/packages', 'packages');
  final list = response['packages'] as List<dynamic>? ?? [];
  return list
      .whereType<Map>()
      .map((item) => PackagePlan.fromJson(Map<String, dynamic>.from(item)))
      .toList();
});

final banksProvider = FutureProvider<List<BankAccount>>((ref) async {
  final response = await _cachedGet(ref, '/bank-accounts', 'bank-accounts');
  final list = response['accounts'] as List<dynamic>? ?? [];
  final accounts = list
      .whereType<Map>()
      .map((item) => BankAccount.fromJson(Map<String, dynamic>.from(item)))
      .toList();
  accounts.shuffle();
  return accounts;
});

final paymentsProvider = FutureProvider<List<PaymentRecord>>((ref) async {
  final shopId = ref.watch(sessionProvider).shop?.id ?? 'anonymous';
  final response = await _cachedGet(
    ref,
    '/payments/mine',
    'payments.mine.$shopId',
  );
  final list = response['payments'] as List<dynamic>? ?? [];
  return list
      .whereType<Map>()
      .map((item) => PaymentRecord.fromJson(Map<String, dynamic>.from(item)))
      .toList();
});

final pendingSyncProvider = FutureProvider<int>(
  (ref) => ref.watch(syncRepositoryProvider).pendingCount(),
);

final salesHistoryProvider = FutureProvider<List<SaleRecord>>(
  (ref) => ref.read(salesRepositoryProvider).recent(limit: 200),
);

// ─── Multi-cart ──────────────────────────────────────────────────────────────

final cartProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

class CartController extends Notifier<CartState> {
  static const _storageKey = 'carts.state';

  @override
  CartState build() {
    final prefs = ref.watch(prefsProvider);
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return CartState.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    return CartState.initial();
  }

  void _commit(CartState next) {
    state = next;
    unawaited(
      ref.read(prefsProvider).setString(_storageKey, jsonEncode(next.toJson())),
    );
  }

  void addTab() {
    final id = const Uuid().v4();
    final tabs = [
      ...state.tabs,
      CartTab(id: id, label: 'Cart ${state.tabs.length + 1}'),
    ];
    _commit(state.copyWith(tabs: tabs, activeIndex: tabs.length - 1));
  }

  void closeTab(String id) {
    if (state.tabs.length == 1) {
      _commit(CartState.initial());
      return;
    }
    final index = state.tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    final tabs = [...state.tabs]..removeAt(index);
    final activeIndex = state.activeIndex.clamp(0, tabs.length - 1);
    _commit(state.copyWith(tabs: tabs, activeIndex: activeIndex));
  }

  void selectTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    _commit(state.copyWith(activeIndex: index));
  }

  void renameTab(String id, String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final tabs = state.tabs
        .map((tab) => tab.id == id ? tab.copyWith(label: trimmed) : tab)
        .toList();
    _commit(state.copyWith(tabs: tabs));
  }

  void addProduct(Product product, {double quantity = 1}) {
    final tab = state.active;
    final lines = [...tab.lines];
    final index = lines.indexWhere((line) => line.productId == product.id);
    if (index >= 0) {
      lines[index] = lines[index].copyWith(qty: lines[index].qty + quantity);
    } else {
      lines.add(CartLine(
        productId: product.id,
        name: product.name,
        unit: product.unit,
        unitPrice: product.sellingPrice,
        unitCost: product.buyingPrice,
        trackStock: product.trackStock,
        qty: quantity,
      ));
    }
    _replaceActive(tab.copyWith(lines: lines));
  }

  void setQuantity(String productId, double quantity) {
    final tab = state.active;
    final lines = [...tab.lines];
    final index = lines.indexWhere((line) => line.productId == productId);
    if (index < 0) return;
    if (quantity <= 0) {
      lines.removeAt(index);
    } else {
      lines[index] = lines[index].copyWith(qty: quantity);
    }
    _replaceActive(tab.copyWith(lines: lines));
  }

  void removeLine(String productId) {
    final tab = state.active;
    _replaceActive(tab.copyWith(
      lines: tab.lines.where((line) => line.productId != productId).toList(),
    ));
  }

  void setDiscount(double value) {
    final tab = state.active;
    _replaceActive(tab.copyWith(discount: value < 0 ? 0 : value));
  }

  void setCustomer(Customer? customer) {
    final tab = state.active;
    _replaceActive(
      customer == null
          ? tab.copyWith(clearCustomer: true)
          : tab.copyWith(customerId: customer.id, customerName: customer.name),
    );
  }

  void clearActive() {
    final tab = state.active;
    _replaceActive(CartTab(id: tab.id, label: tab.label));
  }

  void _replaceActive(CartTab tab) {
    final tabs = [...state.tabs];
    tabs[state.activeIndex] = tab;
    _commit(state.copyWith(tabs: tabs));
  }
}
