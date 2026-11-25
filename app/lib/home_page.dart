import 'package:material_ui/material_ui.dart' hide Text;
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'celebration.dart';
import 'digit_text.dart';
import 'hud.dart';
import 'keys.dart';
import 'l10n/app_localizations.dart';
import 'math_tester_model.dart';
import 'problem_page.dart';
import 'results_page.dart';

/// The page column beside the navigation rail, while the rail shows.
final contentAreaKey = GlobalKey();

/// Keeps a sheet or dialog over the page column instead of the whole window,
/// so on a wide screen it lines up with the page beside the navigation rail
/// (issue #237). Without the rail (phones, practice) it changes nothing; the
/// strip it leaves free still belongs to the dimmed area, so a tap there
/// closes the sheet or dialog.
class ContentArea extends StatelessWidget {
  const ContentArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // shortcut: reads the column's last layout, so a resize while open may
    // lag one frame; measure in a layout pass if that ever shows.
    final box = contentAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return child;
    final left = box.localToGlobal(Offset.zero).dx;
    final right = MediaQuery.sizeOf(context).width - left - box.size.width;
    // The column already sits inside the safe area at its sides.
    return Padding(
      padding: EdgeInsets.only(left: left, right: right),
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: true,
        removeRight: true,
        child: child,
      ),
    );
  }
}

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
        // While practising the page keeps only the question and the header;
        // My answers is one tap away after End.
        final navigation = !model.practising;
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: compact || !navigation
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
                          key: contentAreaKey,
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
          bottomNavigationBar: compact && navigation
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

/// A monthly row under the header suggesting a look at the app store. It never
/// checks anything itself: the reminder sends nothing, it only opens the
/// store.
class _UpdateReminder extends StatelessWidget {
  const _UpdateReminder();

  @override
  Widget build(BuildContext context) {
    final show = context.select(
      (MathTesterModel m) =>
          m.showUpdateReminder && !m.inSprint && !m.practising,
    );
    if (!show) return const SizedBox.shrink();
    final model = context.read<MathTesterModel>();
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    return Material(
      key: updateReminderKey,
      color: tokens.surfaceRaised,
      shape: Border(
        bottom: BorderSide(
          color: tokens.outline,
          width: AppTokens.outlineWidth,
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
