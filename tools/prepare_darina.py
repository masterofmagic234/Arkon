from PIL import Image
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "IMG_20260917_103543.png"
OUT = ROOT / "assets"

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

OUT.mkdir(parents=True, exist_ok=True)
for name, rect in RECTS.items():
    remove_black_background(src.crop(rect)).save(OUT / name, "PNG", optimize=True)

print("Darina poses prepared")
