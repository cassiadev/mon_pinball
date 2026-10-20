"""Validate the platform icon contracts. Requires Pillow; does not modify files."""
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
checked = set()

# Independent reference: the exact user upload, with a centered square canvas.
with Image.open(ROOT / "assets/app_icon/source.png") as supplied:
    assert supplied.size == (1254, 1254)
    reference = supplied.convert("RGB").crop((17, 0, 1236, 1219))
core_radius = 0.54


def approved_artwork(icon, artwork_fraction=1):
    """Compare the rendered interior with the upload, including garden details."""
    size = icon.width
    side = size * artwork_fraction
    start = (size - side) / 2
    filtered = reference.resize((round(side), round(side)), Image.Resampling.LANCZOS)
    expected = filtered.transform(
        (size, size), Image.Transform.EXTENT,
        (-start / side * filtered.width, -start / side * filtered.height,
         (size - start) / side * filtered.width, (size - start) / side * filtered.height),
        Image.Resampling.BICUBIC,
    )
    # Compare visual identity, allowing subpixel differences between encoders.
    actual_image = icon.filter(ImageFilter.GaussianBlur(0.6))
    expected = expected.filter(ImageFilter.GaussianBlur(0.6))
    error = count = 0
    for y in range(size):
        sy = (y + 0.5 - start) / side
        for x in range(size):
            sx = (x + 0.5 - start) / side
            if 0.08 < sx < 0.92 and 0.12 < sy < 0.91:
                actual = actual_image.getpixel((x, y))
                original = expected.getpixel((x, y))
                error += sum(abs(actual[c] - original[c]) for c in range(3))
                count += 3
    assert count and error / count < 24, ("Artwork differs from user upload", size, error / max(count, 1))


def image(path, size, opaque=False, artwork_fraction=1):
    path = ROOT / path
    with Image.open(path) as opened:
        opened.verify()
    with Image.open(path) as opened:
        assert opened.size == (size, size), (path, opened.size, size)
        if opaque:
            assert "A" not in opened.getbands(), f"Unexpected alpha channel: {path}"
        result = opened.convert("RGBA")
    checked.add(path)
    approved_artwork(result, artwork_fraction)
    return result


for platform in ("ios", "macos"):
    catalog = Path(platform) / "Runner/Assets.xcassets/AppIcon.appiconset"
    content = json.loads((ROOT / catalog / "Contents.json").read_text())
    for item in content["images"]:
        size = round(float(item["size"].split("x")[0]) * float(item["scale"][:-1]))
        icon = image(catalog / item["filename"], size, opaque=platform == "ios",
                     artwork_fraction=0.8 if platform == "macos" else 1)
        if platform == "macos":
            assert icon.getpixel((0, 0))[3] == 0, "Desktop margin must be transparent"
            assert icon.getpixel((size // 2, size // 2))[3] == 255

for density, scale in (("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2), ("xxhdpi", 3), ("xxxhdpi", 4)):
    folder = Path("android/app/src/main/res") / f"mipmap-{density}"
    image(folder / "ic_launcher.png", round(48 * scale), opaque=True)
    size = round(108 * scale)
    foreground = image(folder / "ic_launcher_foreground.png", size, opaque=True,
                       artwork_fraction=(32 / 108) / core_radius)
    assert foreground.getpixel((0, 0))[:3] == (12, 5, 64)
    # Decorative background can enter the mask area; bright gold, ivory and
    # jade game pieces must remain inside the protected circle.
    visible = []
    artwork_side = size * (32 / 108) / core_radius
    for y in range(size):
        for x in range(size):
            sx = (x + 0.5 - size / 2) / artwork_side + 0.5
            sy = (y + 0.5 - size / 2) / artwork_side + 0.5
            moon = 0.16 < sx < 0.80 and 0.04 < sy < 0.69
            left_flipper = 0 < sx < 0.43 and abs(sy - (0.59 + 0.75 * sx)) < 0.12
            right_flipper = 0.57 < sx < 1 and abs(sy - (0.59 + 0.75 * (1 - sx))) < 0.12
            if not (moon or left_flipper or right_flipper):
                continue  # Outer clouds, petals and tassels can be masked.
            r, g, b, _ = foreground.getpixel((x, y))
            gold = r > 120 and g > 70 and b < r * 0.7
            jade = g > 80 and g > r * 1.15 and g > b * 0.9
            if gold or jade:
                visible.append((x, y))
    assert visible, "Adaptive artwork must contain the game pieces"
    radius = max(math.hypot(x + 0.5 - size / 2, y + 0.5 - size / 2) for x, y in visible)
    assert radius <= 33 * scale, (density, "Art crosses Android's safe circle", radius)

namespace = "{http://schemas.android.com/apk/res/android}"
for api in (26, 33):
    adaptive = ET.parse(ROOT / f"android/app/src/main/res/mipmap-anydpi-v{api}/ic_launcher.xml").getroot()
    assert adaptive.tag == "adaptive-icon"
    assert adaptive.find("background").get(namespace + "drawable") == "@color/ic_launcher_background"
    assert adaptive.find("foreground").get(namespace + "drawable") == "@mipmap/ic_launcher_foreground"
    if api == 33:
        assert adaptive.find("monochrome") is not None

manifest = json.loads((ROOT / "web/manifest.json").read_text())
assert manifest["theme_color"] == manifest["background_color"] == "#0C0540"
for item in manifest["icons"]:
    size = int(item["sizes"].split("x")[0])
    icon = image(Path("web") / item["src"], size, opaque=True,
                 artwork_fraction=0.39 / core_radius if item.get("purpose") == "maskable" else 1)
    if item.get("purpose") == "maskable":
        assert icon.getpixel((0, 0))[:3] == (12, 5, 64)
image("web/icons/apple-touch-icon.png", 180, opaque=True)
image("web/favicon.png", 32, opaque=True)
image("build/app-icons/master-1024.png", 1024, opaque=True)
image("build/app-icons/play-store-512.png", 512, opaque=True)
image("linux/runner/resources/app_icon.png", 512, artwork_fraction=0.8)

with Image.open(ROOT / "windows/runner/resources/app_icon.ico") as ico:
    expected = {(size, size) for size in (16, 20, 24, 32, 40, 48, 64, 128, 256)}
    assert ico.ico.sizes() == expected, ico.ico.sizes()
    for size in expected:
        frame = ico.ico.getimage(size)
        assert frame.size == size
        approved_artwork(frame.convert("RGBA"), 0.8)
with Image.open(ROOT / "build/app-icons/MonPinball.icns") as icns:
    assert icns.size == (1024, 1024)
    icns.load()
    approved_artwork(icns.convert("RGBA"), 0.8)

print(f"PASS: {len(checked)} PNG files, 9 Windows frames, macOS ICNS, Apple catalogs, Android safe zones and web manifest.")
