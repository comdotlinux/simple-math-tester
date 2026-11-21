import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/operations.dart';

import 'oracle.dart';

/// Known-answer rows from Illustrative Mathematics (CC BY 4.0, see
/// docs/attributions.md), so the generators and the oracle cannot share a
/// wrong idea unnoticed. Each row is an equation printed on the cited page
/// and the answer printed there; nothing here is computed. Changes made:
/// the letter is written n, and minus, times and divide use the app's signs.
///
/// - [printed]: the equation as the page prints it (letters as there).
/// - [question]: the same equation in the app's notation.
/// - [answer]: the answer the page prints.
const _rows =
    <
      ({
        String id,
        String source,
        String lesson,
        String url,
        String printed,
        String question,
        num answer,
      })
    >[
      (
        id: 'A01',
        source: 'IM K–5 Math',
        lesson: 'Grade 2, Unit 1, Lesson 2',
        url: 'https://im.kendallhunt.com/k5/teachers/grade-2/unit-1/lesson-2/lesson.html',
        printed: '2 + __ = 10',
        question: '2 + n = 10',
        answer: 8,
      ),
      (
        id: 'A04',
        source: 'IM K–5 Math',
        lesson: 'Grade 3, Unit 4, Family materials',
        url: 'https://im.kendallhunt.com/k5/families/grade-3/unit-4/family-materials.html',
        printed: '78 ÷ 3',
        question: '78 ÷ 3',
        answer: 26,
      ),
      (
        id: 'A06',
        source: 'IM 6–8 Math',
        lesson: 'Grade 6, Unit 5, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/1/5/index.html',
        printed: '784 ÷ 7',
        question: '784 ÷ 7',
        answer: 112,
      ),
      (
        id: 'A07',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 6, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/2/6/index.html',
        printed: '12 - c = 10',
        question: '12 − n = 10',
        answer: 2,
      ),
      (
        id: 'A08',
        source: 'IM 6–8 Math',
        lesson: 'Grade 6, Unit 6, Lesson 2',
        url: 'https://im.kendallhunt.com/MS/students/1/6/2/index.html',
        printed: 'u + 1 = 8',
        question: 'n + 1 = 8',
        answer: 7,
      ),
      (
        id: 'A09',
        source: 'IM 6–8 Math',
        lesson: 'Grade 6, Unit 6, Lesson 1',
        url: 'https://im.kendallhunt.com/MS/students/1/6/1/index.html',
        printed: 'y + 3 = 21',
        question: 'n + 3 = 21',
        answer: 18,
      ),
      (
        id: 'A10',
        source: 'IM 6–8 Math',
        lesson: 'Grade 6, Unit 6, Lesson 1',
        url: 'https://im.kendallhunt.com/MS/students/1/6/1/index.html',
        printed: '3·x = 21',
        question: '3 × n = 21',
        answer: 7,
      ),
      (
        id: 'A11',
        source: 'IM 6–8 Math',
        lesson: 'Grade 6, Unit 6, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/1/6/index.html',
        printed: '15 = 3x',
        question: '15 = 3n',
        answer: 5,
      ),
      (
        id: 'A12',
        source: 'IM 6–8 Math',
        lesson: 'Grade 6, Unit 6, Lesson 3',
        url: 'https://im.kendallhunt.com/MS/students/1/6/3/index.html',
        printed: '11 = y + 5',
        question: '11 = n + 5',
        answer: 6,
      ),
      (
        id: 'A13',
        source: 'IM 6–8 Math',
        lesson: 'Grade 6, Unit 6, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/1/6/index.html',
        printed: '11 = x + 2',
        question: '11 = n + 2',
        answer: 9,
      ),
      (
        id: 'A15',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 6, Lesson 7',
        url: 'https://im.kendallhunt.com/MS/students/2/6/7/index.html',
        printed: '7 = 3x + 1',
        question: '7 = 3n + 1',
        answer: 2,
      ),
      (
        id: 'A16',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 6, Lesson 8',
        url: 'https://im.kendallhunt.com/MS/students/2/6/8/index.html',
        printed: '3x + 6 = 18',
        question: '3n + 6 = 18',
        answer: 4,
      ),
      (
        id: 'A17',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 6, Lesson 11',
        url: 'https://im.kendallhunt.com/MS/students/2/6/11/index.html',
        printed: '4 + 6x = 22',
        question: '4 + 6n = 22',
        answer: 3,
      ),
      (
        id: 'A18',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 6, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/2/6/index.html',
        printed: '3e + 10.50 = 30',
        question: '3n + 10.50 = 30',
        answer: 6.5,
      ),
      (
        id: 'A19',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 6, Lesson 8',
        url: 'https://im.kendallhunt.com/MS/students/2/6/8/index.html',
        printed: '3(x + 2) = 18',
        question: '3(n + 2) = 18',
        answer: 4,
      ),
      (
        id: 'A20',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 6, Lesson 9',
        url: 'https://im.kendallhunt.com/MS/students/2/6/9/index.html',
        printed: '2(x - 5) = -6',
        question: '2(n − 5) = −6',
        answer: 2,
      ),
      (
        id: 'A21',
        source: 'IM 6–8 Math',
        lesson: 'Grade 8, Unit 4, Lesson 6',
        url: 'https://im.kendallhunt.com/MS/students/3/4/6/index.html',
        printed: '2(x + 5) = 10',
        question: '2(n + 5) = 10',
        answer: 0,
      ),
      (
        id: 'A25',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 5, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/2/5/index.html',
        printed: 'x + 11 = -4',
        question: 'n + 11 = −4',
        answer: -15,
      ),
      (
        id: 'A26',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 5, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/2/5/index.html',
        printed: '25 + a = 17',
        question: '25 + n = 17',
        answer: -8,
      ),
      (
        id: 'A27',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 5, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/2/5/index.html',
        printed: '-4b = -30',
        question: '−4n = −30',
        answer: 7.5,
      ),
      (
        id: 'A31',
        source: 'IM 6–8 Math',
        lesson: 'Grade 6, Unit 6, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/1/6/index.html',
        printed: '2y = 11',
        question: '2n = 11',
        answer: 5.5,
      ),
      (
        id: 'A32',
        source: 'IM 6–8 Math',
        lesson: 'Grade 6, Unit 6, Lesson 4',
        url: 'https://im.kendallhunt.com/MS/students/1/6/4/index.html',
        printed: '13.68 + x = 16.05',
        question: '13.68 + n = 16.05',
        answer: 2.37,
      ),
      (
        id: 'A33',
        source: 'IM 6–8 Math',
        lesson: 'Grade 8, Unit 4, Lesson 1',
        url: 'https://im.kendallhunt.com/MS/students/3/4/1/index.html',
        printed: '2x + 4 = 18',
        question: '2n + 4 = 18',
        answer: 7,
      ),
      (
        id: 'A34',
        source: 'IM K–5 Math',
        lesson: 'Grade 1, Unit 2, Lesson 21',
        url: 'https://im.kendallhunt.com/k5/teachers/grade-1/unit-2/lesson-21/lesson.html',
        printed: '4 + □ = 5',
        question: '4 + n = 5',
        answer: 1,
      ),
      (
        id: 'A35',
        source: 'IM K–5 Math',
        lesson: 'Grade 1, Unit 2, Lesson 21',
        url: 'https://im.kendallhunt.com/k5/teachers/grade-1/unit-2/lesson-21/lesson.html',
        printed: '5 - □ = 4',
        question: '5 − n = 4',
        answer: 1,
      ),
      (
        id: 'A36',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 5, Lesson 11',
        url: 'https://im.kendallhunt.com/MS/students/2/5/11/index.html',
        printed: 'x ÷ -2 = 5',
        question: 'n ÷ −2 = 5',
        answer: -10,
      ),
      (
        id: 'A37',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 5, Lesson 15',
        url: 'https://im.kendallhunt.com/MS/students/2/5/15/index.html',
        printed: 'x + 8 = -5',
        question: 'n + 8 = −5',
        answer: -13,
      ),
      (
        id: 'A38',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 5, Lesson 16',
        url: 'https://im.kendallhunt.com/MS/students/2/5/16/index.html',
        printed: '-3 + x = -17',
        question: '−3 + n = −17',
        answer: -14,
      ),
      (
        id: 'A39',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 6, Lesson 4',
        url: 'https://im.kendallhunt.com/MS/students/2/6/4/index.html',
        printed: '34 + 10x = 144',
        question: '34 + 10n = 144',
        answer: 11,
      ),
      (
        id: 'A40',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 6, Lesson 5',
        url: 'https://im.kendallhunt.com/MS/students/2/6/5/index.html',
        printed: '10(x + 2) = 140',
        question: '10(n + 2) = 140',
        answer: 12,
      ),
      (
        id: 'A41',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 6, Lesson 5',
        url: 'https://im.kendallhunt.com/MS/students/2/6/5/index.html',
        printed: '2(y + 10) = 140',
        question: '2(n + 10) = 140',
        answer: 60,
      ),
      (
        id: 'A42',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 6, Lesson 12',
        url: 'https://im.kendallhunt.com/MS/students/2/6/12/index.html',
        printed: '1.25p - 10 = 152.50',
        question: '1.25n − 10 = 152.50',
        answer: 130,
      ),
      (
        id: 'A43',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 7, Lesson 5',
        url: 'https://im.kendallhunt.com/MS/students/2/7/5/index.html',
        printed: '3x + 90 = 144',
        question: '3n + 90 = 144',
        answer: 18,
      ),
    ];

/// The rows an app family builds exactly, within the level's ranges: the
/// row, the level, the variant and the params read off the printed
/// equation. Levels 1 and 2 show the unknown as the blank.
const _built = <(String, int, String, List<int>)>[
  ('A01', 1, 'missingSecondAddend', [2, 8]),
  ('A34', 1, 'missingSecondAddend', [4, 1]),
  ('A07', 1, 'missingSubtrahend', [10, 2]),
  ('A35', 1, 'missingSubtrahend', [4, 1]),
  ('A08', 1, 'missingFirstAddend', [1, 7]),
  ('A10', 2, 'missingSecondFactor', [3, 7]),
  ('A09', 3, 'nPlusA', [3, 18]),
  ('A10', 3, 'aTimesN', [3, 7]),
  ('A16', 4, 'anPlusB', [3, 6, 4]),
  ('A33', 4, 'anPlusB', [2, 4, 7]),
  ('A19', 5, 'aBracketNPlusB', [3, 2, 4]),
  ('A20', 5, 'aBracketNMinusB', [2, 5, 2]),
  ('A21', 5, 'aBracketNPlusB', [2, 5, 0]),
  ('A31', 5, 'anTenths', [2, 55]),
];

/// None of the public pages read so far (issue #148 searched IM 6–8 and
/// K–5 for them) prints an answer for these forms in the app's notation
/// and ranges; they rest on the oracle and the exhaustive runs alone.
const _familiesWithoutRow = {
  'missingMinuend',
  'missingFirstFactor',
  'missingDivisor',
  'missingDividend',
  'nMinusA',
  'nDividedByA',
  'anMinusB',
  'nDividedByAPlusB',
  'anPlusBNegativeN',
  // Squares and roots (issue #155): no textbook page has been searched for
  // them yet.
  'missingSquare',
  'missingSquareRoot',
  'aSquared',
  'squareRootOfC',
  'nSquared',
  'anSquared',
};

void main() {
  const kind = OperationType.algebra;
  final source = kind.source as AlgebraSource;

  test('every row has its own id, and each built row is a row', () {
    final ids = _rows.map((row) => row.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, containsAll(_built.map((b) => b.$1).toSet()));
  });

  test('every level has a built row', () {
    expect(_built.map((b) => b.$2).toSet(), {
      for (var l = 1; l <= kind.highestLevel; l++) l,
    });
  });

  test('families with a built row, and the families without one', () {
    final families = {
      for (final level in source.levels)
        for (final (variant, _) in level) variant,
    };
    expect(
      families.difference(_built.map((b) => b.$3).toSet()),
      _familiesWithoutRow,
    );
  });

  group('the oracle alone', () {
    for (final row in _rows) {
      test(
        '${row.id}: ${row.printed} has the printed answer ${row.answer}',
        () {
          expect(check(row.question, row.answer), Verdict.ok);
          expect(check(row.question, row.answer + 1), isNot(Verdict.ok));
        },
      );
    }
  });

  group('build and the oracle', () {
    for (final (id, level, variant, params) in _built) {
      final row = _rows.firstWhere((row) => row.id == id);
      test('${row.id}: level $level $variant $params is ${row.printed}', () {
        final ranges = source.levels[level - 1]
            .firstWhere((family) => family.$1 == variant)
            .$2;
        for (final (i, (low, high)) in ranges.indexed) {
          expect(params[i], inInclusiveRange(low, high), reason: 'param $i');
        }
        final problem = source.build(kind, variant, params, level: level)!;
        expect(
          problem.question,
          level <= 2 ? row.question.replaceAll('n', box) : row.question,
        );
        expect(problem.resultHundredths, (row.answer * 100).round());
        expect(check(problem.question, row.answer), Verdict.ok);
        expect(check(problem.question, row.answer + 1), isNot(Verdict.ok));
      });
    }
  });
}
