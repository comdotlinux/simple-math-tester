import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/operations.dart';

import 'home_page.dart';
import 'keys.dart';

void main() {
  runApp(MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => MathTesterModel())],
    child: const MathTesterApp(),
  ));
}

class MathTesterApp extends StatelessWidget {
  const MathTesterApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(final BuildContext context) {
    return MaterialApp(
      key: materialAppKey,
      title: 'Math Tester',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const MyHomePage(key: homePageKey),
    );
  }
}

class MathTesterModel extends ChangeNotifier {
  Map<OperationType, Operator> operators = {
    OperationType.plus: Addition(),
    OperationType.minus: Subtraction(),
    OperationType.multiply: Multiplication(),
    OperationType.divide: Division()
  };
  final _random = Random();

  OperationType _nextRandomOperation() => OperationType.of(_random.nextInt(operators.length));

  var completedProblems = <Operation>{};

  Operation current = Addition().create();

  double? _input;

  int _currentPage = 0;

  void generateNextProblem() {
    completedProblems.add(current);
    current = operators[_nextRandomOperation()]!.create();
    notifyListeners();
  }

  void checkInput() {
    current.input = _input;
    notifyListeners();
  }

  void setInput(double? userInput) {
    _input = userInput;
    notifyListeners();
  }

  int get currentPage => _currentPage;

  void setCurrentPage(int value) {
    _currentPage = value;
    notifyListeners();
  }
}
