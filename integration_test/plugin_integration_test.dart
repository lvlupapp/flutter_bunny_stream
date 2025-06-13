// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_bunny_stream/flutter_bunny_stream.dart';
import 'package:flutter_bunny_stream/src/bunny_stream_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create returns BunnyStreamApi instance', (WidgetTester tester) async {
    // Test creating a BunnyStreamApi instance
    final bunnyStream = FlutterBunnyStream.create(
      accessKey: 'test_key',
      libraryId: 123,
    );
    
    // Verify that we got a non-null BunnyStreamApi instance
    expect(bunnyStream, isNotNull);
    expect(bunnyStream, isA<BunnyStreamApi>());
  });
}
