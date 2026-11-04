import 'package:flutter/foundation.dart';

class AdminConfig {
  static const String appName = 'SUQ Admin';
  static const String version = '1.0.0';

  /// Base host only. [ApiClient] prefixes every request with `/api`.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('SUQ_API', defaultValue: '');
    if (override.isNotEmpty) return override;
    if (kIsWeb) return 'http://localhost:4000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000';
    }
    return 'http://localhost:4000';
  }
}
