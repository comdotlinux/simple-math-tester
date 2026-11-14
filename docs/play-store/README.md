# Play Store listing graphics

- `icon-512.png`: 512 x 512, 32-bit PNG, full bleed (Play applies its own mask).
- `feature-graphic-1024x500.png`: 1024 x 500, no alpha.
- `phone-1-practice.png` to `phone-7-compact.png`: phone screenshots of a 450 x 800 dp phone, 1080 x 1920 (9:16), 24-bit PNG without alpha.
  Made with `SCREENSHOT_DIR=<dir> SCREENSHOT_SIZE=450x800 SCREENSHOT_PIXEL_RATIO=2.4 flutter test tool/screenshots_test.dart`
  (in `app/`), then `magick <shot>.png -background white -alpha remove -alpha off PNG24:<name>.png`.

Both files are generated from the SVG sources in `app/assets/branding/`:
`python3 app/assets/branding/render.py` (needs `rsvg-convert` and `magick`).
It also rewrites the Android, iOS, macOS, web and Windows icons in place.
