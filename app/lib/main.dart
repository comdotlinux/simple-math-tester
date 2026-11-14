import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'home_page.dart';
import 'keys.dart';
import 'math_tester_model.dart';
import 'progress_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap(SharedPreferencesStore());
}

/// Loads saved progress (and backs up unreadable progress) before the model
/// exists, so no save can run before the read has finished.
Future<void> bootstrap(ProgressStore store) async {
  final loaded = await loadProgress(store);
  runApp(
    MultiProvider(
      // A new key per load, so a second bootstrap builds a new model.
      key: ObjectKey(loaded.progress),
      providers: [
        ChangeNotifierProvider(
          create: (_) => MathTesterModel(
            store: store,
            progress: loaded.progress,
            canSave: loaded.canSave,
          ),
        ),
      ],
      child: const MathTesterApp(),
    ),
  );
}

class MathTesterApp extends StatefulWidget {
  const MathTesterApp({super.key});

  @override
  State<MathTesterApp> createState() => _MathTesterAppState();
}

class _MathTesterAppState extends State<MathTesterApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: context.read<MathTesterModel>().handleLifecycle,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scrollBehavior: CustomScrollBehavior(),
      key: materialAppKey,
      title: 'Math Tester',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
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
