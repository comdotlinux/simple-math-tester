import 'package:flutter/foundation.dart';

import 'rules.dart';

const materialAppKey = Key('material-app');
const homePageKey = Key('home-page');
const problemsPageKey = Key('problems-page');
const resultsPageKey = Key('results-page');
const noResultsOnResultsPageKey = Key('no-results-on-results-page');
const questionOnProblemsPageKey = Key('question-on-problems-page');
const checkAnswerButtonKey = Key('check-answer-button');
const nextQuestionButtonKey = Key('next-question-button');
const revealStepButtonKey = Key('reveal-step-button');
const settingsButtonKey = Key('settings-button');
const settingsSheetKey = Key('settings-sheet');
const currentTierNoteKey = Key('current-tier-note');
const tierPickerKey = Key('tier-picker');

/// One per tier: the tier picker's button and the settings sheet's row.
Key tierOptionKey(Tier tier) => Key('tier-option-${tier.name}');
Key tierSettingKey(Tier tier) => Key('tier-setting-${tier.name}');
const hudKey = Key('hud');
const sprintButtonKey = Key('sprint-button');
const sprintCountdownKey = Key('sprint-countdown');
const sprintResultKey = Key('sprint-result');
const numberPadKey = Key('number-pad');
const keyboardSwitchKey = Key('keyboard-switch');
const soundSwitchKey = Key('sound-switch');
const hapticsSwitchKey = Key('haptics-switch');
const privacyTileKey = Key('privacy-tile');
const impressumTileKey = Key('impressum-tile');
const privacyPageKey = Key('privacy-page');

/// One per segment of the settings sheet's theme choice.
Key themeModeKey(Enum mode) => Key('theme-mode-${mode.name}');

/// One per segment of the settings sheet's layout choice.
Key layoutModeKey(Enum mode) => Key('layout-mode-${mode.name}');
const pinnedQuestionKey = Key('pinned-question');
const practiceNavKey = Key('practice-nav');
const myAnswersNavKey = Key('my-answers-nav');
const padDeleteKey = Key('pad-delete');
Key padDigitKey(String digit) => Key('pad-digit-$digit');
Key operationToggleKey(Enum type) => Key('operation-toggle-${type.name}');
const solutionStepsKey = Key('solution-steps');

// Header values.
const hudStreakKey = Key('hud-streak');
const hudGoalKey = Key('hud-goal');
const hudComboKey = Key('hud-combo');
const hudXpKey = Key('hud-xp');
const cantSaveNoticeKey = Key('cant-save-notice');

// Sprint bar and result.
const sprintScoreKey = Key('sprint-score');
const sprintResultScoreKey = Key('sprint-result-score');
const sprintResultBestKey = Key('sprint-result-best');

// My answers.
const emptyStatePracticeButtonKey = Key('empty-state-practice-button');
const historyCountKey = Key('history-count');

/// One per answer, by its index in the history.
Key historyRowKey(int index) => Key('history-row-$index');
const statsCardKey = Key('stats-card');
const dailyStreakStatKey = Key('stat-daily-streak');
const bestStreakStatKey = Key('stat-best-streak');
const bestSprintStatKey = Key('stat-best-sprint');
const totalXpStatKey = Key('stat-total-xp');
const playerLevelStatKey = Key('stat-player-level');
const compactStatsKey = Key('compact-stats');
const answersLoadingKey = Key('answers-loading');
const answersEndKey = Key('answers-end');
