import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'home_page.dart';
import 'keys.dart';
import 'math_tester_model.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => MathTesterModel())],
      child: const MathTesterApp(),
    ),
  );
}

class MathTesterApp extends StatelessWidget {
  const MathTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scrollBehavior: CustomScrollBehavior(),
      key: materialAppKey,
      title: 'Math Tester',
      theme: buildAppTheme(),
      home: const MyHomePage(key: homePageKey),
    );
  }
}

class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}
