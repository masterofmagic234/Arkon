extends RefCounted
# Authored interaction footprints are shared with park physics and navigation.
const DIAL_TARGET := [1, 2, 1]
const SYMBOLS := ["ЗВЕЗДА", "ЛУНА", "ЛИСТ"]
const DEVICES := [
    {"id":"MoonDial1", "kind":"dial", "cell":Vector2i(14,4), "index":0},
    {"id":"MoonDial2", "kind":"dial", "cell":Vector2i(16,3), "index":1},
    {"id":"MoonDial3", "kind":"dial", "cell":Vector2i(18,6), "index":2},
    {"id":"GalleryRelay", "kind":"relay", "cell":Vector2i(41,6), "index":0},
    {"id":"OakSeal", "kind":"seal", "cell":Vector2i(38,24), "index":0},
    {"id":"BellEntry", "kind":"bell", "cell":Vector2i(10,23), "index":0},
    {"id":"BellMoon", "kind":"bell", "cell":Vector2i(20,10), "index":1},
    {"id":"BellGallery", "kind":"bell", "cell":Vector2i(33,15), "index":2},
    {"id":"BellGrove", "kind":"bell", "cell":Vector2i(40,30), "index":3},
    {"id":"NoteEntry", "kind":"note", "cell":Vector2i(3,22), "index":0},
    {"id":"NoteMoon", "kind":"note", "cell":Vector2i(4,6), "index":1},
    {"id":"NoteGrove", "kind":"note", "cell":Vector2i(44,32), "index":2},
]
const SCANNERS := [Vector2i(32,6), Vector2i(43,11)]
const NOTES := [
    "Записка садовника 1/3: «Колокольчики созывают дозор. Позвони и уходи другой дорогой. По траве тихие шаги почти не слышны». ",
    "Записка садовника 2/3: «Луна отражается в листе, и лист снова смотрит на луну. Вот и весь секрет трёх линз». ",
    "Записка садовника 3/3: «Последний жёлудь разбудит весь парк. Машину оставили у ВХОДА. Не геройствуй: жми рывок и беги». ",
]

static func footprint(spec: Dictionary) -> Vector3:
    if spec.kind == "note": return Vector3(.55,1.25,.30)
    if spec.kind == "bell": return Vector3(.48,1.80,.48)
    return Vector3(.80,1.35,.70)
