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

const dailyGoal = 10;
const maxComboBonus = 10;
const xpPerLevelStep = 100;

/// A local date more than this many days before `lastActiveDate` means the
/// stored date came from a clock that was wrong in the future.
const clockCorrectionDays = 7;

/// XP, combo, daily goal and streak. Dates are local calendar dates stored
/// as `yyyy-MM-dd`; null until the first one is set.
class GameState {
  const GameState({
    this.xp = 0,
    this.combo = 0,
    this.dailyCount = 0,
    this.lastActiveDate,
    this.lastGoalDate,
    this.streak = 0,
    this.bestStreak = 0,
  });

  final int xp;
  final int combo;
  final int dailyCount;
  final String? lastActiveDate;
  final String? lastGoalDate;
  final int streak;
  final int bestStreak;

  GameState _copy({
    int? xp,
    int? combo,
    int? dailyCount,
    String? lastActiveDate,
    String? lastGoalDate,
    int? streak,
    int? bestStreak,
  }) => GameState(
    xp: xp ?? this.xp,
    combo: combo ?? this.combo,
    dailyCount: dailyCount ?? this.dailyCount,
    lastActiveDate: lastActiveDate ?? this.lastActiveDate,
    lastGoalDate: lastGoalDate ?? this.lastGoalDate,
    streak: streak ?? this.streak,
    bestStreak: bestStreak ?? this.bestStreak,
  );
}

/// The XP for a first-valid-check correct answer at difficulty [level].
int xpFor({
  required int level,
  required int comboBefore,
  required bool hinted,
}) {
  final base = level * (10 + min<int>(comboBefore, maxComboBonus));
  return hinted ? (base + 1) ~/ 2 : base;
}

/// The total XP at which player level [level] is reached.
int xpForLevel(int level) => xpPerLevelStep * level * (level - 1) ~/ 2;

int playerLevel(int xp) {
  var level = 1;
  while (xpForLevel(level + 1) <= xp) {
    level++;
  }
  return level;
}

/// The local calendar date of [now] as `yyyy-MM-dd`.
String localDate(DateTime now) => _format(now.year, now.month, now.day);

/// Computed on UTC dates, so 23- and 25-hour days cannot skip or repeat one.
String dateBefore(String date) => _shift(date, -1);

String _shift(String date, int days) {
  final parsed = DateTime.parse(date);
  final shifted = DateTime.utc(parsed.year, parsed.month, parsed.day + days);
  return _format(shifted.year, shifted.month, shifted.day);
}

String _format(int year, int month, int day) =>
    '${year.toString().padLeft(4, '0')}-'
    '${month.toString().padLeft(2, '0')}-'
    '${day.toString().padLeft(2, '0')}';

String _later(String a, String? b) => b != null && b.compareTo(a) > 0 ? b : a;

/// `max(localDate(now), lastActiveDate)`: a clock set back never moves a
/// date back.
String _today(GameState state, DateTime now) =>
    _later(localDate(now), state.lastActiveDate);

/// Rule step 1, also run on load and on app resume: clock correction, then
/// day change.
GameState dayChanged(GameState state, DateTime now) {
  final clockDate = localDate(now);
  final active = state.lastActiveDate;
  if (active != null &&
      clockDate.compareTo(_shift(active, -clockCorrectionDays)) < 0) {
    final goal = state.lastGoalDate;
    return GameState(
      xp: state.xp,
      combo: state.combo,
      lastActiveDate: clockDate,
      lastGoalDate: goal != null && goal.compareTo(clockDate) > 0
          ? dateBefore(clockDate)
          : goal,
      streak: state.streak,
      bestStreak: state.bestStreak,
    );
  }
  final today = _today(state, now);
  if (today == active) return state;
  return state._copy(dailyCount: 0, lastActiveDate: today);
}

/// Rule steps 1, 2 and 4 for one recorded [attempt] (step 3 is
/// [difficultyAfter]; step 5, the player level, follows from the XP).
GameState gameAfter(GameState before, Attempt attempt, DateTime now) {
  final state = dayChanged(before, now);
  if (attempt.skipped || !attempt.correct) return state._copy(combo: 0);

  final counted = state._copy(
    xp:
        state.xp +
        xpFor(
          level: attempt.problem.level,
          comboBefore: state.combo,
          hinted: attempt.hintsUsed > 0,
        ),
    combo: state.combo + 1,
    dailyCount: state.dailyCount + 1,
  );
  if (counted.dailyCount != dailyGoal) return counted;

  final today = counted.lastActiveDate!;
  final streak = switch (counted.lastGoalDate) {
    final goal when goal == today => counted.streak,
    final goal when goal == dateBefore(today) => counted.streak + 1,
    _ => 1,
  };
  return counted._copy(
    lastGoalDate: today,
    streak: streak,
    bestStreak: max(counted.bestStreak, streak),
  );
}

/// The streak shown: 0 once a date without a reached goal has passed.
int displayedStreak(GameState state, DateTime now) {
  final today = _today(state, now);
  final goal = state.lastGoalDate;
  return goal == today || goal == dateBefore(today) ? state.streak : 0;
}

/// The goal ring value: 0 after midnight even before any event.
int goalRingValue(GameState state, DateTime now) =>
    state.lastActiveDate == localDate(now) ? state.dailyCount : 0;

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
