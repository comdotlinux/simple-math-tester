import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'celebration.dart';
import 'hud.dart';
import 'keys.dart';
import 'math_tester_model.dart';
import 'problem_page.dart';
import 'results_page.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MathTesterModel>();
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
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.calculate_outlined),
                            selectedIcon: Icon(Icons.calculate),
                            label: Text('Practice', key: practiceNavKey),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.checklist_outlined),
                            selectedIcon: Icon(Icons.checklist),
                            label: Text('My answers', key: myAnswersNavKey),
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
                    destinations: const [
                      NavigationDestination(
                        key: practiceNavKey,
                        icon: Icon(Icons.calculate_outlined),
                        selectedIcon: Icon(Icons.calculate),
                        label: 'Practice',
                      ),
                      NavigationDestination(
                        key: myAnswersNavKey,
                        icon: Icon(Icons.checklist_outlined),
                        selectedIcon: Icon(Icons.checklist),
                        label: 'My answers',
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
