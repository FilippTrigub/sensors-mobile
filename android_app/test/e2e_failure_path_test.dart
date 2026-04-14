import 'package:flutter_test/flutter_test.dart';

import 'e2e_test_helpers.dart';

const String kEndpointUrl = String.fromEnvironment('E2E_ENDPOINT_URL');
const bool kSkipFailurePath = kEndpointUrl == '';

void main() {
  ensureIntegrationBinding();

  testWidgets(
    'shows connection error when host service is unavailable',
    (WidgetTester tester) async {
      expect(kEndpointUrl, isNotEmpty);

      await launchFreshApp(tester);
      await enterHostUrlAndSubmit(tester, kEndpointUrl);

      await pumpUntilVisible(tester, find.text('Connection Error'));

      expect(find.textContaining('Failed to connect to host'), findsOneWidget);

      await captureScreenshot(tester, 'task14-failure-path');
    },
    skip: kSkipFailurePath,
  );
}
