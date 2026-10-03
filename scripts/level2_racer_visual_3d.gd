extends Node3D
class_name Level2RacerVisual3D

var movement: RaceMovementComponent = null

func _ready() -> void:
    var racer := get_parent().get_parent()
    movement = racer.get_node_or_null(
        "RaceMovementComponent"
    ) as RaceMovementComponent

func sync_from_movement() -> void:
    if movement == null:
        return

    position = Vector3(
        movement.get_render_world_x(),
        0.9,
        movement.get_render_world_z()
    )
    rotation_degrees = Vector3(
        0.0,
        rad_to_deg(movement.get_render_track_yaw()),
        0.0
    )
