import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_test_helpers.dart';

const String kEndpointUrl = String.fromEnvironment('E2E_ENDPOINT_URL');
const String kExpectedHostname = String.fromEnvironment(
  'E2E_EXPECTED_HOSTNAME',
);
const bool kSkipHappyPath = kEndpointUrl == '' || kExpectedHostname == '';

void main() {
  ensureIntegrationBinding();

  testWidgets('renders live host data on Android emulator', (
    WidgetTester tester,
  ) async {
    expect(kEndpointUrl, isNotEmpty);
    expect(kExpectedHostname, isNotEmpty);

    final HttpClient probeClient = HttpClient();
    final HttpClientRequest request = await probeClient.getUrl(
      Uri.parse(kEndpointUrl),
    );
    final HttpClientResponse probeResponse = await request.close();
    debugPrint('Direct probe status: ${probeResponse.statusCode}');
    probeClient.close(force: true);

    await launchFreshApp(tester);
    await enterHostUrlAndSubmit(tester, kEndpointUrl);

    await Future<void>.delayed(const Duration(seconds: 3));
    await tester.pump();
    debugPrint('Visible texts after submit: ${visibleTextValues()}');

    await pumpUntilVisible(tester, find.text(kExpectedHostname));

    expect(find.textContaining('Last updated:'), findsOneWidget);
    expect(find.text('Connection Error'), findsNothing);

    await captureScreenshot(tester, 'task14-happy-path');
  }, skip: kSkipHappyPath);
}
