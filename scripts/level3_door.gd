extends Node2D
class_name Level3Door

signal opened(door: Level3Door)

@export var tile_size: float = 48.0

var is_open: bool = false
var locked: bool = false
var _collision_body: StaticBody2D
var _collision_shape: CollisionShape2D

func setup(world_position: Vector2, locked_state: bool = false) -> void:
    global_position = world_position
    locked = locked_state

func _ready() -> void:
    _collision_body = StaticBody2D.new()
    _collision_body.collision_layer = 1
    _collision_body.collision_mask = 0
    _collision_shape = CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(tile_size * 0.86, tile_size * 0.72)
    _collision_shape.shape = shape
    _collision_body.add_child(_collision_shape)
    add_child(_collision_body)
    queue_redraw()

func interact() -> bool:
    if is_open or locked:
        return false
    open()
    return true

func open() -> void:
    if is_open:
        return
    is_open = true
    _collision_shape.disabled = true
    var tween := create_tween()
    tween.tween_property(self, "scale:x", 0.10, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_property(self, "modulate:a", 0.35, 0.08)
    opened.emit(self)

func _draw() -> void:
    var door_color := Color(0.34, 0.35, 0.39, 1.0)
    var frame_color := Color(0.12, 0.12, 0.14, 1.0)
    draw_rect(Rect2(-tile_size * 0.43, -tile_size * 0.36, tile_size * 0.86, tile_size * 0.72), frame_color, true)
    draw_rect(Rect2(-tile_size * 0.35, -tile_size * 0.29, tile_size * 0.70, tile_size * 0.58), door_color, true)
    draw_line(Vector2(0, -tile_size * 0.20), Vector2(0, tile_size * 0.20), door_color.lightened(0.2), 2.0)
