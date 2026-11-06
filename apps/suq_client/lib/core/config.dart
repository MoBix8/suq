import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'SUQ';
  static const String appTagline = 'ሱቅዎን በቀላሉ ያስተዳድሩ';
  static const String version = '1.0.0';

  /// Ed25519 public key used to verify offline subscription leases.
  /// Regenerate with `node scripts/gen-keys.mjs` in the server and replace this.
  static const String entitlementPublicKey =
      'uSTPGi9h892sWLLzwrVRM2RDvhkNn+lu8L9/CG3bCDk=';

  static String get apiBaseUrl {
    const override = String.fromEnvironment('SUQ_API', defaultValue: '');
    if (override.isNotEmpty) return override;
    return 'https://server-xi-ten-61.vercel.app';
  }
}
