extends Node
class_name RaceAIComponent

const RaceMath = preload("res://scripts/race_math.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")
const RaceAiAssist = preload("res://scripts/race_ai_assist.gd")

var movement: RaceMovementComponent = null
var skill: float = 0.8
var lane_bias: float = 0.0

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

    var player := get_tree().get_first_node_in_group("level2_player")
    if player == null:
        return

    var player_movement := player.get_node_or_null(
        "RaceMovementComponent"
    ) as RaceMovementComponent
    if player_movement == null:
        return

    var pattern := movement.track_pattern
    var n := pattern.size()
    if n <= 0:
        return

    var player_progress := player_movement.progress(n)
    var effective_skill := RaceAiAssist.effective_skill(
        skill,
        movement.progress(n),
        player_progress,
        n
    )

    var vehicle := movement.get_physical_vehicle()
    if vehicle == null:
        return

    var target := movement.get_ai_target_point(
        clampf(5.0 + movement.speed * 0.20, 5.0, 12.0),
        lane_bias
    )

    var to_target := target - vehicle.global_position
    to_target.y = 0.0
    if to_target.length_squared() < 0.01:
        movement.set_inputs(0.0, effective_skill, 0.0)
        return

    to_target = to_target.normalized()

    var forward := -vehicle.global_transform.basis.z
    forward.y = 0.0
    if forward.length_squared() < 0.01:
        forward = Vector3.FORWARD
    else:
        forward = forward.normalized()

    var signed_angle := atan2(
        forward.cross(to_target).y,
        forward.dot(to_target)
    )
    var steer := clampf(
        signed_angle / deg_to_rad(26.0),
        -1.0,
        1.0
    )

    var brake := 0.0
    var lookahead := 7
    for i in range(1, RaceLevelData.AI_LOOKAHEAD + 1):
        var idx: int = posmod(
            movement.segment_index + i,
            n
        )
        var seg: int = int(pattern[idx])
        var weight := (
            float(RaceLevelData.AI_LOOKAHEAD - i)
            / float(RaceLevelData.AI_LOOKAHEAD)
        )
        brake = maxf(
            brake,
            RaceMath.ai_brake_for(seg, i) * weight
        )

    if absf(signed_angle) > deg_to_rad(24.0):
        brake = maxf(brake, 0.18)
    if absf(signed_angle) > deg_to_rad(36.0):
        brake = maxf(brake, 0.38)
    if absf(signed_angle) > deg_to_rad(52.0):
        brake = maxf(brake, 0.62)

    var throttle := clampf(
        (1.0 - brake) * effective_skill,
        0.0,
        1.0
    )

    # Keep the AI decisively pointed toward the road target. It is physical
    # steering now, so no fake lane-position write is necessary.
    movement.set_inputs(
        steer * effective_skill,
        throttle,
        brake
    )

    lookahead = lookahead
