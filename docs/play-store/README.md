# Play Store listing graphics

- `icon-512.png`: 512 x 512, 32-bit PNG, full bleed (Play applies its own mask).
- `feature-graphic-1024x500.png`: 1024 x 500, no alpha.
- Phone screenshots (at least 2) are not here yet; capture them from the redesigned app.

Both files are generated from the SVG sources in `app/assets/branding/`:
`python3 app/assets/branding/render.py` (needs `rsvg-convert` and `magick`).
It also rewrites the Android, iOS, macOS, web and Windows icons in place.
