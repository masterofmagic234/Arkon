extends RefCounted
## Four immutable 96px poses per speaker: rest, talk-small, talk-wide, blink.

const FRAME_SIZE := 96
const PATHS := {
    "carolina":"res://assets/level3/dialogue/carolina.png",
    "chef":"res://assets/level3/dialogue/chef.png",
    "chef_shocked":"res://assets/level3/dialogue/chef_shocked.png",
}
static var _cache: Dictionary = {}
static func release_scene_cache() -> void:
    _cache.clear()

static func key_for(entry: Dictionary) -> String:
    var key := String(entry.get("portrait", "carolina"))
    if key == "chef" and String(entry.get("expression", "")) == "shocked":
        return "chef_shocked"
    return key if PATHS.has(key) else "carolina"

static func frame(key: String, index: int) -> Texture2D:
    if not PATHS.has(key): key = "carolina"
    if not _cache.has(key):
        var path: String = PATHS[key]
        if not ResourceLoader.exists(path): return null
        var strip := load(path) as Texture2D
        if strip == null: return null
        var frames: Array[AtlasTexture] = []
        for column in range(4):
            var texture := AtlasTexture.new()
            texture.atlas = strip
            texture.region = Rect2(column * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
            frames.append(texture)
        _cache[key] = frames
    return _cache[key][clampi(index, 0, 3)]
