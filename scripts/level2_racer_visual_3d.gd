extends Node3D
class_name Level2RacerVisual3D

@onready var movement: RaceMovementComponent = get_parent().get_node("RaceMovementComponent") as RaceMovementComponent

func sync_from_movement() -> void:
    if movement == null:
        return
    position = Vector3(
        movement.world_x,
        0.9,
        movement.world_z
    )
    rotation_degrees = Vector3(
        0.0,
        rad_to_deg(movement.sprite_yaw),
        0.0
    )
