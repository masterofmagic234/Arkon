extends RefCounted
class_name RaceCameraState

const RaceLevelData = preload("res://scripts/race_level_data.gd")

# Level2's presentation-camera state. The Director owns the instance.
# Renderer and 240SX overlay consume it; neither owns chase-camera behavior.

const LATERAL_FOLLOW: float = 0.82
const LATERAL_SMOOTH: float = 7.0
const MAX_LATERAL_OFFSET: float = 1.1

var lateral_offset: float = 0.0
var target_lateral_offset: float = 0.0
var steer: float = 0.0
var speed_ratio: float = 0.0

func reset(race_car) -> void:
    if race_car == null:
        lateral_offset = 0.0
        target_lateral_offset = 0.0
        steer = 0.0
        speed_ratio = 0.0
        return

    target_lateral_offset = clampf(
        float(race_car.lateral_offset) * LATERAL_FOLLOW,
        -MAX_LATERAL_OFFSET,
        MAX_LATERAL_OFFSET
    )
    lateral_offset = target_lateral_offset
    steer = clampf(float(race_car.steer_in), -1.0, 1.0)
    speed_ratio = clampf(
        float(race_car.speed) / maxf(RaceLevelData.PLAYER_MAX_SPEED, 0.001),
        0.0,
        1.0
    )

func update_from_race_car(race_car, delta: float) -> void:
    if race_car == null:
        return

    target_lateral_offset = clampf(
        float(race_car.lateral_offset) * LATERAL_FOLLOW,
        -MAX_LATERAL_OFFSET,
        MAX_LATERAL_OFFSET
    )

    # Exponential smoothing keeps the camera response stable across render FPS.
    var blend := 1.0 - exp(-LATERAL_SMOOTH * maxf(delta, 0.0))
    lateral_offset = lerpf(lateral_offset, target_lateral_offset, blend)
    steer = clampf(float(race_car.steer_in), -1.0, 1.0)
    speed_ratio = clampf(
        float(race_car.speed) / maxf(RaceLevelData.PLAYER_MAX_SPEED, 0.001),
        0.0,
        1.0
    )
