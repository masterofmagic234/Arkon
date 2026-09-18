extends RefCounted

# Состояние одной машины Level 2.

const RaceMath = preload("res://scripts/race_math.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")

var is_player: bool = false
var world_x: float = 0.0
var world_z: float = 0.0
var speed: float = 0.0
var steer_in: float = 0.0
var throttle: float = 0.0
var brake_in: float = 0.0
var grid_index: int = 0\nvar segment_index: int = 0
var segment_progress: float = 0.0
var last_segment_index: int = -1
var lap: int = 0
var position: int = 1
var finish_time: float = -1.0
var sprite_yaw: float = 0.0

func setup(player_flag: bool) -> void:
    is_player = player_flag

func place_on_grid(grid_index: int, lane_x: float, track_x: PackedFloat32Array) -> void:
    segment_index = 0
    segment_progress = -float(grid_slot) * 0.6
    world_x = track_x[0] + lane_x
    world_z = -float(grid_slot) * 0.6 * RaceLevelData.SEGMENT_HEIGHT

func set_inputs(steer: float, th: float, br: float) -> void:
    steer_in = clampf(steer, -1.0, 1.0)
    throttle = clampf(th, 0.0, 1.0)
    brake_in = clampf(br, 0.0, 1.0)

func tick(delta: float, allow_control: bool, track_pattern: Array, track_x: PackedFloat32Array) -> void:
    var max_speed: float = RaceLevelData.PLAYER_MAX_SPEED
    if not is_player:
        max_speed *= 0.92

    if allow_control:
        speed = RaceMath.step_speed(speed, throttle, brake_in, delta, max_speed, RaceLevelData.PLAYER_ACCEL, RaceLevelData.PLAYER_BRAKE, RaceLevelData.PLAYER_DRAG)
        var d := RaceMath.steering_delta(steer_in, speed, delta, RaceLevelData.PLAYER_STEER_RATE, max_speed)
        world_x += d * maxf(speed, 4.0) * 0.08
    else:
        speed = maxf(speed - 6.0 * delta, 0.0)

    var advance: float = speed * delta / RaceLevelData.SEGMENT_HEIGHT
    segment_progress += advance
    while segment_progress >= 1.0:
        segment_progress -= 1.0
        last_segment_index = segment_index
        segment_index += 1
        if segment_index >= track_pattern.size():
            segment_index = 0
            lap += 1

    var center: float = track_x[segment_index]
    var half: float = RaceLevelData.ROAD_WIDTH * 0.5
    if absf(world_x - center) > half:
        speed *= 0.985

    world_z = float(segment_index) * RaceLevelData.SEGMENT_HEIGHT + segment_progress * RaceLevelData.SEGMENT_HEIGHT
    var target_yaw := -steer_in * 0.35
    sprite_yaw = lerpf(sprite_yaw, target_yaw, clampf(delta * 8.0, 0.0, 1.0))

func progress(track_size: int) -> float:
    return float(lap) * float(track_size) + float(segment_index) + segment_progress
