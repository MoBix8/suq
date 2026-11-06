import 'dart:io';

class GeminiKeyStore {
  static File _file() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return File('$home${Platform.pathSeparator}.suq_admin_gemini_key');
  }

  static Future<String?> read() async {
    try {
      final f = _file();
      if (!await f.exists()) return null;
      final value = (await f.readAsString()).trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key) async {
    try {
      await _file().writeAsString(key.trim());
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final f = _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
