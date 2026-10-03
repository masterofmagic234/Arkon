extends Node2D
class_name Level2RacerVisualPseudo3D

const OKA_PATH := "res://assets/oka.png"
const SQUIRREL_PATH := "res://assets/squirrel_mobile.png"

var renderer: Node2D = null
var movement: RaceMovementComponent = null
var projection: Dictionary = {}
var texture: Texture2D = null
var _draw_width := 0.0
var _draw_height := 0.0

func bind_movement(movement_ref: RaceMovementComponent) -> void:
    movement = movement_ref
    texture = _load_texture(
        OKA_PATH if movement != null and movement.is_player else SQUIRREL_PATH
    )

func bind_renderer(renderer_ref: Node2D, movement_ref: RaceMovementComponent) -> void:
    renderer = renderer_ref
    movement = movement_ref
    if texture == null:
        texture = _load_texture(
            OKA_PATH if movement != null and movement.is_player else SQUIRREL_PATH
        )

func sync_from_movement() -> void:
    if renderer == null or movement == null:
        visible = false
        return

    projection = renderer.project_racer(movement)
    visible = bool(projection.get("visible", false))
    if not visible:
        return

    position = Vector2(
        float(projection["x"]),
        float(projection["y"])
    )
    rotation = float(projection.get("rotation", 0.0))
    _draw_width = float(projection["width"])
    _draw_height = float(projection["height"])
    z_index = 20 if movement.is_player else 10
    queue_redraw()

func _draw() -> void:
    if movement == null or not visible:
        return

    if texture != null:
        draw_texture_rect(
            texture,
            Rect2(
                -_draw_width * 0.5,
                -_draw_height,
                _draw_width,
                _draw_height
            ),
            false
        )
        return

    var w := maxf(_draw_width, 8.0)
    var h := maxf(_draw_height, 8.0)
    draw_rect(Rect2(-w * 0.5, -h, w, h), Color(0.8, 0.15, 0.15), true)
    draw_rect(Rect2(-w * 0.4, -h * 0.7, w * 0.8, h * 0.3), Color.WHITE, true)

func _load_texture(path: String) -> Texture2D:
    return load(path) as Texture2D
