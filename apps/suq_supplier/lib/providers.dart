import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'data/models.dart';

final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

final apiProvider = Provider<ApiClient>((ref) => ApiClient());

// ─── Session ─────────────────────────────────────────────────────────────────

class SupplierSessionState {
  const SupplierSessionState({this.token, this.user, this.supplier});

  final String? token;
  final SupplierUser? user;
  final SupplierProfile? supplier;

  bool get isLoggedIn => token != null && token!.isNotEmpty && user != null;
}

final sessionProvider =
    NotifierProvider<SupplierSessionController, SupplierSessionState>(
  SupplierSessionController.new,
);

class SupplierSessionController extends Notifier<SupplierSessionState> {
  @override
  SupplierSessionState build() => const SupplierSessionState();

  Future<void> login({required String phone, required String pin}) async {
    final response = await ref.read(apiProvider).post(
      '/auth/login',
      body: {'phone': phone.trim(), 'pin': pin},
    );

    final userJson = response['user'];
    if (userJson is! Map) {
      throw ApiException('The server returned an incomplete account.');
    }
    final user = SupplierUser.fromJson(asMap(userJson));
    if (user.role != 'SUPPLIER') {
      throw ApiException('This account is not a SUQ supplier account.');
    }

    final supplierJson = response['supplier'];
    if (supplierJson is! Map) {
      throw ApiException(
        'This supplier account is not linked to a business profile yet.',
      );
    }

    final token = response['token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('The server did not return a session token.');
    }

    ref.read(apiProvider).setToken(token);
    ref.invalidate(profileProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(listingsProvider);
    ref.invalidate(ordersProvider);
    ref.read(recentlyPublishedListingProvider.notifier).remember(null);
    state = SupplierSessionState(
      token: token,
      user: user,
      supplier: SupplierProfile.fromJson(asMap(supplierJson)),
    );
  }

  void updateSupplier(SupplierProfile supplier) {
    state = SupplierSessionState(
      token: state.token,
      user: state.user,
      supplier: supplier,
    );
  }

  Future<void> logout() async {
    final api = ref.read(apiProvider);
    try {
      await api.post('/auth/logout');
    } catch (_) {
      // Signing out locally must never be blocked by the network.
    }
    api.setToken(null);
    state = const SupplierSessionState();
    ref.invalidate(profileProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(listingsProvider);
    ref.invalidate(ordersProvider);
    ref.read(recentlyPublishedListingProvider.notifier).remember(null);
  }
}

// ─── Supplier data ───────────────────────────────────────────────────────────

final profileProvider = FutureProvider<SupplierProfile>((ref) async {
  final response = await ref.watch(apiProvider).get('/supplier/profile');
  return SupplierProfile.fromJson(asMap(response['supplier']));
});

final categoriesProvider = FutureProvider<List<SupplierCategory>>((ref) async {
  final response = await ref.watch(apiProvider).get('/supplier/categories');
  final fetched = (response['categories'] as List? ?? const [])
      .whereType<Map>()
      .map((row) => SupplierCategory.fromJson(asMap(row)))
      .toList();

  // Some servers only return the supplier's own categories, which can leave the
  // tab empty even though the shared library has products. Build the list from
  // the products feed too, so every category shops see is always present.
  final products = await ref.watch(productsProvider.future);

  final byId = <String, SupplierCategory>{
    for (final category in fetched) category.id: category,
  };
  final counts = <String, int>{};
  final names = <String, String>{};
  for (final product in products) {
    if (product.categoryId.isEmpty || !product.active) continue;
    counts[product.categoryId] = (counts[product.categoryId] ?? 0) + 1;
    if (product.categoryName.isNotEmpty) {
      names.putIfAbsent(product.categoryId, () => product.categoryName);
    }
  }

  for (final entry in counts.entries) {
    final existing = byId[entry.key];
    if (existing == null) {
      byId[entry.key] = SupplierCategory(
        id: entry.key,
        name: names[entry.key] ?? '',
        productCount: entry.value,
      );
    } else {
      byId[entry.key] = SupplierCategory(
        id: existing.id,
        name: existing.name.isEmpty
            ? (names[entry.key] ?? '')
            : existing.name,
        supplierId: existing.supplierId,
        sortOrder: existing.sortOrder,
        productCount: entry.value,
      );
    }
  }

  return byId.values.toList()
    ..sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
});

final productsProvider = FutureProvider<List<SupplierProduct>>((ref) async {
  final response = await ref.watch(apiProvider).get('/supplier/products');
  return (response['products'] as List? ?? const [])
      .whereType<Map>()
      .map((row) => SupplierProduct.fromJson(asMap(row)))
      .toList();
});

final listingsProvider = FutureProvider<List<SupplierListing>>((ref) async {
  final response = await ref.watch(apiProvider).get('/supplier/listings');
  return (response['listings'] as List? ?? const [])
      .whereType<Map>()
      .map((row) => SupplierListing.fromJson(asMap(row)))
      .toList();
});

/// The listing returned by the last create/update call. It is shown
/// immediately so a successful publish is visible even if a cached listings
/// response has not caught up yet.
final recentlyPublishedListingProvider =
    NotifierProvider<RecentListingController, SupplierListing?>(
  RecentListingController.new,
);

class RecentListingController extends Notifier<SupplierListing?> {
  @override
  SupplierListing? build() => null;

  void remember(SupplierListing? listing) => state = listing;
}

final ordersProvider = FutureProvider<List<SupplierOrder>>((ref) async {
  final response = await ref.watch(apiProvider).get('/supplier/orders');
  return (response['orders'] as List? ?? const [])
      .whereType<Map>()
      .map((row) => SupplierOrder.fromJson(asMap(row)))
      .toList();
});
