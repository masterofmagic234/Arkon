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
    var effective_skill := RaceAiAssist.effective_skill(skill, car.physical_progress(n), player_progress, n)
    # Anticipate actual ribbon heading, then correct lane error.
    var at: float=car.track_phase()
    var ratio := clampf(float(car.speed)/RaceLevelData.PLAYER_MAX_SPEED,0.0,1.0)
    var preview := lerpf(.20,.65,ratio)
    var tangent := atan2(RaceMath.track_center_slope(at+preview,track_x),RaceLevelData.SEGMENT_HEIGHT)
    var center := RaceMath.track_center_x(at,track_x)
    var target_x := center+lane_bias*2.0
    var target_yaw := tangent+clampf((target_x-float(car.world_x))*.07,-.13,.13)
    var steer := clampf(RaceLevelData.steer_for_heading(target_yaw,ratio),-.97,.97)
    var target_speed := RaceMath.safe_corner_speed(at,track_x,RaceLevelData.PLAYER_MAX_SPEED*.92,RaceLevelData.NFS_MAX_HEADING_YAW,RaceLevelData.CORNER_GRIP_ACCEL)*lerpf(.93,1.0,effective_skill)
    var excess: float=float(car.speed)-target_speed
    var brake := clampf(excess/8.0,0.0,.65)
    var throttle := clampf((target_speed-float(car.speed))/4.0+.72,0.0,1.0)
    car.set_inputs(steer,throttle,brake)
