# Simple Math Tester

A friendly arithmetic practice app for school beginners. Practice with addition,
subtraction, multiplication and division, then review answers for the current
session. Supports web, Android and iOS.

## Local setup

Flutter and the other project tools are managed with [mise](https://mise.jdx.dev/).
The Flutter version is pinned in `mise.toml` and matches CI.

```sh
mise install
cd app
mise exec -- flutter pub get --enforce-lockfile
mise exec -- flutter run
```

Use `mise exec -- flutter devices` to list available targets. iOS builds require
macOS and Xcode. Android builds require an Android SDK and accepted licenses.

## Checks

Run all Flutter and Dart commands through `mise` from `app/`:

```sh
mise exec -- dart format --output=none --set-exit-if-changed lib test
mise exec -- flutter analyze
mise exec -- flutter test
mise exec -- flutter build web --release
mise exec -- flutter build apk --release
```

On macOS, also run:

```sh
mise exec -- flutter build ios --release --no-codesign
```

See `DESIGN.md` for the visual and accessibility contract. Session answers remain
in memory and are cleared when the app restarts.

## Modernization record

Upgraded on 2026-11-13:

- Flutter 3.13.5 to 3.50.0, with bundled Dart 3.14.0.
- `duration` 3.0.13 to 4.0.3, `provider` 6.0.5 to 6.1.5+1, and `collection`
  1.17.1 to 1.19.1.
- `flutter_lints` 2.0.3 to 6.0.0; added `material_ui` 1.11.0 for Flutter's
  standalone Material package migration.
- Removed unused `cupertino_icons` and `flutter_otp_text_field`; neither had
  references in `app/lib` or `app/test`.
- `material_color_utilities` 0.13.0 and `test_api` 0.7.14 remain constrained by
  the Flutter SDK. Versions 0.13.1 and 0.7.15 are not resolvable without
  dependency overrides, which this project intentionally does not use.

## Platform verification limits

Linux cannot build iOS. Use the macOS CI job or a local macOS Xcode toolchain for
the unsigned iOS build. Android and iOS keyboard, safe-area, navigation and
background/resume behavior also require emulator, simulator or device smoke
tests. Browser emulation is not native execution evidence. CI job definitions
alone do not prove those checks passed.
