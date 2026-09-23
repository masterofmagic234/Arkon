extends RefCounted
class_name Level3AssetVisual

static func strip_frame_count(path: String) -> int:
    var base := path.get_file().get_basename()
    var regex := RegEx.new()
    regex.compile("_strip(\\d+)$")
    var match := regex.search(base)
    if match == null:
        return 1
    return maxi(1, int(match.get_string(1)))

static func first_frame_texture(path: String) -> Texture2D:
    var texture := load(path) as Texture2D
    if texture == null:
        return null

    var frame_count := strip_frame_count(path)
    if frame_count <= 1:
        return texture

    var frame_width := float(texture.get_width()) / float(frame_count)
    var atlas := AtlasTexture.new()
    atlas.atlas = texture
    atlas.region = Rect2(0.0, 0.0, frame_width, texture.get_height())
    return atlas

static func animated_strip(path: String, fps: float = 8.0, scale: Vector2 = Vector2.ONE, loop: bool = true) -> AnimatedSprite2D:
    var texture := load(path) as Texture2D
    if texture == null:
        return null

    var frame_count := strip_frame_count(path)
    var frame_width := float(texture.get_width()) / float(frame_count)

    var frames := SpriteFrames.new()
    frames.set_animation_speed(&"default", fps)
    frames.set_animation_loop(&"default", loop)

    for index in range(frame_count):
        var atlas := AtlasTexture.new()
        atlas.atlas = texture
        atlas.region = Rect2(
            float(index) * frame_width,
            0.0,
            frame_width,
            float(texture.get_height())
        )
        frames.add_frame(&"default", atlas)

    var sprite := AnimatedSprite2D.new()
    sprite.sprite_frames = frames
    sprite.animation = &"default"
    sprite.speed_scale = 1.0
    sprite.scale = scale
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.play(&"default")
    return sprite

static func static_sprite(path: String, scale: Vector2 = Vector2.ONE) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.texture = first_frame_texture(path)
    sprite.scale = scale
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    return sprite
