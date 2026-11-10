class SupplierConfig {
  static const String appName = 'SUQ SUPPLIER';
  static const String appTagline = 'Supplier workspace';
  static const String version = '1.0.0';

  /// Override at build time with:
  /// `flutter build apk --dart-define=SUQ_API=https://your-server`
  static String get apiBaseUrl {
    const override = String.fromEnvironment('SUQ_API', defaultValue: '');
    if (override.isNotEmpty) return override;
    return 'https://suq-silk.vercel.app';
  }
}
