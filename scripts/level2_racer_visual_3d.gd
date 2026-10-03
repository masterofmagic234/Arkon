extends Node3D
class_name Level2RacerVisual3D

@onready var movement: RaceMovementComponent = (
    get_parent().get_node("RaceMovementComponent")
    as RaceMovementComponent
)

func sync_from_movement() -> void:
    if movement == null:
        return

    position = Vector3(
        movement.get_render_world_x(),
        0.9,
        movement.get_render_world_z()
    )

    # The road heading is the base orientation; steering adds only a small
    # driver-input response instead of pretending the car faces the screen.
    var visual_yaw := (
        movement.get_render_track_yaw()
        - movement.steer_in * 0.12
    )

    rotation_degrees = Vector3(
        0.0,
        rad_to_deg(visual_yaw),
        0.0
    )
