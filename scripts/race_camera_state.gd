extends RefCounted
class_name RaceCameraState

const RaceLevelData = preload("res://scripts/race_level_data.gd")
const BEHIND := 6.0
const FOLLOW_RESPONSE := 7.5

# +Z is forward, +X is right. This is the ONLY gameplay camera owner.
# The renderer and model viewport consume the same yaw, roll and zoom.
var lateral_offset: float = 0.0
var target_lateral_offset: float = 0.0
var behind_distance: float = BEHIND
var steer: float = 0.0
var speed_ratio: float = 0.0
var yaw_offset: float = 0.0
var roll: float = 0.0
var zoom: float = 1.0
var horizon_offset: float = 0.0

func reset(race_car) -> void:
    lateral_offset = 0.0
    target_lateral_offset = 0.0
    behind_distance = BEHIND
    steer = 0.0
    speed_ratio = 0.0
    yaw_offset = 0.0
    roll = 0.0
    zoom = 1.0
    horizon_offset = 0.0
    if race_car != null:
        update_from_race_car(race_car, 0.0)
        lateral_offset = target_lateral_offset

func update_from_race_car(race_car, delta: float) -> void:
    if race_car == null:
        return
    steer = clampf(float(race_car.steer_applied), -1.0, 1.0)
    speed_ratio = clampf(float(race_car.speed) / RaceLevelData.PLAYER_MAX_SPEED, 0.0, 1.0)
    # Direction is bound to the nose. Only the camera boom position has inertia.
    yaw_offset = float(race_car.heading_yaw)
    behind_distance = BEHIND * cos(yaw_offset)
    target_lateral_offset = float(race_car.lateral_offset) - BEHIND * sin(yaw_offset)
    var blend := 1.0 - exp(-FOLLOW_RESPONSE * maxf(delta, 0.0))
    lateral_offset = lerpf(lateral_offset, target_lateral_offset, blend)
    roll = lerpf(roll, -steer * speed_ratio * deg_to_rad(1.0), blend)
    zoom = lerpf(zoom, lerpf(1.0, 0.94, speed_ratio), blend)
    horizon_offset = lerpf(horizon_offset, clampf(float(race_car.longitudinal_acceleration) / 40.0, -1.0, 1.0) * 0.008, blend)
