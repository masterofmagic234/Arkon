extends Area2D
class_name Level3Pickup

const AssetVisual = preload("res://scripts/level3_asset_visual.gd")

signal collected(kind: StringName)

@export var kind: StringName = &""
var consumed: bool = false
@onready var _visual: Sprite2D = %Visual
@onready var _collider: CollisionShape2D = %CollisionShape2D

func _ready() -> void:
    monitoring = true
    monitorable = true
    collision_layer = 4
    collision_mask = 2
    body_entered.connect(_on_body_entered)
    _configure_visual()

func _on_body_entered(body: Node) -> void:
    if consumed:
        return
    if body is Level3Player:
        consumed = true
        collected.emit(kind)
        queue_free()

func _configure_visual() -> void:
    if _visual == null:
        return
    _visual.position = Vector2(0.0, -2.0)
    _visual.z_index = 1
    _visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    match kind:
        &"pistol", &"shotgun":
            _visual.texture = AssetVisual.first_frame_texture("res://assets/level3/weapons/guns/sprBossgun.png")
        &"bat":
            _visual.texture = AssetVisual.first_frame_texture("res://assets/level3/weapons/melee/sprCleaverDrop.png")
        &"bottle":
            _visual.texture = AssetVisual.first_frame_texture("res://assets/level3/weapons/throwables/sprMolotov_strip4.png")
        _:
            _visual.texture = null

func _draw() -> void:
    draw_circle(Vector2.ZERO, 7.0, Color(0.03, 0.03, 0.04, 0.50))
