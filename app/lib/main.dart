import 'dart:math';

import 'package:flutter/material.dart';
import 'package:simple_math_tester/operations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Math Test',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.lightBlue,
      ),
      home: const MathTester(title: 'Math Tester'),
    );
  }
}

class MathTester extends StatefulWidget {
  const MathTester({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MathTester> createState() => _MathTesterState();
}

class _MathTesterState extends State<MathTester> {
  List<Operator> operators = [Addition(), Subtraction(), Multiplication()];
  final random = Random();
  List<Operation> operations = [Addition().create()];
  var userInputController = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    userInputController.dispose();
    super.dispose();
  }

  void _nextOperation() {
    // This call to setState tells the Flutter framework that something has
    // changed in this State, which causes it to rerun the build method below
    // so that the display can reflect the updated values. If we changed
    // _counter without calling setState(), then the build method would not be
    // called again, and so nothing would appear to happen.
    setState(() {
      try {
        operations.last.input = double.parse(userInputController.text);
      } catch (e) {
        // TODO: show error that input has to be an integer
        operations.last.input = 0;
      }
      userInputController.dispose();
      userInputController = TextEditingController();
      operations.add(operators[random.nextInt(operators.length)].create());
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: buildRow(operations),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nextOperation,
        tooltip: 'Next Operation',
        child: const Icon(Icons.navigate_next_rounded),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  List<Row> buildRow(List<Operation> operations) {
    const fontSize = TextStyle(fontSize: 20);
    return operations
        .map(
          (row) => Row(
            children: <Widget>[
              Visibility(
                visible: !row.inputEntered(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(style: fontSize, row.left),
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 10, right: 10),
                      child: Text(style: fontSize, row.operationType.displayString),
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 10, right: 10),
                      child: Text(style: fontSize, row.right),
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 10, right: 10),
                      // ignore: prefer_const_constructors
                      child: Text(style: fontSize, '='),
                    ),
                  ],
                ),
              ),
              Visibility(
                visible: row.inputEntered(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                        style: TextStyle(
                          color: row.inputCorrect() ? Colors.green : Colors.red,
                          fontSize: 30,
                        ),
                        row.toString()),
                    Icon(
                      size: 100,
                      row.inputCorrect() ? Icons.sentiment_satisfied : Icons.sentiment_dissatisfied,
                      color: row.inputCorrect() ? Colors.green : Colors.red,
                    ),
                  ],
                ),
              ),
              Visibility(
                visible: !row.inputEntered(),
                child: Flexible(
                  fit: FlexFit.tight,
                  child: TextField(
                    controller: userInputController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Please Enter Your Answer',
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
        .toList();
  }
}
