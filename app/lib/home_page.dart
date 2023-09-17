import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:simple_math_tester/problem_page.dart';
import 'package:simple_math_tester/results_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedWidget = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedWidget) {
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
        throw UnimplementedError('no widget for $selectedWidget');
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
                  selectedIndex: selectedWidget,
                  onDestinationSelected: (value) {
                    debugPrint('Selected Index Changed to $value');
                    setState(() {
                      selectedWidget = value;
                    });
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