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

class PaymentQuery {
  const PaymentQuery({
    this.status,
    this.bankAccountId,
    this.page = 1,
    this.pageSize = 25,
  });

  final String? status;
  final String? bankAccountId;
  final int page;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      other is PaymentQuery &&
      other.status == status &&
      other.bankAccountId == bankAccountId &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(status, bankAccountId, page, pageSize);
}

class PagedPayments {
  const PagedPayments({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<PaymentRecord> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;
}

final paymentsProvider =
    FutureProvider.family<PagedPayments, PaymentQuery>((ref, query) async {
  final response = await ref.watch(apiProvider).get(
    '/admin/payments',
    query: {
      if (query.status != null && query.status!.isNotEmpty) 'status': query.status,
      if (query.bankAccountId != null && query.bankAccountId!.isNotEmpty)
        'bankAccountId': query.bankAccountId,
      'page': query.page,
      'pageSize': query.pageSize,
    },
  );
  final list = response['payments'] as List<dynamic>? ?? [];
  return PagedPayments(
    items: list
        .whereType<Map>()
        .map((item) => PaymentRecord.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    total: asInt(response['total']),
    page: asInt(response['page']) == 0 ? query.page : asInt(response['page']),
    pageSize:
        asInt(response['pageSize']) == 0 ? query.pageSize : asInt(response['pageSize']),
  );
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

final categoriesProvider =
    FutureProvider.family<PagedLibraryCategories, int>((ref, page) async {
  final response = await ref.watch(apiProvider).get(
    '/admin/library/categories',
    query: {'page': page, 'pageSize': 20},
  );
  final list = response['categories'] as List<dynamic>? ?? [];
  return PagedLibraryCategories(
    items: list
        .whereType<Map>()
        .map((item) => LibraryCategory.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    total: asInt(response['total']),
    page: asInt(response['page']) == 0 ? page : asInt(response['page']),
    pageSize: asInt(response['pageSize']) == 0 ? 20 : asInt(response['pageSize']),
  );
});

final allCategoriesProvider = FutureProvider<List<LibraryCategory>>((ref) async {
  final response = await ref.watch(apiProvider).get(
    '/admin/library/categories',
    query: {'page': 1, 'pageSize': 200},
  );
  final list = response['categories'] as List<dynamic>? ?? [];
  return list
      .whereType<Map>()
      .map((item) => LibraryCategory.fromJson(Map<String, dynamic>.from(item)))
      .toList();
});

class LibraryProductQuery {
  const LibraryProductQuery({
    this.categoryId,
    this.query = '',
    this.page = 1,
    this.pageSize = 25,
  });

  final String? categoryId;
  final String query;
  final int page;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      other is LibraryProductQuery &&
      other.categoryId == categoryId &&
      other.query == query &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(categoryId, query, page, pageSize);
}

final libraryProductsProvider =
    FutureProvider.family<PagedLibraryProducts, LibraryProductQuery>(
  (ref, query) async {
    final response = await ref.watch(apiProvider).get(
      '/admin/library/products',
      query: {
        'all': 'true',
        'page': query.page,
        'pageSize': query.pageSize,
        if (query.categoryId != null && query.categoryId!.isNotEmpty)
          'categoryId': query.categoryId,
        if (query.query.trim().isNotEmpty) 'q': query.query.trim(),
      },
    );
    final list = response['products'] as List<dynamic>? ?? [];
    return PagedLibraryProducts(
      items: list
          .whereType<Map>()
          .map((item) => LibraryProduct.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      total: asInt(response['total']),
      page: asInt(response['page']) == 0 ? query.page : asInt(response['page']),
      pageSize: asInt(response['pageSize']) == 0
          ? query.pageSize
          : asInt(response['pageSize']),
    );
  },
);
