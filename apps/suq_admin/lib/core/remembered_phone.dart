// Conditional export: picks the platform-specific implementation.
export 'remembered_phone_stub.dart'
    if (dart.library.io) 'remembered_phone_io.dart'
    if (dart.library.html) 'remembered_phone_web.dart';