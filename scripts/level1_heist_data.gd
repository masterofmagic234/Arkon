extends RefCounted
# Authored interaction footprints are shared with park physics and navigation.
const DIAL_TARGET := [1, 2, 1]
const SYMBOLS := ["ЗВЕЗДА", "ЛУНА", "ЛИСТ"]
const DEVICES := [
    {"id":"MoonDial1", "kind":"dial", "cell":Vector2i(14,14), "index":0},
    {"id":"MoonDial2", "kind":"dial", "cell":Vector2i(20,9), "index":1},
    {"id":"MoonDial3", "kind":"dial", "cell":Vector2i(30,14), "index":2},
    {"id":"GalleryRelay", "kind":"relay", "cell":Vector2i(74,22), "index":0},
    {"id":"OakSeal", "kind":"seal", "cell":Vector2i(63,45), "index":0},
    {"id":"BellEntry", "kind":"bell", "cell":Vector2i(25,49), "index":0},
    {"id":"BellMoon", "kind":"bell", "cell":Vector2i(32,17), "index":1},
    {"id":"BellGallery", "kind":"bell", "cell":Vector2i(78,25), "index":2},
    {"id":"BellGrove", "kind":"bell", "cell":Vector2i(72,47), "index":3},
    {"id":"NoteEntry", "kind":"note", "cell":Vector2i(8,47), "index":0},
    {"id":"NoteMoon", "kind":"note", "cell":Vector2i(10,22), "index":1},
    {"id":"NoteGrove", "kind":"note", "cell":Vector2i(78,53), "index":2},
]
const SCANNERS := [Vector2i(61,16), Vector2i(74,15)]
const NOTES := [
    "Записка садовника 1/3: «Колокольчики созывают дозор. Позвони и уходи другой дорогой. По траве тихие шаги почти не слышны». ",
    "Записка садовника 2/3: «Луна отражается в листе, и лист снова смотрит на луну. Вот и весь секрет трёх линз». ",
    "Записка садовника 3/3: «Печать дуба опускает решётку на мосту через озеро. На другой стороне — аллея и машина. Последний жёлудь разбудит дозор». ",
]

static func footprint(spec: Dictionary) -> Vector3:
    if spec.kind == "note": return Vector3(.55,1.25,.30)
    if spec.kind == "bell": return Vector3(.48,1.80,.48)
    return Vector3(.80,1.35,.70)
