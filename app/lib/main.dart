import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'home_page.dart';
import 'keys.dart';
import 'l10n/app_localizations.dart';
import 'labels.dart';
import 'legal.dart';
import 'math_tester_model.dart';
import 'progress_store.dart';
import 'sound_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap(SharedPreferencesStore(), AudioplayersSoundPlayer());
}

/// Loads saved progress (and backs up unreadable progress) before the model
/// exists, so no save can run before the read has finished. Silent unless a
/// player is given, so tests need no audio sink.
Future<void> bootstrap(
  ProgressStore store, [
  SoundPlayer sounds = const SilentSoundPlayer(),
  Future<bool> Function(Uri)? openLink,
]) async {
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
            haptic: playHaptic,
            sounds: sounds,
            openLink: openLink,
            updateReminders: updateRemindersSupported,
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

class _MathTesterAppState extends State<MathTesterApp>
    with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = AppLifecycleListener(
      onStateChange: context.read<MathTesterModel>().handleLifecycle,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycle.dispose();
    super.dispose();
  }

  // The system language, for the theme's font, follows the device.
  @override
  void didChangeLocales(List<Locale>? locales) => setState(() {});

  @override
  Widget build(BuildContext context) {
    final palette = context.select((MathTesterModel m) => m.palette);
    final language = context.select((MathTesterModel m) => m.language);
    // Urdu gets its Nastaliq font and tall lines also as the system language.
    final themeLanguage =
        language ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return MaterialApp(
      scrollBehavior: CustomScrollBehavior(),
      key: materialAppKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      // material_ui's own delegates: flutter_localizations' Material ones
      // serve package:flutter/material.dart, not this app's widgets.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      // English first, so an unsupported system language falls back to it.
      supportedLocales: AppLocalizations.supportedLocales,
      locale: switch (language) {
        final code? => appLocale(code),
        null => null,
      },
      theme: buildAppTheme(Brightness.light, palette, themeLanguage),
      darkTheme: buildAppTheme(Brightness.dark, palette, themeLanguage),
      themeMode: context.select((MathTesterModel m) => m.themeMode),
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
