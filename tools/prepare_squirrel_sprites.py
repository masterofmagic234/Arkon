from collections import Counter, deque
from pathlib import Path
from PIL import Image

SPRITES = [
    "squirrel_scout.png",
    "squirrel_scout_stunned.png",
    "squirrel_thrower.png",
    "squirrel_thrower_stunned.png",
    "squirrel_tank.png",
    "squirrel_tank_stunned.png",
    "squirrel_thief.png",
    "squirrel_thief_stunned.png",
    "squirrel_runner.png",
    "squirrel_runner_stunned.png",
]

def color_distance(a, b):
    return sum((int(a[i]) - int(b[i])) ** 2 for i in range(3)) ** 0.5

def is_neutral(c):
    return max(c[:3]) - min(c[:3]) <= 14

def background_palette(image):
    px = image.load()
    w, h = image.size
    border = []
    for x in range(w):
        for y in range(min(8, h)):
            c = px[x, y]
            if c[3] > 0 and is_neutral(c):
                border.append(c)
        for y in range(max(0, h - 8), h):
            c = px[x, y]
            if c[3] > 0 and is_neutral(c):
                border.append(c)
    for y in range(h):
        for x in range(min(8, w)):
            c = px[x, y]
            if c[3] > 0 and is_neutral(c):
                border.append(c)
        for x in range(max(0, w - 8), w):
            c = px[x, y]
            if c[3] > 0 and is_neutral(c):
                border.append(c)

    common = Counter(border).most_common(8)
    return [color for color, _count in common]

def remove_checkerboard(path):
    image = Image.open(path).convert("RGBA")
    px = image.load()
    w, h = image.size
    palette = background_palette(image)
    if not palette:
        raise RuntimeError(f"No neutral border palette found in {path}")

    def is_background(x, y):
        c = px[x, y]
        if c[3] == 0 or not is_neutral(c):
            return c[3] == 0
        return min(color_distance(c, p) for p in palette) <= 24.0

    visited = bytearray(w * h)
    queue = deque()

    def push(x, y):
        idx = y * w + x
        if visited[idx]:
            return
        if not is_background(x, y):
            return
        visited[idx] = 1
        queue.append((x, y))

    for x in range(w):
        push(x, 0)
        push(x, h - 1)
    for y in range(h):
        push(0, y)
        push(w - 1, y)

    removed = 0
    while queue:
        x, y = queue.popleft()
        if px[x, y][3] != 0:
            px[x, y] = (px[x, y][0], px[x, y][1], px[x, y][2], 0)
            removed += 1
        if x > 0:
            push(x - 1, y)
        if x + 1 < w:
            push(x + 1, y)
        if y > 0:
            push(x, y - 1)
        if y + 1 < h:
            push(x, y + 1)

    if removed == 0:
        raise RuntimeError(f"Checkerboard background not detected in {path}")

    image.save(path, "PNG", optimize=True)
    print(f"[squirrel] {path}: removed {removed} background pixels")

for name in SPRITES:
    path = Path("assets") / name
    if not path.is_file():
        raise FileNotFoundError(path)
    remove_checkerboard(path)
