import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api_client.dart';
import 'data/models.dart';

final apiProvider = Provider<ApiClient>((ref) => ApiClient());

// ─── Session ─────────────────────────────────────────────────────────────────

class AdminSessionState {
  const AdminSessionState({this.token, this.user});

  final String? token;
  final AdminUser? user;

  bool get isLoggedIn =>
      token != null && token!.isNotEmpty && user != null;
}

final sessionProvider =
    NotifierProvider<AdminSessionController, AdminSessionState>(
  AdminSessionController.new,
);

class AdminSessionController extends Notifier<AdminSessionState> {
  @override
  AdminSessionState build() => const AdminSessionState();

  Future<void> login({required String phone, required String pin}) async {
    final response = await ref.read(apiProvider).post(
      '/auth/login',
      body: {'phone': phone.trim(), 'pin': pin},
    );

    final userJson = response['user'];
    if (userJson is! Map) {
      throw ApiException('The server returned an incomplete account.');
    }
    final user = AdminUser.fromJson(Map<String, dynamic>.from(userJson));
    if (user.role != 'ADMIN') {
      throw ApiException('This account is not a SUQ administrator.');
    }

    final token = response['token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('The server did not return a session token.');
    }

    ref.read(apiProvider).setToken(token);
    state = AdminSessionState(token: token, user: user);
  }

  void logout() {
    ref.read(apiProvider).setToken(null);
    state = const AdminSessionState();
  }
}

// ─── Data ────────────────────────────────────────────────────────────────────

final dashboardProvider = FutureProvider<AdminDashboard>((ref) async {
  final response = await ref.watch(apiProvider).get('/admin/dashboard');
  return AdminDashboard.fromJson(response);
});

final paymentsProvider =
    FutureProvider.family<List<PaymentRecord>, String?>((ref, status) async {
  final response = await ref.watch(apiProvider).get(
    '/admin/payments',
    query: {if (status != null && status.isNotEmpty) 'status': status},
  );
  final list = response['payments'] as List<dynamic>? ?? [];
  return list
      .whereType<Map>()
      .map((item) => PaymentRecord.fromJson(Map<String, dynamic>.from(item)))
      .toList();
});

final shopsProvider = FutureProvider<List<ShopRecord>>((ref) async {
  final response = await ref.watch(apiProvider).get('/admin/shops');
  final list = response['shops'] as List<dynamic>? ?? [];
  return list
      .whereType<Map>()
      .map((item) => ShopRecord.fromJson(Map<String, dynamic>.from(item)))
      .toList();
});

final packagesProvider = FutureProvider<List<PackagePlan>>((ref) async {
  final response = await ref.watch(apiProvider).get('/admin/packages');
  final list = response['packages'] as List<dynamic>? ?? [];
  return list
      .whereType<Map>()
      .map((item) => PackagePlan.fromJson(Map<String, dynamic>.from(item)))
      .toList();
});

final banksProvider = FutureProvider<List<BankAccount>>((ref) async {
  final response = await ref.watch(apiProvider).get('/admin/bank-accounts');
  final list = response['accounts'] as List<dynamic>? ?? [];
  return list
      .whereType<Map>()
      .map((item) => BankAccount.fromJson(Map<String, dynamic>.from(item)))
      .toList();
});

final categoriesProvider = FutureProvider<List<LibraryCategory>>((ref) async {
  final response = await ref.watch(apiProvider).get('/admin/library/categories');
  final list = response['categories'] as List<dynamic>? ?? [];
  return list
      .whereType<Map>()
      .map((item) => LibraryCategory.fromJson(Map<String, dynamic>.from(item)))
      .toList();
});

final libraryProductsProvider =
    FutureProvider.family<List<LibraryProduct>, String?>((ref, categoryId) async {
  final response = await ref.watch(apiProvider).get(
    '/admin/library/products',
    query: {
      'all': 'true',
      if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
    },
  );
  final list = response['products'] as List<dynamic>? ?? [];
  return list
      .whereType<Map>()
      .map((item) => LibraryProduct.fromJson(Map<String, dynamic>.from(item)))
      .toList();
});
