import 'package:android_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void ensureIntegrationBinding() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

Future<void> launchFreshApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  app.main();
  await tester.pump();
  await pumpUntilVisible(tester, find.text('Host Setup'));
}

Future<void> enterHostUrlAndSubmit(
  WidgetTester tester,
  String endpointUrl,
) async {
  final Finder hostField = find.byType(TextFormField);
  final Finder saveButton = find.text('Save & Continue');

  expect(hostField, findsOneWidget);
  expect(saveButton, findsOneWidget);

  await tester.enterText(hostField, endpointUrl);
  await tester.pump();
  await tester.tap(saveButton);
  await tester.pump();
}

Future<void> pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();

  while (stopwatch.elapsed < timeout) {
    await Future<void>.delayed(step);
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  expect(finder, findsOneWidget);
}

Future<void> captureScreenshot(WidgetTester tester, String name) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await tester.pump();
  debugPrint('Reached integration checkpoint: $name');
}

List<String> visibleTextValues() {
  final Set<String> values = <String>{};

  for (final Element element in find.byType(Text).evaluate()) {
    final Text widget = element.widget as Text;
    final String? value = widget.data ?? widget.textSpan?.toPlainText();
    if (value != null && value.isNotEmpty) {
      values.add(value);
    }
  }

  return values.toList()..sort();
}
