import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class RememberedPhoneStore {
  static const _key = 'suq_admin_phone';

  static File _legacyFile() {
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return File('$home${Platform.pathSeparator}.suq_admin_phone');
  }

  static Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key)?.trim();
      if (saved != null && saved.isNotEmpty) return saved;

      // Migrate the previous desktop file so existing installs keep the value.
      final f = _legacyFile();
      if (!await f.exists()) return null;
      final value = (await f.readAsString()).trim();
      if (value.isNotEmpty) await prefs.setString(_key, value);
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, phone);
    } catch (_) {}
  }
}
