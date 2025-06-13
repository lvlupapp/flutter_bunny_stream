// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_bunny_stream_example/main.dart';

void main() {
  testWidgets('App loads and shows title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BunnyStreamExampleApp());

    // Verify that the app title is shown
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is Text &&
                         widget.data == 'Bunny Stream Example',
      ),
      findsOneWidget,
    );
    
    // Verify that the setup screen is shown initially
    expect(find.text('Enter Bunny Stream Credentials'), findsOneWidget);
  });
}
