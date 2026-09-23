extends Node3D
class_name Level1Door

@export var required_key: int = 1
@export var open_angle_degrees: float = -92.0
@export var open_duration: float = 0.45

var is_open := false
var _opening := false

@onready var pivot: Node3D = $Pivot
@onready var collision: CollisionShape3D = $Pivot/Leaf/Collision

func open() -> void:
    if is_open or _opening:
        return
    _opening = true
    var tween := create_tween()
    tween.set_parallel(false)
    tween.tween_property(
        pivot,
        "rotation:y",
        deg_to_rad(open_angle_degrees),
        open_duration
    ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_callback(_finish_open)

func _finish_open() -> void:
    is_open = true
    _opening = false
    if collision:
        collision.set_deferred("disabled", true)
