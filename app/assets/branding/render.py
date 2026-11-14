#!/usr/bin/env python3
"""Renders every icon and store graphic from foreground/background/monochrome.svg.

Needs rsvg-convert and ImageMagick (magick). Run from anywhere:
    python3 app/assets/branding/render.py
Outputs overwrite the files in place, so a second run changes nothing.
"""
import json
import re
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
APP = HERE.parents[1]
ROOT = APP.parent
FG = (HERE / "foreground.svg").read_text()
# the tiles group without the safe-zone scale wrapped around it in foreground.svg
tiles_inner = FG[FG.index('<g id="tiles"'):FG.rindex("</g>")].rstrip() + "\n"
tile_list = re.findall(r'<g transform="translate\([^)]*\)">.*?\n    </g>', tiles_inner, re.S)
assert len(tile_list) == 4
BG = '<rect width="108" height="108" fill="#FFC83A"/>'
OPEN = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">'


def scaled(s):
    return f'<g transform="translate(54 54) scale({s}) translate(-54 -54)">{tiles_inner}</g>'


def write(name, text):
    (HERE / name).write_text(text)


# Full bleed (iOS, store), maskable (web), rounded (legacy Android, web, Windows).
write("icon.svg", f"{OPEN}{BG}{scaled(1.3)}</svg>\n")
# maskable: all content inside the 40% radius safe circle
write("icon-maskable.svg", f"{OPEN}{BG}{scaled(1.0)}</svg>\n")
write(
    "icon-rounded.svg",
    f'{OPEN}<clipPath id="r"><rect width="108" height="108" rx="24"/></clipPath>'
    f'<g clip-path="url(#r)">{BG}{scaled(1.3)}</g></svg>\n',
)
# macOS draws no mask: icon body is 824/1024 of the canvas with transparent margin.
write(
    "icon-macos.svg",
    f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
    f'<g transform="translate(100 100) scale({824 / 108})">'
    f'<clipPath id="r"><rect width="108" height="108" rx="24"/></clipPath>'
    f'<g clip-path="url(#r)">{BG}{scaled(1.3)}</g></g></svg>\n',
)
# Feature graphic: the four blocks in one row on the yellow page.
s, gap = 6.2, 40
w = 27 * s
x0 = (1024 - (4 * w + 3 * gap)) / 2
y0 = (500 - (27 + 3) * s) / 2
row = ""
for i, t in enumerate(tile_list):
    inner = t[t.index(">") + 1:t.rindex("</g>")]
    row += f'<g transform="translate({x0 + i * (w + gap):.1f} {y0:.1f}) scale({s})">{inner}</g>'
write(
    "feature-graphic.svg",
    f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 500">'
    f'<rect width="1024" height="500" fill="#FFC83A"/>{row}</svg>\n',
)


def png(svg, out, size, w=None, h=None):
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["rsvg-convert", "-w", str(w or size), "-h", str(h or size), str(HERE / svg), "-o", str(out)],
        check=True,
    )


def flat(path):
    # drop the alpha channel entirely (App Store rejects icons with alpha)
    subprocess.run(["magick", str(path), "-background", "#FFC83A", "-alpha", "remove",
                    "-alpha", "off", "PNG24:" + str(path)], check=True)


# Android
res = APP / "android/app/src/main/res"
for d, legacy, layer in [("mdpi", 48, 108), ("hdpi", 72, 162), ("xhdpi", 96, 216),
                         ("xxhdpi", 144, 324), ("xxxhdpi", 192, 432)]:
    png("icon-rounded.svg", res / f"mipmap-{d}/ic_launcher.png", legacy)
    png("foreground.svg", res / f"mipmap-{d}/ic_launcher_foreground.png", layer)
    png("monochrome.svg", res / f"mipmap-{d}/ic_launcher_monochrome.png", layer)

# iOS: sizes come from Contents.json
ios = APP / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for img in json.loads((ios / "Contents.json").read_text())["images"]:
    pts = float(img["size"].split("x")[0])
    px = round(pts * int(img["scale"].rstrip("x")))
    png("icon.svg", ios / img["filename"], px)
    flat(ios / img["filename"])

# macOS
mac = APP / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
for n in (16, 32, 64, 128, 256, 512, 1024):
    png("icon-macos.svg", mac / f"app_icon_{n}.png", n)

# Web
web = APP / "web"
png("icon-rounded.svg", web / "favicon.png", 32)
png("icon-rounded.svg", web / "icons/Icon-192.png", 192)
png("icon-rounded.svg", web / "icons/Icon-512.png", 512)
png("icon-maskable.svg", web / "icons/Icon-maskable-192.png", 192)
png("icon-maskable.svg", web / "icons/Icon-maskable-512.png", 512)

# Windows .ico: 256 PNG plus small sizes
tmp = Path(tempfile.mkdtemp())
sizes = (256, 48, 32, 16)
for n in sizes:
    png("icon-rounded.svg", tmp / f"{n}.png", n)
subprocess.run(["magick", *[str(tmp / f"{n}.png") for n in sizes],
                str(APP / "windows/runner/resources/app_icon.ico")], check=True)

# Play Store listing graphics (the store masks the icon itself: full bleed, 32-bit PNG)
play = ROOT / "docs/play-store"
png("icon.svg", play / "icon-512.png", 512)
subprocess.run(["magick", str(play / "icon-512.png"), "PNG32:" + str(play / "icon-512.png")], check=True)
png("feature-graphic.svg", play / "feature-graphic-1024x500.png", 0, w=1024, h=500)
subprocess.run(["magick", str(play / "feature-graphic-1024x500.png"), "-alpha", "off",
                "PNG24:" + str(play / "feature-graphic-1024x500.png")], check=True)
print("done")
