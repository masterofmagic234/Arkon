extends Area2D
class_name HitboxComponent

signal hit(source: Node, amount: int)

@export var hit_layer: int = 4
@export var hit_mask: int = 0
@export var radius: float = 7.0
@onready var collider: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
    collision_layer = hit_layer
    collision_mask = hit_mask
    monitoring = false
    monitorable = true
    if collider != null:
        if collider.shape == null:
            var shape := CircleShape2D.new()
            shape.radius = radius
            collider.shape = shape
        elif collider.shape is CircleShape2D:
            radius = (collider.shape as CircleShape2D).radius
    add_child(collider)

func receive_hit(amount: int, source: Node = null) -> void:
    hit.emit(source, amount)
    var parent_node := get_parent()
    if parent_node != null and parent_node.has_method("take_damage"):
        parent_node.take_damage(amount)
