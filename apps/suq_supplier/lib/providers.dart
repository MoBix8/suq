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
    ref.invalidate(summaryProvider);
    ref.invalidate(recentOrdersProvider);
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
    ref.invalidate(summaryProvider);
    ref.invalidate(recentOrdersProvider);
  }
}

// ─── Supplier data ───────────────────────────────────────────────────────────

final profileProvider = FutureProvider<SupplierProfile>((ref) async {
  final response = await ref.watch(apiProvider).get('/supplier/profile');
  return SupplierProfile.fromJson(asMap(response['supplier']));
});

/// Small aggregate used by the overview and account screens so they never need
/// to download the full product, listing or order history.
final summaryProvider = FutureProvider<SupplierSummary>((ref) async {
  final response = await ref.watch(apiProvider).get('/supplier/summary');
  return SupplierSummary.fromJson(asMap(response['summary']));
});

final recentOrdersProvider = FutureProvider<List<SupplierOrder>>((ref) async {
  final response = await ref.watch(apiProvider).get(
        '/supplier/orders',
        query: {'page': '1', 'pageSize': '5'},
      );
  return (response['orders'] as List? ?? const [])
      .whereType<Map>()
      .map((row) => SupplierOrder.fromJson(asMap(row)))
      .toList();
});
