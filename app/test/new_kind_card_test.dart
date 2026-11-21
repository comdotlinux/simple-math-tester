import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/labels.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/progress_store.dart';
import 'package:simple_math_tester/rules.dart';

import 'en.dart';
import 'fake_store.dart';

/// The one-time card above the toggles that names a kind outside the
/// arithmetic kinds and offers to switch it on.
void main() {
  final card = find.byKey(newKindCardKey);
  final dismiss = find.byKey(newKindDismissKey);
  final newKinds = OperationType.values.where(
    (kind) => !arithmeticKinds.contains(kind),
  );

  Future<MathTesterModel> launch(
    WidgetTester tester, {
    // Practice starts as after a tap on Start; false stays before it.
    bool start = true,
    Progress? progress,
    FakeStore? store,
    Size size = const Size(1000, 900),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      initialProblem: const ArithmeticProblem(12, 3, OperationType.plus, 15),
      progress: progress ?? Progress(tier: Tier.easy),
      store: store,
      ticker: () => const Stream.empty(),
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        key: ObjectKey(model),
        value: model,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: const MathTesterApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (start) {
      model.startPractice();
      await tester.pumpAndSettle();
    }
    return model;
  }

  Progress saved(FakeStore store) =>
      Progress.decode(store.values[progressKey]!);

  /// Algebra's card is gone; the next new kind, Geometry, has its own.
  void expectNextCard() {
    expect(find.text('New: Algebra'), findsNothing);
    expect(find.text('New: Geometry'), findsOneWidget);
  }

  testWidgets('tapping it switches Algebra on; it never shows again, even '
      'after Algebra is switched off and the app restarts', (tester) async {
    final store = FakeStore();
    final model = await launch(tester, store: store);
    expect(find.text('New: Algebra'), findsOneWidget);
    expect(find.text('Tap here to switch it on'), findsOneWidget);

    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(model.selectedOperations, contains(OperationType.algebra));
    expectNextCard();

    model.toggleOperation(OperationType.algebra);
    await tester.pumpAndSettle();
    expect(model.selectedOperations, arithmeticKinds);
    expectNextCard();
    expect(saved(store).seenKinds, ['algebra']);

    await launch(tester, progress: saved(store));
    expectNextCard();
  });

  testWidgets('closing it switches nothing on and hides it for good', (
    tester,
  ) async {
    final store = FakeStore();
    final model = await launch(tester, store: store);
    await tester.ensureVisible(dismiss);
    await tester.tap(dismiss);
    await tester.pumpAndSettle();
    expectNextCard();
    expect(model.selectedOperations, arithmeticKinds);
    expect(saved(store).seenKinds, ['algebra']);

    await launch(tester, progress: saved(store));
    expectNextCard();
  });

  testWidgets('it waits for a tier, gives way to a sprint, and does not show '
      'for a kind already on or already answered', (tester) async {
    await launch(tester, progress: Progress());
    expect(find.byKey(tierPickerKey), findsOneWidget);
    expect(card, findsNothing);

    final model = await launch(tester);
    model.startSprint();
    await tester.pump();
    expect(card, findsNothing);
    model.endSprint();
    await tester.pump();
    expect(card, findsOneWidget);

    await launch(
      tester,
      progress: Progress(
        tier: Tier.easy,
        selectedOperations: {...arithmeticKinds, OperationType.algebra},
      ),
    );
    expectNextCard();

    await launch(
      tester,
      progress: Progress(
        tier: Tier.easy,
        difficulty: {
          OperationType.algebra: const Difficulty(level: 1, answered: 1),
        },
      ),
    );
    expectNextCard();
  });

  testWidgets('every kind outside arithmetic gets its own card from its '
      'name alone', (tester) async {
    for (final kind in newKinds) {
      await launch(
        tester,
        progress: Progress(
          tier: Tier.easy,
          seenKinds: [
            for (final other in newKinds)
              if (other != kind) other.name,
          ],
        ),
      );
      expect(find.text(en.newKindTitle(kind.label(en))), findsOneWidget);
    }
  });

  for (final (size, scale) in [
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 2.0),
    (const Size(1280, 900), 2.0),
  ]) {
    testWidgets('at ${size.width.toInt()}x${size.height.toInt()}, text '
        '$scale, it fits, is one button with its words, and its close '
        'button is a 48 dp target', (tester) async {
      final semantics = tester.ensureSemantics();
      await launch(tester, size: size, scale: scale);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        tester.getSemantics(
          find.descendant(of: card, matching: find.byType(ListTile)),
        ),
        isSemantics(
          label: 'New: Algebra\nTap here to switch it on',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(dismiss),
        isSemantics(tooltip: 'No, thanks', isButton: true, hasTapAction: true),
      );
      final target = tester.getSize(dismiss);
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
      // The close button comes after the words, in reading and focus order.
      expect(
        tester.getTopLeft(dismiss).dx,
        greaterThan(tester.getTopLeft(find.text('New: Algebra')).dx),
      );
      semantics.dispose();
    });
  }

  // A short phone opens scrolled to the answer; a card shown once must
  // still be on screen, whole, when the page first shows it. Measured with
  // the bundled Roboto, as on a device: the test font draws every glyph a
  // full em wide.
  group('on a short phone', () {
    setUpAll(() async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final family in manifest.cast<Map<String, dynamic>>()) {
        final loader = FontLoader(family['family'] as String);
        for (final font in (family['fonts'] as List).cast<Map>()) {
          loader.addFont(rootBundle.load(font['asset'] as String));
        }
        await loader.load();
      }
    });

    /// The part of [finder]'s rect that the screen and its page scroll show.
    Rect shown(WidgetTester tester, Finder finder, Size size) {
      final view =
          Scrollable.of(tester.element(finder)).context.findRenderObject()!
              as RenderBox;
      return tester
          .getRect(finder)
          .intersect(Offset.zero & size)
          .intersect(view.localToGlobal(Offset.zero) & view.size);
    }

    // A short phone opens scrolled to the answer; a card shown once must
    // still be on screen, whole, when the page first shows it.
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      for (final scale in const [1.0, 2.0]) {
        for (final layout in LayoutMode.values) {
          final tag =
              '${size.width.toInt()}x${size.height.toInt()}, text $scale, '
              '${layout.name}';

          testWidgets('at $tag the page opens with the whole card in view, '
              'for Algebra and then Geometry', (tester) async {
            for (final (seen, title) in [
              (<String>[], 'New: Algebra'),
              (['algebra'], 'New: Geometry'),
            ]) {
              await launch(
                tester,
                progress: Progress(
                  tier: Tier.easy,
                  layoutMode: layout,
                  seenKinds: seen,
                ),
                size: size,
                scale: scale,
              );
              expect(tester.takeException(), isNull);
              expect(find.text(title), findsOneWidget);
              expect(
                shown(tester, card, size),
                tester.getRect(card),
                reason: title,
              );
            }
          });

          testWidgets('at $tag without a card the page still opens with the '
              'question in view', (tester) async {
            await launch(
              tester,
              progress: Progress(
                tier: Tier.easy,
                layoutMode: layout,
                seenKinds: [for (final kind in newKinds) kind.name],
              ),
              size: size,
              scale: scale,
            );
            expect(tester.takeException(), isNull);
            expect(card, findsNothing);
            final question = find.byKey(questionOnProblemsPageKey);
            expect(shown(tester, question, size), tester.getRect(question));
          });
        }
      }
    }
  });

  group('saved progress', () {
    test('seenKinds survives a round trip with names this build does not '
        'know; an empty list writes no field', () {
      final source = jsonEncode({
        'schemaVersion': 2,
        'seenKinds': ['geometry', 'algebra'],
      });
      final decoded = Progress.decode(source);
      expect(decoded.seenKinds, ['geometry', 'algebra']);
      final again = jsonDecode(decoded.encode()) as Map<String, Object?>;
      expect(again['seenKinds'], ['geometry', 'algebra']);
      expect(decoded.extra, isEmpty);

      expect(Progress().encode(), isNot(contains('seenKinds')));
      expect(() => Progress.decode('{"seenKinds":[1]}'), throwsFormatException);
    });

    test('an older build keeps the field: a top-level field a build does '
        'not know is written back unchanged', () {
      // This build plays the older one with a field from a newer build; an
      // older build reads seenKinds the same way.
      final newer = {
        'seenKinds': ['algebra'],
        'nextField': {
          'kinds': ['geometry'],
          'count': 2,
        },
      };
      final decoded = Progress.decode(jsonEncode(newer));
      expect(decoded.extra, {'nextField': newer['nextField']});
      final again = jsonDecode(decoded.encode()) as Map<String, Object?>;
      expect(again['nextField'], newer['nextField']);
      expect(again['seenKinds'], newer['seenKinds']);
    });

    test('switching a new kind on marks it seen; arithmetic kinds never '
        'are', () {
      final on = Progress().withSelectedOperations({
        OperationType.plus,
        OperationType.algebra,
      });
      expect(on.seenKinds, ['algebra']);
      final off = on.withSelectedOperations({OperationType.plus});
      expect(off.seenKinds, ['algebra']);
      expect(off.withSeenKind(OperationType.algebra).seenKinds, [
        'algebra',
      ], reason: 'no name twice');
    });
  });
}
