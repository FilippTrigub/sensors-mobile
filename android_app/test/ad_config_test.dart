import 'package:sensors/ad_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdConfig defaults', () {
    test('adsEnabled is false by default', () {
      expect(AdConfig.adsEnabled, isFalse);
    });

    test('appId is empty string by default', () {
      expect(AdConfig.appId, isEmpty);
    });

    test('bannerUnitId is empty string by default', () {
      expect(AdConfig.bannerUnitId, isEmpty);
    });
  });
}
