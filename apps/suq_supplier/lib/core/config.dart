import 'package:flutter/foundation.dart';

class SupplierConfig {
  static const String appName = 'SUQ SUPPLIER';
  static const String version = '1.0.0';

  static String get apiBaseUrl {
    const override = String.fromEnvironment('SUQ_API', defaultValue: '');
    if (override.isNotEmpty) return override;
    return 'https://suq-silk.vercel.app';
  }
}
