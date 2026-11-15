import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'celebration.dart';
import 'hud.dart';
import 'keys.dart';
import 'l10n/app_localizations.dart';
import 'math_tester_model.dart';
import 'problem_page.dart';
import 'results_page.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MathTesterModel>();
    final l = AppLocalizations.of(context);
    final page = model.currentPage == 0
        // The Android back gesture ends a sprint instead of leaving the app.
        ? PopScope(
            canPop: !model.inSprint,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) model.endSprint();
            },
            child: Celebration(
              count: model.celebrations,
              child: const ProblemPage(key: problemsPageKey),
            ),
          )
        : const ResultsPage(key: resultsPageKey);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 800 ||
            MediaQuery.textScalerOf(context).scale(1) > 1;
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Hud(),
                      const _UpdateReminder(),
                      Expanded(child: page),
                    ],
                  )
                : Row(
                    children: [
                      NavigationRail(
                        extended: constraints.maxWidth >= 1000,
                        labelType: constraints.maxWidth >= 1000
                            ? null
                            : NavigationRailLabelType.all,
                        destinations: [
                          NavigationRailDestination(
                            icon: const Icon(Icons.calculate_outlined),
                            selectedIcon: const Icon(Icons.calculate),
                            label: Text(l.practice, key: practiceNavKey),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.checklist_outlined),
                            selectedIcon: const Icon(Icons.checklist),
                            label: Text(l.myAnswers, key: myAnswersNavKey),
                          ),
                        ],
                        selectedIndex: model.currentPage,
                        onDestinationSelected: model.setCurrentPage,
                      ),
                      const VerticalDivider(
                        width: AppTokens.outlineWidth,
                        thickness: AppTokens.outlineWidth,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Hud(),
                            const _UpdateReminder(),
                            Expanded(child: page),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          bottomNavigationBar: compact
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: context.tokens.outline,
                        width: AppTokens.outlineWidth,
                      ),
                    ),
                  ),
                  child: NavigationBar(
                    destinations: [
                      NavigationDestination(
                        key: practiceNavKey,
                        icon: const Icon(Icons.calculate_outlined),
                        selectedIcon: const Icon(Icons.calculate),
                        label: l.practice,
                      ),
                      NavigationDestination(
                        key: myAnswersNavKey,
                        icon: const Icon(Icons.checklist_outlined),
                        selectedIcon: const Icon(Icons.checklist),
                        label: l.myAnswers,
                      ),
                    ],
                    selectedIndex: model.currentPage,
                    onDestinationSelected: model.setCurrentPage,
                  ),
                )
              : null,
        );
      },
    );
  }
}

/// A monthly row under the header suggesting a look at Google Play. It never
/// checks anything itself: the app sends nothing, it only opens the store.
class _UpdateReminder extends StatelessWidget {
  const _UpdateReminder();

  @override
  Widget build(BuildContext context) {
    final show = context.select(
      (MathTesterModel m) => m.showUpdateReminder && !m.inSprint,
    );
    if (!show) return const SizedBox.shrink();
    final model = context.read<MathTesterModel>();
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    return DecoratedBox(
      key: updateReminderKey,
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        border: Border(
          bottom: BorderSide(
            color: tokens.outline,
            width: AppTokens.outlineWidth,
          ),
        ),
      ),
      child: ListTile(
        leading: const Icon(Icons.system_update_outlined),
        title: Text(l.updateReminderTitle),
        subtitle: Text(l.updateReminderSubtitle),
        trailing: IconButton(
          key: updateReminderDismissKey,
          icon: const Icon(Icons.close),
          tooltip: l.updateReminderDismiss,
          onPressed: () {
            final messenger = ScaffoldMessenger.of(context);
            model.dismissUpdateReminder();
            messenger.showSnackBar(
              SnackBar(content: Text(l.updateReminderLater)),
            );
          },
        ),
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          if (!await model.openStore()) {
            messenger.showSnackBar(
              SnackBar(content: Text(l.browserDidNotOpen)),
            );
          }
        },
      ),
    );
  }
}
