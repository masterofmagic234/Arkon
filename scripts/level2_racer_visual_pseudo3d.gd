extends Node2D
class_name Level2RacerVisualPseudo3D

const SQUIRREL_PATH := "res://assets/squirrel_mobile.png"

var renderer: Node2D = null
var oka_stage: Node = null
var movement: Node = null
var projection: Dictionary = {}
var texture: Texture2D = null
var _draw_width := 0.0
var _draw_height := 0.0

func bind_movement(movement_ref: Node) -> void:
    movement = movement_ref
    if movement != null and not bool(movement.get("is_player")):
        texture = load(SQUIRREL_PATH) as Texture2D

func bind_renderer(renderer_ref: Node2D, movement_ref: Node) -> void:
    renderer = renderer_ref
    movement = movement_ref
    if movement != null and not bool(movement.get("is_player")):
        texture = load(SQUIRREL_PATH) as Texture2D

func bind_stage(stage: Node) -> void:
    oka_stage = stage

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
    _draw_width = float(projection["width"])
    _draw_height = float(projection["height"])

    if bool(movement.get("is_player")):
        if oka_stage != null and oka_stage.has_method("sync_from_movement"):
            oka_stage.sync_from_movement(movement)
        queue_redraw()
    else:
        rotation = float(projection.get("rotation", 0.0))
        z_index = 10
        queue_redraw()

func _draw() -> void:
    if movement == null or not visible:
        return

    if bool(movement.get("is_player")):
        var oka_texture := _get_oka_texture()
        if oka_texture != null:
            var src_size := Vector2(oka_texture.get_width(), oka_texture.get_height())
            var fit := minf(_draw_width / maxf(src_size.x, 1.0), _draw_height / maxf(src_size.y, 1.0))
            var dst_size := src_size * fit
            draw_texture_rect(
                oka_texture,
                Rect2(-dst_size.x * 0.5, -dst_size.y, dst_size.x, dst_size.y),
                false
            )
        else:
            draw_rect(
                Rect2(-_draw_width * 0.5, -_draw_height, _draw_width, _draw_height),
                Color(0.72, 0.08, 0.08, 1.0),
                true
            )
        z_index = 20
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

func _get_oka_texture() -> Texture2D:
    if oka_stage == null or not oka_stage.has_method("get_view_texture"):
        return null
    return oka_stage.get_view_texture() as Texture2D
