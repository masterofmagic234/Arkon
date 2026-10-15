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
var pursuit_target
var pursuit_allowed := false
var pursuit_role := 0
var attack_phase: StringName = &"follow"
var attack_time := 0.0
var attack_cooldown := 3.0
var attack_side := 1.0
var evasion_lane := INF

func recover_from_ram() -> void:
    attack_phase=&"recover";attack_time=1.2;attack_cooldown=5.0

func setup(car_ref, pattern: Array, tx: PackedFloat32Array, skill_: float, bias: float) -> void:
    car = car_ref
    track_pattern = pattern
    track_x = tx
    skill = clampf(skill_, 0.0, 1.0)
    lane_bias = clampf(bias, -1.0, 1.0)

func tick(delta: float, player_progress: float = -INF) -> void:
    if car == null:
        return

    var n := track_pattern.size()
    var effective_skill := RaceAiAssist.effective_skill(skill, car.physical_progress(n), player_progress, n)
    # Anticipate actual ribbon heading, then correct lane error.
    var at: float=car.track_phase()
    var ratio := clampf(float(car.speed)/RaceLevelData.PLAYER_MAX_SPEED,0.0,1.0)
    var preview := lerpf(.10,.42,ratio)
    var tangent := atan2(RaceMath.track_center_slope(at+preview,track_x),RaceLevelData.SEGMENT_HEIGHT)
    var center := RaceMath.track_center_x(at,track_x)
    var target_x := center+lane_bias*2.0
    if pursuit_target!=null:
        attack_cooldown=maxf(0,attack_cooldown-delta)
        attack_time=maxf(0,attack_time-delta)
        if not pursuit_allowed and attack_phase in [&"warn",&"ram"]: recover_from_ram()
        var dz: float=car.world_z-pursuit_target.world_z
        if attack_phase==&"follow" and pursuit_allowed and attack_cooldown<=0 and absf(dz)<7 and car.speed>14:
            attack_side=signf(car.lateral_offset-pursuit_target.lateral_offset)
            if attack_side==0: attack_side=1.0 if pursuit_role%2==0 else -1.0
            attack_phase=&"warn";attack_time=.9
        elif attack_phase==&"warn" and attack_time<=0:
            attack_phase=&"ram";attack_time=.8
        elif attack_phase==&"ram" and attack_time<=0: recover_from_ram()
        elif attack_phase==&"recover" and attack_time<=0: attack_phase=&"follow"
        var lane: float=clampf(pursuit_target.lateral_offset+(2.3*attack_side if attack_phase==&"warn" else 0.0),-3.35,3.35)
        if attack_phase==&"follow": lane=[-2.8,2.8,0.0][pursuit_role%3]
        elif attack_phase==&"recover": lane=attack_side*3.4
        if is_finite(evasion_lane): lane=evasion_lane
        target_x=center+lane
    var target_yaw := tangent+clampf((target_x-float(car.world_x))*.07,-.13,.13)
    var steer := clampf(RaceLevelData.steer_for_heading(target_yaw,ratio),-.97,.97)
    var target_speed := RaceMath.safe_corner_speed(at,track_x,RaceLevelData.PLAYER_MAX_SPEED*.92,RaceLevelData.NFS_MAX_HEADING_YAW,RaceLevelData.CORNER_GRIP_ACCEL)*lerpf(.93,1.0,effective_skill)
    if pursuit_target!=null:
        var dz: float=car.world_z-pursuit_target.world_z
        var desired_gap: float=[-2.0,2.0,-10.0][pursuit_role%3]
        if is_finite(evasion_lane): desired_gap=-10.0-pursuit_role*7.0
        if attack_phase in [&"warn",&"ram"]: desired_gap=0
        var chase_speed: float=clampf(pursuit_target.speed+(desired_gap-dz)*.7,8,RaceLevelData.PLAYER_MAX_SPEED)
        target_speed=minf(chase_speed,RaceMath.safe_corner_speed(at,track_x,RaceLevelData.PLAYER_MAX_SPEED,RaceLevelData.NFS_MAX_HEADING_YAW,RaceLevelData.CORNER_GRIP_ACCEL))
    var excess: float=float(car.speed)-target_speed
    var brake := clampf(excess/8.0,0.0,.65)
    var throttle := clampf((target_speed-float(car.speed))/4.0+.72,0.0,1.0)
    car.set_inputs(steer,throttle,brake)
