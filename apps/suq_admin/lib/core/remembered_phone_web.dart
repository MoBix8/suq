import 'dart:html' as html;

class RememberedPhoneStore {
  static const _key = 'suq_admin_phone';

  static Future<String?> read() async {
    try {
      final value = html.window.localStorage[_key];
      return (value == null || value.trim().isEmpty) ? null : value.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String phone) async {
    try {
      html.window.localStorage[_key] = phone;
    } catch (_) {}
  }
}