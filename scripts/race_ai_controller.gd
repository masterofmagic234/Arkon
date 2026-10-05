extends RefCounted

# AI-пилот Level 2.

const RaceMath = preload("res://scripts/race_math.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")
const RaceAiAssist = preload("res://scripts/race_ai_assist.gd")

var car
var skill: float = 0.8
var lane_bias: float = 0.0
var track_pattern: Array
var track_x: PackedFloat32Array

func setup(car_ref, pattern: Array, tx: PackedFloat32Array, skill_: float, bias: float) -> void:
    car = car_ref
    track_pattern = pattern
    track_x = tx
    skill = clampf(skill_, 0.0, 1.0)
    lane_bias = clampf(bias, -1.0, 1.0)

func tick(_delta: float, player_progress: float = -INF) -> void:
    if car == null:
        return

    var n := track_pattern.size()
    var effective_skill := RaceAiAssist.effective_skill(skill, car.progress(n), player_progress, n)
    var brake := 0.0
    var steer_bias := 0.0
    for i in range(1, RaceLevelData.AI_LOOKAHEAD + 1):
        var idx: int = (car.segment_index + i) % n
        var seg: int = track_pattern[idx]
        var weight := float(RaceLevelData.AI_LOOKAHEAD - i) / float(RaceLevelData.AI_LOOKAHEAD)
        brake = maxf(brake, RaceMath.ai_brake_for(seg, i) * weight)
        steer_bias += RaceMath.curve_of(seg) * 0.01 * weight

    var center: float = track_x[car.segment_index]
    var half: float = RaceLevelData.ROAD_WIDTH * 0.5
    var target_x: float = center + lane_bias * half * 0.55
    var err: float = (target_x - car.world_x) / 2.5
    var steer := clampf(err + steer_bias, -1.0, 1.0) * effective_skill
    var throttle := clampf((1.0 - brake) * effective_skill, 0.0, 1.0)
    car.set_inputs(steer, throttle, brake)
