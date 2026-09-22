extends Node2D
class_name Level3Door

const AssetVisual = preload("res://scripts/level3_asset_visual.gd")

signal opened(door: Level3Door)

@export var tile_size: float = 48.0

var is_open: bool = false
var locked: bool = false
var _collision_body: StaticBody2D
var _collision_shape: CollisionShape2D
var _visual: Sprite2D

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
    _visual = AssetVisual.static_sprite("res://assets/level3/source/Doors/sprDoorH.png", Vector2(1.0, 1.0))
    if _visual != null:
        _visual.z_index = 1
        _visual.position = Vector2(0.0, -1.0)
        add_child(_visual)

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
    if _visual != null:
        _visual.modulate = Color(1.0, 1.0, 1.0, 0.25)
    var tween := create_tween()
    tween.tween_property(self, "scale:x", 0.10, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_property(self, "modulate:a", 0.35, 0.08)
    opened.emit(self)

func _draw() -> void:
    # Door sprite is supplied by the Level 3 asset pack.
    pass
