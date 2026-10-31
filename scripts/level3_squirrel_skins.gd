extends RefCounted
# Shared, immutable animal animation resources. All roles face right around
# the same body origin; there are no per-role human sprite offsets/rotations.
const ROOT := "res://assets/level3/squirrels/"
const CLIPS := {
    &"idle":8, &"walk":12, &"windup":8,
    &"attack":6, &"stun":4, &"fall":6,
}
static var _cache: Dictionary={}
static func release_scene_cache() -> void:
    _cache.clear()
static func frames(kind: StringName) -> SpriteFrames:
    if _cache.has(kind): return _cache[kind]
    var result := SpriteFrames.new()
    result.remove_animation(&"default")
    for clip: StringName in CLIPS:
        var texture := load(ROOT+"%s_%s_strip%d.png"%[kind,clip,CLIPS[clip]]) as Texture2D
        result.add_animation(clip)
        result.set_animation_loop(clip,clip in [&"idle",&"walk",&"stun"])
        result.set_animation_speed(clip,24 if clip==&"walk" else 6)
        for index in range(CLIPS[clip]):
            var frame := AtlasTexture.new()
            frame.atlas=texture
            frame.region=Rect2(index*80,0,80,80)
            result.add_frame(clip,frame)
    _cache[kind]=result
    return result
