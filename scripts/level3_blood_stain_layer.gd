extends Node2D
class_name Level3BloodStainLayer

const MAX_STAINS: int = 360

var _textures: Array[Texture2D] = []
var _regions: Array[Rect2] = []
var _positions: Array[Vector2] = []
var _scales: Array[float] = []
var _rotations: Array[float] = []
var _modulates: Array[Color] = []

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    z_index = -4

func add_stain(
        texture: Texture2D,
        region: Rect2,
        position: Vector2,
        scale: float,
        rotation: float,
        modulate: Color
) -> void:
    if texture == null or region.size.x <= 0.0 or region.size.y <= 0.0:
        return

    _textures.append(texture)
    _regions.append(region)
    _positions.append(position)
    _scales.append(scale)
    _rotations.append(rotation)
    _modulates.append(modulate)

    while _textures.size() > MAX_STAINS:
        _textures.pop_front()
        _regions.pop_front()
        _positions.pop_front()
        _scales.pop_front()
        _rotations.pop_front()
        _modulates.pop_front()

    queue_redraw()

func _draw() -> void:
    for i in _textures.size():
        var frame_size := _regions[i].size
        draw_set_transform(
            _positions[i],
            _rotations[i],
            Vector2(_scales[i], _scales[i])
        )
        draw_texture_rect_region(
            _textures[i],
            Rect2(-frame_size * 0.5, frame_size),
            _regions[i],
            _modulates[i]
        )

    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
