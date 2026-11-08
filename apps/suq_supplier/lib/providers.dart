import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/config.dart';

final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

final apiProvider = Provider<SupplierApi>((ref) {
  final prefs = ref.watch(prefsProvider);
  return SupplierApi(token: prefs.getString('supplier.token'));
});

// ─── Session ──────────────────────────────────────────────────────────────────

class SupplierSessionState {
  const SupplierSessionState({this.token, this.user});
  final String? token;
  final Map<String, dynamic>? user;
  bool get isLoggedIn => token != null && token!.isNotEmpty && user != null;
}

final sessionProvider =
    NotifierProvider<SupplierSessionController, SupplierSessionState>(
  SupplierSessionController.new,
);

class SupplierSessionController extends Notifier<SupplierSessionState> {
  @override
  SupplierSessionState build() {
    final prefs = ref.watch(prefsProvider);
    final api = ref.watch(apiProvider);
    final token = prefs.getString('supplier.token');
    api.setToken(token);
    final raw = prefs.getString('supplier.user');
    Map<String, dynamic>? user;
    if (raw != null) {
      try {
        user = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    return SupplierSessionState(token: token, user: user);
  }

  Future<void> login({required String phone, required String pin}) async {
    final api = ref.read(apiProvider);
    final response = await api.post('/auth/login', {
      'phone': phone.trim(),
      'pin': pin,
    });
    final user = Map<String, dynamic>.from(response['user'] as Map);
    if (user['role'] != 'SUPPLIER') {
      throw ApiException('This account is not a supplier account.');
    }
    final token = response['token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('The server did not return a session.');
    }
    final prefs = ref.read(prefsProvider);
    await prefs.setString('supplier.token', token);
    await prefs.setString('supplier.phone', phone.trim());
    await prefs.setString('supplier.user', jsonEncode(user));
    api.setToken(token);
    state = SupplierSessionState(token: token, user: user);
  }

  void logout() {
    final prefs = ref.read(prefsProvider);
    prefs.remove('supplier.token');
    prefs.remove('supplier.user');
    ref.read(apiProvider).setToken(null);
    state = const SupplierSessionState();
  }
}
