/// Compile-time AdMob configuration via `--dart-define` flags.
///
/// All values are resolved at build time using `String.fromEnvironment` /
/// `bool.fromEnvironment` from the Dart standard library.
/// These are `const` because dart-define values are baked into the binary
/// at compile time.
///
/// Usage example:
///   flutter run --dart-define=ADS_ENABLED=true \
///     --dart-define=ADMOB_APP_ID=ca-app-p-xxxxxxxx~yyyyyyyy \
///     --dart-define=ADMOB_BANNER_UNIT_ID=ca-app-p-xxxxxxxx/zzzzzzzz
///
/// Defaults are safe for development (ads disabled, empty IDs).
/// TODO: Replace placeholder IDs below with production AdMob IDs when ready.
class AdConfig {
  /// Whether ads are enabled for this build.
  ///
  /// Read from `ADS_ENABLED` dart-define.
  /// Default: `false` — ads are disabled in dev/debug builds.
  static const bool adsEnabled = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: false,
  );

  /// The AdMob App ID for Android.
  ///
  /// Read from `ADMOB_APP_ID` dart-define.
  /// Format: `ca-app-p-XXXXXXXX~YYYYYYYY`
  ///
  /// TODO: Replace with production AdMob App ID for Android.
  /// For testing, use the test App ID:
  ///   ca-app-pub-3940256099942544~3347511713
  static const String appId = String.fromEnvironment(
    'ADMOB_APP_ID',
    defaultValue: '',
  );

  /// The AdMob Banner ad unit ID for Android.
  ///
  /// Read from `ADMOB_BANNER_UNIT_ID` dart-define.
  /// Format: `ca-app-p-XXXXXXXX/YYYYYYYY`
  ///
  /// TODO: Replace with production AdMob Banner Unit ID for Android.
  /// For testing, use the test Banner ID:
  ///   ca-app-pub-3940256099942544/6300978111
  static const String bannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID',
    defaultValue: '',
  );
}
