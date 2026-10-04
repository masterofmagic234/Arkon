extends Node
class_name RaceAIComponent

const RaceAiAssist = preload("res://scripts/race_ai_assist.gd")

var movement: RaceMovementComponent = null
var skill := 0.8
var lane_bias := 0.0

func setup(
        movement_ref: RaceMovementComponent,
        skill_: float,
        bias: float
) -> void:
    movement = movement_ref
    skill = clampf(skill_, 0.0, 1.0)
    lane_bias = clampf(bias, -1.0, 1.0)

func tick(_delta: float) -> void:
    if movement == null or not movement.race_active:
        return

    var player := get_tree().get_first_node_in_group(
        "level2_player"
    )
    if player == null:
        return

    var player_movement := player.get_node_or_null(
        "RaceMovementComponent"
    ) as RaceMovementComponent
    if player_movement == null:
        return

    var effective_skill := RaceAiAssist.effective_skill(
        skill,
        movement.progress(movement.track_length),
        player_movement.progress(movement.track_length),
        movement.track_length
    )

    var vehicle := movement.get_physical_vehicle()
    if vehicle == null:
        return

    var target := movement.get_ai_target_point(
        clampf(
            5.0 + movement.speed * 0.22,
            5.0,
            12.0
        ),
        lane_bias
    )

    var to_target := target - vehicle.global_position
    to_target.y = 0.0
    if to_target.length_squared() < 0.01:
        movement.set_inputs(
            0.0,
            effective_skill,
            0.0
        )
        return

    to_target = to_target.normalized()

    var forward := -vehicle.global_transform.basis.z
    forward.y = 0.0
    if forward.length_squared() < 0.0001:
        forward = Vector3(0.0, 0.0, -1.0)
    else:
        forward = forward.normalized()

    var signed_angle := atan2(
        forward.cross(to_target).y,
        forward.dot(to_target)
    )

    var steer := clampf(
        signed_angle / deg_to_rad(28.0),
        -1.0,
        1.0
    )

    var brake := 0.0
    brake = maxf(
        brake,
        movement.get_curve_severity(6.0) * 0.72
    )
    brake = maxf(
        brake,
        movement.get_curve_severity(12.0) * 0.48
    )

    if absf(signed_angle) > deg_to_rad(30.0):
        brake = maxf(brake, 0.16)
    if absf(signed_angle) > deg_to_rad(50.0):
        brake = maxf(brake, 0.35)

    var throttle := clampf(
        (1.0 - brake) * effective_skill,
        0.0,
        1.0
    )

    movement.set_inputs(
        steer * effective_skill,
        throttle,
        brake
    )
