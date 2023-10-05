// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';

import 'package:simple_math_tester/main.dart';

void main() {

  testWidgets(skip: true, 'Can Find The Problem and Result Pages By Their Keys', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => MathTesterModel()),],
          child: const MathTesterApp()
        )
    );
    await tester.pump();
    // Verify that our counter starts at 0.
    expect(find.byKey(materialAppKey), findsOneWidget);
    expect(find.byKey(homePageKey), findsOneWidget);
    expect(find.byKey(problemsPageKey), findsOneWidget);

    expect(find.byKey(questionOnProblemsPageKey), findsOneWidget);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.question_answer_rounded));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.byKey(noResultsOnResultsPageKey), findsOneWidget);
    expect(find.byKey(questionOnProblemsPageKey), findsNothing);
  });
}
