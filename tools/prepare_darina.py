from PIL import Image, ImageDraw
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "IMG_20260917_103543.png"
OUT = ROOT / "assets"
DEBUG = ROOT / "build" / "darina_debug"

src = Image.open(SRC).convert("RGBA")

# Source-sheet rectangles, in the original 1078x1536 image.
RECTS = {
    "darina_peek.png": (43, 129, 210, 740),
    "darina_toy.png": (729, 160, 1078, 779),
    "darina_sad.png": (382, 808, 736, 1536),
    "darina_happy.png": (749, 815, 1078, 1536),
}


def remove_black_background(img: Image.Image) -> Image.Image:
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if max(r, g, b) < 22:
                px[x, y] = (r, g, b, 0)
    return img


def longest_transparent_row_gap(img: Image.Image) -> int:
    alpha = img.getchannel("A")
    rows = []
    for y in range(img.height):
        rows.append(alpha.crop((0, y, img.width, y + 1)).getbbox() is not None)

    longest = 0
    current = 0
    for occupied in rows:
        if occupied:
            current = 0
        else:
            current += 1
            longest = max(longest, current)
    return longest


OUT.mkdir(parents=True, exist_ok=True)
DEBUG.mkdir(parents=True, exist_ok=True)

# Keep a copy of the actual source used by CI so crop decisions can be verified
# against the exact file that the APK pipeline consumes.
src.save(DEBUG / "source_sheet.png", "PNG", optimize=True)

overlay = src.convert("RGBA")
draw = ImageDraw.Draw(overlay)
for name, rect in RECTS.items():
    draw.rectangle(rect, outline=(255, 64, 64, 255), width=4)
    draw.text((rect[0] + 4, rect[1] + 4), name, fill=(255, 255, 0, 255))
overlay.save(DEBUG / "crop_rectangles.png", "PNG", optimize=True)

for name, rect in RECTS.items():
    crop = remove_black_background(src.crop(rect))
    output_path = OUT / name
    crop.save(output_path, "PNG", optimize=True)

    bbox = crop.getchannel("A").getbbox()
    opaque_pixels = sum(1 for a in crop.getchannel("A").getdata() if a > 0)
    gap = longest_transparent_row_gap(crop)
    print(
        f"{name}: crop={crop.size}, alpha_bbox={bbox}, "
        f"opaque_pixels={opaque_pixels}, longest_transparent_row_gap={gap}"
    )

print("Darina poses prepared")
