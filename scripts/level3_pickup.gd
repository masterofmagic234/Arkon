extends Area2D
class_name Level3Pickup

const AssetVisual = preload("res://scripts/level3_asset_visual.gd")

signal collected(kind: StringName)

var kind: StringName = &""
var consumed: bool = false
var _visual: Node2D

func setup(pickup_kind: StringName, world_position: Vector2) -> void:
    kind = pickup_kind
    global_position = world_position
    collision_layer = 4
    collision_mask = 2

func _ready() -> void:
    monitoring = true
    monitorable = true
    body_entered.connect(_on_body_entered)
    var shape := CircleShape2D.new()
    shape.radius = 22.0
    var collider := CollisionShape2D.new()
    collider.shape = shape
    add_child(collider)
    _setup_visual()

func _on_body_entered(body: Node) -> void:
    if consumed:
        return
    if body is Level3Player:
        consumed = true
        collected.emit(kind)
        queue_free()

func _setup_visual() -> void:
    var scale := Vector2(1.1, 1.1)
    match kind:
        &"pistol":
            _visual = AssetVisual.static_sprite(
                "res://assets/level3/weapons/guns/sprBossgun.png",
                scale
            )
        &"shotgun":
            _visual = AssetVisual.static_sprite(
                "res://assets/level3/weapons/guns/sprBossgun.png",
                Vector2(1.35, 1.35)
            )
        &"bat":
            _visual = AssetVisual.static_sprite(
                "res://assets/level3/weapons/melee/sprCleaverDrop.png",
                Vector2(1.3, 1.3)
            )
        &"bottle":
            _visual = AssetVisual.animated_strip(
                "res://assets/level3/weapons/throwables/sprMolotov_strip4.png",
                7.0,
                Vector2(1.1, 1.1)
            )

    if _visual == null:
        return
    _visual.position = Vector2(0.0, -4.0)
    _visual.z_index = 1
    add_child(_visual)

func _draw() -> void:
    # Pickups are rendered from the supplied weapon/item sprites.
    draw_circle(Vector2.ZERO, 17.0, Color(0.03, 0.03, 0.04, 0.50))
