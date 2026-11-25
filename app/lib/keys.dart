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
// The hint: the page's Hint (or Show a hint) and Try again buttons; the
// modal ([solutionStepsKey]) with its Next step or Show the answer button
// and its Close button.
const hintButtonKey = Key('hint-button');
const tryAgainButtonKey = Key('try-again-button');
const revealStepButtonKey = Key('reveal-step-button');
const hintCloseKey = Key('hint-close');
// The nudge to try first, before the hint, with its two buttons.
const hintNudgeKey = Key('hint-nudge');
const hintNudgeTryKey = Key('hint-nudge-try');
const hintNudgeAnywayKey = Key('hint-nudge-anyway');
// Start and End of practice, and the summary End shows.
const startPracticeButtonKey = Key('start-practice-button');
const endPracticeButtonKey = Key('end-practice-button');
const roundSummaryKey = Key('round-summary');
const roundSummaryDoneKey = Key('round-summary-done');
const roundSummaryAnswersKey = Key('round-summary-answers');
const summaryAnsweredKey = Key('summary-answered');
const summaryCorrectKey = Key('summary-correct');
const summaryXpKey = Key('summary-xp');
const summaryComboKey = Key('summary-combo');
const summaryHintsKey = Key('summary-hints');
const summarySkippedKey = Key('summary-skipped');
const summaryTimeKey = Key('summary-time');
const summaryLevelKey = Key('summary-level');

/// One per kind in the summary: its answered and right.
Key summaryKindKey(Enum kind) => Key('summary-kind-${kind.name}');
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
const soundVolumeHintKey = Key('sound-volume-hint');
const openVolumeSettingsKey = Key('open-volume-settings');
const hapticsSwitchKey = Key('haptics-switch');
const touchFeedbackHintKey = Key('touch-feedback-hint');
const openVibrationSettingsKey = Key('open-vibration-settings');
const privacyTileKey = Key('privacy-tile');
const licencesTileKey = Key('licences-tile');
const impressumTileKey = Key('impressum-tile');
const reportProblemTileKey = Key('report-problem-tile');
const sendProblemReportTileKey = Key('send-problem-report-tile');

// Marking a question and the report dialog.
const reportFlagKey = Key('report-flag');

/// The flag on a history entry, by its index in the history.
Key historyFlagKey(int index) => Key('history-flag-$index');
const reportDialogKey = Key('report-dialog');
const reportContinueKey = Key('report-continue');
const reportRemoveMarkKey = Key('report-remove-mark');
const reportNotNowKey = Key('report-not-now');
const reportCancelKey = Key('report-cancel');
const reportCloseKey = Key('report-close');
const reportBackKey = Key('report-back');

/// One per reason or category, by its contract name.
Key reportOptionKey(String name) => Key('report-option-$name');
const reportCheckWordKey = Key('report-check-word');
const reportCheckFieldKey = Key('report-check-field');
const reportCheckWrongKey = Key('report-check-wrong');
const reportSendKey = Key('report-send');
const reportResultKey = Key('report-result');
const reportTryAgainKey = Key('report-try-again');
const reportWaitKey = Key('report-wait');
const appVersionTileKey = Key('app-version-tile');
const updateReminderKey = Key('update-reminder');
const updateReminderDismissKey = Key('update-reminder-dismiss');
const newKindCardKey = Key('new-kind-card');
const newKindDismissKey = Key('new-kind-dismiss');
const privacyPageKey = Key('privacy-page');
const licencesPageKey = Key('licences-page');

/// One per segment of the settings sheet's theme choice.
Key themeModeKey(Enum mode) => Key('theme-mode-${mode.name}');

/// One per segment of the settings sheet's layout choice.
Key layoutModeKey(Enum mode) => Key('layout-mode-${mode.name}');
Key numbersModeKey({required bool native}) =>
    Key(native ? 'numbers-native' : 'numbers-ascii');

/// The settings row that opens the language choice, and one key per choice
/// (a language code such as `de`; null is "System").
const languageTileKey = Key('language-tile');
Key languageOptionKey(String? code) =>
    Key('language-option-${code ?? 'system'}');

/// One per swatch of the settings sheet's colour choice.
Key paletteKey(Enum palette) => Key('palette-${palette.name}');
const pinnedQuestionKey = Key('pinned-question');
const practiceNavKey = Key('practice-nav');
const myAnswersNavKey = Key('my-answers-nav');
const padDeleteKey = Key('pad-delete');
const padMinusKey = Key('pad-minus');
const padDecimalKey = Key('pad-decimal');
Key padDigitKey(String digit) => Key('pad-digit-$digit');
Key operationToggleKey(Enum type) => Key('operation-toggle-${type.name}');
const solutionStepsKey = Key('solution-steps');
const hintFigureKey = Key('hint-figure');

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

/// The hint totals on the stats card: all answers, then each kind's.
const hintStatsKey = Key('hint-stats');
Key hintStatsKindKey(Enum type) => Key('hint-stats-${type.name}');
const answersLoadingKey = Key('answers-loading');
const answersEndKey = Key('answers-end');
