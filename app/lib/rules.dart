import 'dart:math';

import 'operations.dart';

/// The starting tier sets every operation to [level].
enum Tier {
  easy('Easy', 1),
  medium('Medium', 3),
  hard('Hard', 5);

  const Tier(this.label, this.level);

  final String label;
  final int level;
}

/// One operation's difficulty level and counters, and its lifetime totals.
class Difficulty {
  const Difficulty({
    this.level = 1,
    this.upCount = 0,
    this.downCount = 0,
    this.answered = 0,
    this.correct = 0,
  });

  final int level;
  final int upCount;
  final int downCount;
  final int answered;
  final int correct;

  /// Choosing a tier: the level is set and both counters zeroed; the
  /// lifetime totals stay.
  Difficulty atTier(Tier tier) =>
      Difficulty(level: tier.level, answered: answered, correct: correct);
}

const levelUpAfter = 3;
const levelDownAfter = 2;

/// The "Difficulty counters and totals" column of the practice events table
/// for one recorded [attempt] of that operation.
///
/// A skip changes nothing; retries, "Next" after a check and invalid input
/// record no attempt and never reach this function.
Difficulty difficultyAfter(Difficulty before, Attempt attempt) {
  if (attempt.skipped) return before;
  final correct = attempt.correct;
  final hinted = attempt.hintsUsed > 0;
  var up = correct ? (hinted ? before.upCount : before.upCount + 1) : 0;
  var down = correct ? (hinted ? before.downCount : 0) : before.downCount + 1;
  var level = before.level;
  // Both counters restart at a threshold, also when the level is at a limit.
  if (up >= levelUpAfter) {
    level = min(level + 1, maxLevel);
    up = down = 0;
  } else if (down >= levelDownAfter) {
    level = max(level - 1, 1);
    up = down = 0;
  }
  return Difficulty(
    level: level,
    upCount: up,
    downCount: down,
    answered: before.answered + 1,
    correct: before.correct + (correct ? 1 : 0),
  );
}

/// The History column of the practice events table.
///
/// [answer] is the parsed answer of a valid check, or null for "Next".
/// Only the first event per problem is recorded: a retry or a "Next" after a
/// valid check returns null, a "Next" without one returns a Skipped attempt.
/// Invalid input is not an event and never reaches this function.
Attempt? historyEntry({
  required Problem problem,
  required bool alreadyChecked,
  required num? answer,
  required int hintsUsed,
  required int elapsedMs,
  required DateTime at,
}) => alreadyChecked
    ? null
    : Attempt(
        problem,
        firstAnswer: answer,
        hintsUsed: hintsUsed,
        elapsedMs: elapsedMs,
        answeredAt: at,
      );

enum HintEvent {
  /// "Hint" (from 0 steps) or "Next step": one more step.
  reveal,

  /// The first valid check of the problem was wrong.
  wrongFirstCheck,
}

/// How many solution steps are revealed after [event].
///
/// The last step states the answer, so before the first valid check
/// ([checked] false) at most `stepCount - 1` steps can be revealed.
int nextRevealed({
  required int revealed,
  required HintEvent event,
  required int stepCount,
  required bool checked,
}) => switch (event) {
  HintEvent.reveal => min(revealed + 1, checked ? stepCount : stepCount - 1),
  HintEvent.wrongFirstCheck => max(revealed, 1),
};
