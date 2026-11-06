import 'dart:html' as html;

class GeminiKeyStore {
  static const _key = 'suq_admin_gemini_key';

  static Future<String?> read() async {
    try {
      final value = html.window.localStorage[_key];
      return (value == null || value.trim().isEmpty) ? null : value.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key) async {
    try {
      html.window.localStorage[_key] = key.trim();
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      html.window.localStorage.remove(_key);
    } catch (_) {}
  }
}
