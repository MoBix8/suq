import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// A clock anchored to the last server timestamp.
///
/// Subscription dates are evaluated with [now], never directly with
/// DateTime.now(). If the device clock moves backwards, the app flags tampering
/// and refuses to extend the offline lease.
class TrustedClock {
  TrustedClock(this._prefs);

  final SharedPreferences _prefs;

  static const _serverMsKey = 'trusted.serverMs';
  static const _localMsKey = 'trusted.localMs';
  static const _tamperedKey = 'trusted.tampered';
  static const _maxRollbackMs = 60 * 1000;

  bool get tampered => _prefs.getBool(_tamperedKey) ?? false;

  DateTime now() {
    final serverMs = _prefs.getInt(_serverMsKey);
    final localMs = _prefs.getInt(_localMsKey);
    final currentMs = DateTime.now().millisecondsSinceEpoch;

    if (serverMs == null || localMs == null) {
      return DateTime.now();
    }

    if (currentMs < localMs - _maxRollbackMs) {
      unawaited(_prefs.setBool(_tamperedKey, true));
      return DateTime.fromMillisecondsSinceEpoch(serverMs, isUtc: true).toLocal();
    }

    final trustedUtcMs = serverMs + (currentMs - localMs);
    return DateTime.fromMillisecondsSinceEpoch(trustedUtcMs, isUtc: true).toLocal();
  }

  Future<void> anchor(DateTime serverTime) async {
    await _prefs.setInt(
      _serverMsKey,
      serverTime.toUtc().millisecondsSinceEpoch,
    );
    await _prefs.setInt(
      _localMsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> clearTamper() => _prefs.setBool(_tamperedKey, false);
}
