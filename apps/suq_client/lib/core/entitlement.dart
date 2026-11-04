import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'config.dart';

/// Verifies the Ed25519 signature on an offline entitlement lease.
class EntitlementVerifier {
  static final Ed25519 _ed25519 = Ed25519();

  static Future<Map<String, dynamic>?> verify(String token) async {
    try {
      final dot = token.indexOf('.');
      if (dot <= 0 || dot == token.length - 1) return null;

      final payloadBytes = base64Url.decode(
        base64Url.normalize(token.substring(0, dot)),
      );
      final signatureBytes = base64Url.decode(
        base64Url.normalize(token.substring(dot + 1)),
      );

      final publicKey = SimplePublicKey(
        base64.decode(AppConfig.entitlementPublicKey),
        type: KeyPairType.ed25519,
      );

      final valid = await _ed25519.verify(
        payloadBytes,
        signature: Signature(signatureBytes, publicKey: publicKey),
      );
      if (!valid) return null;

      final decoded = jsonDecode(utf8.decode(payloadBytes));
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }
}
