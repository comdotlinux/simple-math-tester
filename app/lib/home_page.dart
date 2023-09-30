import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/problem_page.dart';
import 'package:simple_math_tester/results_page.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final modelProvider = context.watch<MathTesterModel>();
    Widget page;
    switch (modelProvider.currentPage) {
      case 0:
        page = const ProblemPage();
        break;
      case 1:
        page = const ResultsPage();
        break;
      // case 2:
      //   page = const StaticOpenLibrarySearchWidget();
      //   break;
      default:
        throw UnimplementedError('no widget for ${modelProvider.currentPage}');
    }
    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                  extended: constraints.maxWidth > 600,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.question_mark),
                      label: Text('Questions'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.question_answer_rounded),
                      label: Text('Answers'),
                    ),
                  ],
                  selectedIndex: modelProvider.currentPage,
                  onDestinationSelected: (value) {
                    // debugPrint('Selected Index Changed to $value');
                    modelProvider.setCurrentPage(value);
                  }),
            ),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: page,
              ),
            ),
          ],
        ),
      );
    });
  }
}
