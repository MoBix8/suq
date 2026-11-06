import 'package:flutter/foundation.dart';

class AdminConfig {
  static const String appName = 'SUQ ADMIN';
  static const String version = '1.0.0';

  /// Base host only. [ApiClient] prefixes every request with `/api`.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('SUQ_API', defaultValue: '');
    if (override.isNotEmpty) return override;
    return 'https://server-gules-rho-94.vercel.app';
  }
}
