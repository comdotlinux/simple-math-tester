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
const pinnedQuestionKey = Key('pinned-question');
