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
  required int elapsedMs,
  required DateTime at,
}) => alreadyChecked
    ? null
    : Attempt(
        problem,
        firstAnswer: answer,
        elapsedMs: elapsedMs,
        answeredAt: at,
      );
