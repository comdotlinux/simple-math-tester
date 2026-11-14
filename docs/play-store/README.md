# Play Store listing graphics

- `icon-512.png`: 512 x 512, 32-bit PNG, full bleed (Play applies its own mask).
- `feature-graphic-1024x500.png`: 1024 x 500, no alpha.
- `phone-1-practice.png` to `phone-6-dark.png`: phone screenshots, 1080 x 1920 (9:16), 24-bit PNG without alpha.
  Made with `SCREENSHOT_DIR=<dir> SCREENSHOT_PIXEL_RATIO=3 flutter test tool/screenshots_test.dart --plain-name 360x640`
  (in `app/`), then `magick <shot>.png -background white -alpha remove -alpha off PNG24:<name>.png`.

Both files are generated from the SVG sources in `app/assets/branding/`:
`python3 app/assets/branding/render.py` (needs `rsvg-convert` and `magick`).
It also rewrites the Android, iOS, macOS, web and Windows icons in place.
