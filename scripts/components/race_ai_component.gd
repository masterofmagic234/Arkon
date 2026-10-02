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
    if movement == null:
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
    var track_x := movement.track_x
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

    var brake := 0.0
    var steer_bias := 0.0

    for i in range(1, RaceLevelData.AI_LOOKAHEAD + 1):
        var idx: int = (movement.segment_index + i) % n
        var seg: int = pattern[idx]
        var weight := float(RaceLevelData.AI_LOOKAHEAD - i) / float(RaceLevelData.AI_LOOKAHEAD)
        brake = maxf(
            brake,
            RaceMath.ai_brake_for(seg, i) * weight
        )
        steer_bias += RaceMath.curve_of(seg) * 0.01 * weight

    var center: float = track_x[movement.segment_index]
    var half: float = RaceLevelData.ROAD_WIDTH * 0.5
    var target_x: float = center + lane_bias * half * 0.55
    var err: float = (target_x - movement.world_x) / 2.5
    var steer := clampf(err + steer_bias, -1.0, 1.0) * effective_skill
    var throttle := clampf((1.0 - brake) * effective_skill, 0.0, 1.0)

    movement.set_inputs(steer, throttle, brake)
