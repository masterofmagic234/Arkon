from PIL import Image
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "IMG_20260917_103543.png"
OUT = ROOT / "assets"

src = Image.open(SRC).convert("RGBA")

# The current source sheet in the repository is 718x1023 px. The previous
# extraction rectangles were copied from an older 1078x1536 version, which
# caused each crop to overlap neighboring poses and sometimes extend past the
# actual image bounds.
EXPECTED_SOURCE_SIZE = (718, 1023)
if src.size != EXPECTED_SOURCE_SIZE:
    raise ValueError(
        f"Unexpected Darina source size: {src.size}; "
        f"expected {EXPECTED_SOURCE_SIZE}. Update RECTS intentionally if the "
        "source artwork is replaced."
    )

# One complete pose per rectangle, with a small transparent margin. These
# regions are based on the actual 718x1023 source sheet used by CI.
RECTS = {
    "darina_peek.png": (18, 72, 242, 510),
    "darina_toy.png": (470, 92, 718, 538),
    "darina_sad.png": (247, 522, 492, 1023),
    "darina_happy.png": (493, 530, 718, 1023),
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
    crop = remove_black_background(src.crop(rect))
    alpha_bbox = crop.getchannel("A").getbbox()
    if alpha_bbox is None:
        raise RuntimeError(f"Darina crop is completely transparent: {name}")

    crop.save(OUT / name, "PNG", optimize=True)
    print(f"{name}: crop={crop.size}, alpha_bbox={alpha_bbox}")

print("Darina poses prepared")
