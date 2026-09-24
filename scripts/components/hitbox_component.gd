extends Area2D
class_name HitboxComponent

signal hit(source: Node, amount: int)

@export var hit_layer: int = 4
@export var hit_mask: int = 0
@export var radius: float = 7.0

func _ready() -> void:
    collision_layer = hit_layer
    collision_mask = hit_mask
    monitoring = false
    monitorable = true
    var shape := CircleShape2D.new()
    shape.radius = radius
    var collider := CollisionShape2D.new()
    collider.shape = shape
    add_child(collider)

func receive_hit(amount: int, source: Node = null) -> void:
    hit.emit(source, amount)
    var parent_node := get_parent()
    if parent_node != null and parent_node.has_method("take_damage"):
        parent_node.take_damage(amount)
