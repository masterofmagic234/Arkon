extends RefCounted
class_name Level3AssetVisual

# Sprite strips contain either animation frames or furniture variants. Authors
# choose the variant explicitly; shared immutable resources prevent attack-time
# texture/RegEx/SpriteFrames allocations.
static var _counts: Dictionary = {}
static var _textures: Dictionary = {}
static var _frames: Dictionary = {}

static func release_scene_cache() -> void:
    # Existing sprites retain their own resources. Only this optional cache
    # releases its references when the diner is left or restarted.
    _textures.clear()
    _frames.clear()
    _counts.clear()

static func strip_frame_count(path: String) -> int:
    if _counts.has(path): return _counts[path]
    var suffix := path.get_file().get_basename().rsplit("_strip",true,1)
    var count := maxi(1,int(suffix[1])) if suffix.size()==2 else 1
    _counts[path] = count
    return count

static func frame_texture(path: String, frame: int = 0) -> Texture2D:
    var key := path+":"+str(frame)
    if _textures.has(key): return _textures[key]
    var source := load(path) as Texture2D
    if source == null: return null
    var count := strip_frame_count(path)
    if count == 1:
        _textures[key] = source
        return source
    var atlas := AtlasTexture.new()
    atlas.atlas = source
    var width := float(source.get_width())/count
    atlas.region = Rect2(clampi(frame,0,count-1)*width,0.0,width,source.get_height())
    _textures[key] = atlas
    return atlas

static func first_frame_texture(path: String) -> Texture2D: return frame_texture(path)

static func sprite_frames_from_strip(path: String, fps: float = 8.0, loop: bool = true) -> SpriteFrames:
    var key := path+":"+str(fps)+":"+str(loop)
    if _frames.has(key): return _frames[key]
    var frames := SpriteFrames.new()
    frames.set_animation_speed(&"default",fps)
    frames.set_animation_loop(&"default",loop)
    for index in range(strip_frame_count(path)):
        var frame := frame_texture(path,index)
        if frame == null: return null
        frames.add_frame(&"default",frame)
    _frames[key] = frames
    return frames

static func animated_strip(path: String, fps: float = 8.0, scale_: Vector2 = Vector2.ONE, loop: bool = true) -> AnimatedSprite2D:
    var frames := sprite_frames_from_strip(path,fps,loop)
    if frames == null: return null
    var sprite := AnimatedSprite2D.new()
    sprite.sprite_frames = frames
    sprite.scale = scale_
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.play(&"default")
    return sprite

static func static_sprite(path: String, scale_: Vector2 = Vector2.ONE) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.texture = first_frame_texture(path)
    sprite.scale = scale_
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    return sprite
