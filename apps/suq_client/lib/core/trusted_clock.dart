import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// A clock anchored to the last server timestamp.
///
/// Subscription dates are evaluated with [now], never directly with
/// DateTime.now(). The clock keeps a persisted high-water mark, so moving the
/// device date backwards can never increase the remaining subscription time.
///
/// This is a client-side speed bump, not a security boundary: a user who
/// controls the device clock can still freeze time. The signed offline lease
/// and periodic online verification bound how long that can last.
class TrustedClock {
  TrustedClock(this._prefs);

  final SharedPreferences _prefs;

  static const _serverMsKey = 'trusted.serverMs';
  static const _localMsKey = 'trusted.localMs';
  static const _highWaterMsKey = 'trusted.highWaterMs';
  static const _tamperedKey = 'trusted.tampered';
  static const _maxRollbackMs = 60 * 1000;

  final Stopwatch _uptime = Stopwatch()..start();
  int? _sessionBaseTrustedMs;
  int? _sessionBaseUptimeMs;

  bool get tampered => _prefs.getBool(_tamperedKey) ?? false;

  DateTime now() {
    final serverMs = _prefs.getInt(_serverMsKey);
    final localMs = _prefs.getInt(_localMsKey);
    final highWaterMs = _prefs.getInt(_highWaterMsKey) ?? 0;
    final currentMs = DateTime.now().millisecondsSinceEpoch;

    // Without a server anchor the best we can do is remember the latest time
    // this device has ever reported. That still prevents a backwards jump.
    if (serverMs == null || localMs == null) {
      final wall = mathMax(currentMs, highWaterMs);
      final trusted = mathMax(wall, _sessionTime(wall));
      _remember(trusted);
      return _fromEpoch(trusted);
    }

    if (currentMs < localMs - _maxRollbackMs) {
      unawaited(_prefs.setBool(_tamperedKey, true));
      final wall = mathMax(serverMs, highWaterMs);
      final trusted = mathMax(wall, _sessionTime(wall));
      _remember(trusted);
      return _fromEpoch(trusted);
    }

    final wall = mathMax(serverMs + (currentMs - localMs), highWaterMs);
    final trusted = mathMax(wall, _sessionTime(wall));
    _remember(trusted);
    return _fromEpoch(trusted);
  }

  /// Advances even when the device wall clock is frozen or moved backwards,
  /// for as long as this app process is alive.
  int _sessionTime(int wallMs) {
    final uptimeMs = _uptime.elapsedMilliseconds;
    final baseTrusted = _sessionBaseTrustedMs;
    final baseUptime = _sessionBaseUptimeMs;
    if (baseTrusted == null || baseUptime == null) {
      _sessionBaseTrustedMs = wallMs;
      _sessionBaseUptimeMs = uptimeMs;
      return wallMs;
    }
    return baseTrusted + (uptimeMs - baseUptime);
  }

  Future<void> anchor(DateTime serverTime) async {
    final serverMs = serverTime.toUtc().millisecondsSinceEpoch;
    await _prefs.setInt(_serverMsKey, serverMs);
    await _prefs.setInt(_localMsKey, DateTime.now().millisecondsSinceEpoch);
    // The server is authoritative, so it may also correct a clock that was
    // accidentally moved too far forward.
    await _prefs.setInt(_highWaterMsKey, serverMs);
    _sessionBaseTrustedMs = null;
    _sessionBaseUptimeMs = null;
  }

  Future<void> clearTamper() => _prefs.setBool(_tamperedKey, false);

  void _remember(int milliseconds) {
    final current = _prefs.getInt(_highWaterMsKey) ?? 0;
    if (milliseconds > current) {
      unawaited(_prefs.setInt(_highWaterMsKey, milliseconds));
    }
  }

  DateTime _fromEpoch(int milliseconds) {
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true)
        .toLocal();
  }

  static int mathMax(int a, int b) => a > b ? a : b;
}
