import 'package:integration_test/integration_test.dart';

import 'journeys/game_loop_journeys.dart';
import 'journeys/hints_journeys.dart';
import 'journeys/history_journeys.dart';
import 'journeys/number_pad_journeys.dart';
import 'journeys/operations_journeys.dart';
import 'journeys/persistence_journeys.dart';
import 'journeys/practice_journeys.dart';
import 'journeys/settings_journeys.dart';
import 'journeys/sprint_journeys.dart';
import 'journeys/tier_picker_journeys.dart';

/// The one entry point: each device builds the app once and runs every
/// feature's journeys. See README.md in this folder.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tierPickerJourneys();
  practiceJourneys();
  numberPadJourneys();
  hintsJourneys();
  operationsJourneys();
  historyJourneys();
  gameLoopJourneys();
  sprintJourneys();
  settingsJourneys();
  persistenceJourneys();
}
