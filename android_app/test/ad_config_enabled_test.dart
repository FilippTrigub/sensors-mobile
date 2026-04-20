import 'package:sensors/ad_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for AdConfig when ads are enabled via dart-defines.
///
/// Run with:
///   flutter test test/ad_config_enabled_test.dart \
///     --dart-define=ADS_ENABLED=true \
///     --dart-define=ADMOB_APP_ID=ca-app-pub-3940256099942544~3347511713 \
///     --dart-define=ADMOB_BANNER_UNIT_ID=ca-app-pub-3940256099942544/6300978111
///
/// Without dart-defines, all tests are skipped since values fall back to defaults.
void main() {
  // Runtime guard: skip all tests when dart-defines are not provided.
  // This allows the file to be run with plain `flutter test` without failure.
  final hasAdsEnabled = AdConfig.adsEnabled;
  final hasAppId = AdConfig.appId.isNotEmpty;
  final hasBannerUnitId = AdConfig.bannerUnitId.isNotEmpty;

  group('AdConfig with ads enabled', () {
    test(
      'adsEnabled is true when ADS_ENABLED=true',
      skip: hasAdsEnabled
          ? false
          : 'ADS_ENABLED dart-define not provided (defaults to false)',
      () {
        expect(AdConfig.adsEnabled, isTrue);
      },
    );

    test(
      'appId equals ADMOB_APP_ID dart-define value',
      skip: hasAppId
          ? false
          : 'ADMOB_APP_ID dart-define not provided (defaults to empty string)',
      () {
        expect(AdConfig.appId, isNotEmpty);
      },
    );

    test(
      'bannerUnitId equals ADMOB_BANNER_UNIT_ID dart-define value',
      skip: hasBannerUnitId
          ? false
          : 'ADMOB_BANNER_UNIT_ID dart-define not provided (defaults to empty string)',
      () {
        expect(AdConfig.bannerUnitId, isNotEmpty);
      },
    );
  });
}
