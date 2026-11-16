import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage shared by the Qur'an reader, the player and the tasbih counter.
///
/// The concrete instance is supplied from `main()` so every tool reads the same
/// preferences without a second async load.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);
