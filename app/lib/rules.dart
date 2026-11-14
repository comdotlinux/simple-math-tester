import 'dart:math';

import 'operations.dart';

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
