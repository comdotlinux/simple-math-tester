import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/operations.dart';

import 'home_page.dart';

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
      title: 'Math Tester',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const MyHomePage(),
    );
  }
}

class MathTesterModel extends ChangeNotifier {

  List<Operator> operators = [Addition(), Subtraction(), Multiplication(), Division()];
  final random = Random();

  var completedProblems = <Operation>{};

  Operation current = Addition().create();

  double? _input;

  int _currentPage = 0;

  void generateNextProblem() {
    completedProblems.add(current);
    current = operators[random.nextInt(operators.length)].create();
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
