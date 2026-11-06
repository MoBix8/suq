import 'dart:io';

class RememberedPhoneStore {
  static File _file() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return File('$home${Platform.pathSeparator}.suq_admin_phone');
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

  static Future<void> write(String phone) async {
    try {
      await _file().writeAsString(phone);
    } catch (_) {}
  }
}