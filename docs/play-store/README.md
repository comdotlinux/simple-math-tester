# Play Store listing graphics

- `icon-512.png`: 512 x 512, 32-bit PNG, full bleed (Play applies its own mask).
- `feature-graphic-1024x500.png`: 1024 x 500, no alpha.
- `phone-1-practice.png` to `phone-8-algebra.png`: phone screenshots of a 450 x 800 dp phone, 1080 x 1920 (9:16), 24-bit PNG without alpha.
  Made with `SCREENSHOT_DIR=<dir> SCREENSHOT_SIZE=450x800 SCREENSHOT_PIXEL_RATIO=2.4 flutter test tool/screenshots_test.dart`
  (in `app/`), then `magick <shot>.png -background white -alpha remove -alpha off PNG24:<name>.png`.

Both files are generated from the SVG sources in `app/assets/branding/`:
`python3 app/assets/branding/render.py` (needs `rsvg-convert` and `magick`).
It also rewrites the Android, iOS, macOS, web and Windows icons in place.

## Phone screenshots in every language

The **Play store listing** workflow (`.github/workflows/play-listing.yml`) shoots the eight phone screenshots in
English and every app language, and replaces the phone screenshots of each listing in `play/listing/` with them, in the
same edit as the texts. Run it with `screenshots` unticked to push the texts only. The icon and feature graphic are not
touched. The English files here are kept for reference; they are not uploaded from this folder.

A run from a branch (`gh workflow run play-listing.yml --ref <branch>`) only shoots: its `phone-screenshots` artifact
holds one folder per Play language for review, and nothing is sent to Play.

The tool writes many shots; these eight are the Play ones (Play shows at most eight):

| Play file | Tool shot |
| --- | --- |
| `phone-1-practice.png` | `light-450x800-0-before-start.png` (the start screen: kinds, Start, sprint) |
| `phone-2-correct.png` | `light-450x800-2b-celebration.png` |
| `phone-3-hints.png` | `light-450x800-3b-wrong-hints.png` (the hint modal with its steps) |
| `phone-4-sprint.png` | `light-450x800-5-sprint.png` |
| `phone-5-my-answers.png` | `light-450x800-17c-answers-top.png` (My answers with the Hints card) |
| `phone-6-dark.png` | `dark-450x800-16-geometry-pythagorasHypotenuse-8x15-x1.0.png` (a theorem figure, dark theme) |
| `phone-7-summary.png` | `light-450x800-2e-round-summary.png` (the summary at End) |
| `phone-8-algebra.png` | `light-450x800-13g-algebra-level-4-hints.png` (algebra with its hint steps) |

With `SCREENSHOT_LANGUAGES=de,hi` each name starts with the code, for example `de-light-450x800-0-before-start.png`.

To add a language: add its code to `languages` in `tool/translate.mjs` and its Play code to `playCodes` in
`tool/translate_listing.mjs` (and a Noto Sans font in `app/pubspec.yaml` if it uses a new script). Run **Translate new
and changed strings**, merge its pull request, then run **Play store listing** from `main`.
