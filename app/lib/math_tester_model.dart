import 'dart:async';
import 'dart:math';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'operations.dart';
import 'progress.dart';
import 'progress_store.dart';
import 'rules.dart';
import 'solution_steps.dart';

/// What a vibration marks.
enum Haptic { key, correct, wrong, celebrate }

/// Light on a key press; stronger for a checked answer and a milestone.
void playHaptic(Haptic haptic) => unawaited(switch (haptic) {
  Haptic.key => HapticFeedback.lightImpact(),
  Haptic.correct => HapticFeedback.mediumImpact(),
  Haptic.wrong => HapticFeedback.heavyImpact(),
  Haptic.celebrate => HapticFeedback.vibrate(),
});

class MathTesterModel extends ChangeNotifier {
  MathTesterModel({
    Problem? initialProblem,
    this.nextProblem,
    Random? random,
    DateTime Function()? clock,
    ProgressStore? store,
    Progress? progress,
    this._canSave = true,
    Stream<void> Function()? ticker,
    void Function(Haptic)? haptic,
  }) : _ticker = ticker ?? _everySecond,
       // Silent unless given, so a model built without a binding works.
       _haptic = haptic ?? _silent,
       _random = random ?? Random(),
       _clock = clock ?? DateTime.now,
       _store = store ?? MemoryProgressStore(),
       _progress = progress ?? Progress() {
    _progress = _withDayChange(_progress);
    _show(initialProblem ?? _draw());
  }

  static void _silent(Haptic _) {}

  static Stream<void> _everySecond() =>
      Stream.periodic(const Duration(seconds: 1));

  /// Wakes the sprint countdown; the time itself is read from the clock.
  final Stream<void> Function() _ticker;
  final void Function(Haptic) _haptic;
  final Random _random;
  final DateTime Function() _clock;
  final ProgressStore _store;
  late final _writer = ProgressWriter(_store);
  Progress _progress;
  bool _canSave;
  bool _retried = false;
  @visibleForTesting
  final Problem Function()? nextProblem;

  late Problem _current;
  late List<String> _steps;
  late DateTime _shownAt;
  late bool _checked;
  late int _revealed;
  String _draftInput = '';
  String? _validationMessage;
  bool? _answerCorrect;
  int _currentPage = 0;
  DateTime? _sprintStart;
  int _sprintStartXp = 0;
  List<int> _sprintLevels = const [];
  StreamSubscription<void>? _ticks;
  ({int score, int best, List<int> levels})? _lastSprint;
  ({int count, bool correct, bool first})? _lastCheck;
  int _celebrations = 0;

  /// Whole seconds left in the sprint; its own notifier, so a tick rebuilds
  /// only the countdown.
  final sprintSecondsLeft = ValueNotifier<int>(0);

  Problem get current => _current;

  /// Solution steps of the current problem; the first [revealedSteps] show.
  List<String> get steps => _steps;
  int get revealedSteps => _revealed;
  bool get canRevealStep => _nextRevealed(HintEvent.reveal) > _revealed;

  /// Replaced, never mutated, so `context.select` sees every change.
  List<Attempt> get history => _progress.history;
  Set<OperationType> get selectedOperations => _progress.selectedOperations;

  /// Null until the player picks a starting tier.
  Tier? get tier => _progress.tier;
  Map<OperationType, Difficulty> get difficulty => _progress.difficulty;
  GameState get game => _progress.game;

  /// Read from the clock on every call, so a rebuild after midnight shows
  /// the new date without any event.
  int get shownStreak => displayedStreak(game, _clock());
  int get shownDailyCount => goalRingValue(game, _clock());

  /// False in no-write mode: saved data could not be read, so it is kept.
  bool get canSave => _canSave;
  String get draftInput => _draftInput;
  String? get validationMessage => _validationMessage;
  bool? get answerCorrect => _answerCorrect;
  int get currentPage => _currentPage;

  bool get inSprint => _sprintStart != null;

  /// The XP earned in the round so far.
  int get sprintScore => inSprint ? game.xp - _sprintStartXp : 0;

  /// The last finished round: its score, the best after it, and how many
  /// answers it had at each difficulty level (index 0 is level 1). Cleared
  /// by the next practice answer or round.
  ({int score, int best, List<int> levels})? get lastSprint => _lastSprint;

  bool get sound => _progress.sound;
  bool get haptics => _progress.haptics;

  /// The latest valid check; [count] tells two equal results apart, so each
  /// one plays its feedback motion.
  ({int count, bool correct, bool first})? get lastCheck => _lastCheck;

  /// How many level-ups and reached daily goals this session has seen.
  int get celebrations => _celebrations;

  void setSound(bool on) {
    _progress = _progress.withSwitches(sound: on);
    _save();
    notifyListeners();
  }

  void setHaptics(bool on) {
    _progress = _progress.withSwitches(haptics: on);
    _save();
    notifyListeners();
  }

  /// A number pad key press.
  void keyPressed() => _buzz(Haptic.key);

  void _buzz(Haptic haptic) {
    if (haptics) _haptic(haptic);
  }

  void setDraftInput(String value) {
    _draftInput = value;
    _validationMessage = null;
    _answerCorrect = null;
    notifyListeners();
  }

  bool submitAnswer() {
    if (inSprint) {
      // A check after the time ran out ends the round; that problem is not
      // recorded.
      _tick();
      if (!inSprint) return false;
    }
    final input = double.tryParse(_draftInput.trim());
    if (input == null || !input.isFinite) {
      _validationMessage = _draftInput.trim().isEmpty
          ? 'Enter a number first.'
          : 'Use a number for your answer.';
      _answerCorrect = null;
      notifyListeners();
      return false;
    }

    final firstCheck = !_checked;
    final correct = input == _current.result;
    final celebrated = _record(input);
    _lastCheck = (
      count: (_lastCheck?.count ?? 0) + 1,
      correct: correct,
      first: firstCheck,
    );
    _buzz(
      celebrated
          ? Haptic.celebrate
          : correct
          ? Haptic.correct
          : Haptic.wrong,
    );
    if (inSprint) {
      _sprintLevels[_current.level - 1]++;
      _showNext();
      notifyListeners();
      return true;
    }
    _validationMessage = null;
    _answerCorrect = correct;
    if (firstCheck && !_answerCorrect!) {
      _revealed = _nextRevealed(HintEvent.wrongFirstCheck);
    }
    notifyListeners();
    return true;
  }

  /// "Next"; there is none during a sprint.
  void generateNextProblem() {
    if (inSprint) return;
    _record(null);
    _showNext();
    notifyListeners();
  }

  /// The "Hint" and "Next step" controls.
  void revealStep() {
    if (inSprint || !canRevealStep) return;
    _revealed = _nextRevealed(HintEvent.reveal);
    notifyListeners();
  }

  /// Refuses to deselect the last selected operation. The problem on screen
  /// is kept; the selection applies from the next problem.
  void toggleOperation(OperationType type) {
    final selected = selectedOperations;
    if (!selected.contains(type)) {
      _progress = _progress.withSelectedOperations({...selected, type});
    } else if (selected.length > 1) {
      _progress = _progress.withSelectedOperations(
        selected.where((kind) => kind != type).toSet(),
      );
    } else {
      return;
    }
    _save();
    notifyListeners();
  }

  /// Sets every operation to the tier's level and shows a new problem at
  /// that level; the replaced problem is not recorded.
  void chooseTier(Tier tier) {
    endSprint();
    _progress = _progress.withTier(tier);
    _save();
    _showNext();
    notifyListeners();
  }

  void setCurrentPage(int value) {
    RangeError.checkValueInInterval(value, 0, 1, 'page');
    if (value != 0) endSprint();
    _currentPage = value;
    notifyListeners();
  }

  /// Starts a sprint round on a new problem; the replaced problem is not
  /// recorded. Needs a chosen tier.
  void startSprint() {
    if (inSprint || tier == null) return;
    _sprintStart = _clock();
    _sprintStartXp = game.xp;
    _sprintLevels = List.filled(maxLevel, 0);
    _lastSprint = null;
    _progress = _progress.withGame(sprintStarted(game));
    _save();
    _showNext();
    _ticks = _ticker().listen((_) => _tick());
    _tick();
    notifyListeners();
  }

  /// Ends the round with the score so far and draws a new problem; the
  /// problem on screen is not recorded.
  void endSprint() {
    if (!inSprint) return;
    _ticks?.cancel();
    _ticks = null;
    final score = sprintScore;
    _progress = _progress.withGame(sprintEnded(game, score));
    _lastSprint = (
      score: score,
      best: game.bestSprint,
      levels: List.unmodifiable(_sprintLevels),
    );
    _sprintStart = null;
    _save();
    _showNext();
    notifyListeners();
  }

  void _tick() {
    final start = _sprintStart;
    if (start == null) return;
    final left = sprintRemaining(start, _clock());
    sprintSecondsLeft.value = (left.inMilliseconds + 999) ~/ 1000;
    if (left == Duration.zero) endSprint();
  }

  /// Flushes saves when the app goes to the background; a resume runs the
  /// day change, and in no-write mode the first resume tries to read the
  /// saved progress once more.
  void handleLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        if (_canSave) _writer.flush();
      case AppLifecycleState.resumed:
        _progress = _withDayChange(_progress);
        notifyListeners();
        _tick();
        if (!_canSave && !_retried) {
          _retried = true;
          _retryLoad();
        }
      default:
    }
  }

  Future<void> _retryLoad() async {
    final loaded = await loadProgress(_store, clock: _clock);
    if (!loaded.canSave) return;
    endSprint();
    _progress = _withDayChange(loaded.progress);
    _canSave = true;
    // The problem on screen came from the default selection; it is not
    // recorded, as after any reload.
    _showNext();
    notifyListeners();
  }

  Progress _withDayChange(Progress progress) =>
      progress.withGame(dayChanged(progress.game, _clock()));

  void _save() {
    if (_canSave) _writer.save(_progress.encode());
  }

  /// A problem of one of the selected operations, at that operation's level.
  Problem _draw() {
    if (nextProblem case final next?) return next();
    final kinds = OperationType.values.where(selectedOperations.contains);
    final kind = kinds.elementAt(_random.nextInt(kinds.length));
    return kind.generate(_random, difficulty[kind]!.level);
  }

  void _showNext() {
    _show(_draw());
    _draftInput = '';
    _validationMessage = null;
    _answerCorrect = null;
  }

  void _show(Problem problem) {
    _current = problem;
    _steps = solutionSteps(problem);
    _shownAt = _clock();
    _checked = false;
    _revealed = 0;
  }

  int _nextRevealed(HintEvent event) => nextRevealed(
    revealed: _revealed,
    event: event,
    stepCount: _steps.length,
    checked: _checked,
  );

  /// Returns whether the attempt raised the player level or reached the
  /// daily goal.
  bool _record(num? answer) {
    final now = _clock();
    final attempt = historyEntry(
      problem: _current,
      alreadyChecked: _checked,
      answer: answer,
      hintsUsed: _revealed,
      elapsedMs: now.difference(_shownAt).inMilliseconds,
      at: now,
      sprint: inSprint,
    );
    _checked = true;
    if (attempt == null) return false;
    if (!inSprint) _lastSprint = null;
    final kind = attempt.problem.kind;
    final before = game;
    _progress = _progress
        .withAttempt(attempt)
        .withDifficulty(kind, difficultyAfter(difficulty[kind]!, attempt))
        .withGame(gameAfter(game, attempt, now));
    _save();
    // XP grows only with the answer that also counts toward the goal.
    final milestone =
        playerLevel(game.xp) > playerLevel(before.xp) ||
        (game.xp > before.xp && game.dailyCount == dailyGoal);
    if (milestone) _celebrations++;
    return milestone;
  }

  @override
  void dispose() {
    _ticks?.cancel();
    sprintSecondsLeft.dispose();
    super.dispose();
  }
}
