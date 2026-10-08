extends RefCounted
class_name RaceCameraState

const RaceLevelData = preload("res://scripts/race_level_data.gd")

# Level2's presentation-camera state. The Director owns the instance.
# Renderer and 240SX overlay consume it; neither owns chase-camera behavior.

const LATERAL_FOLLOW: float = 0.82
const LATERAL_SMOOTH: float = 7.0
const NFS_LATERAL_FOLLOW: float = 0.72
const NFS_LATERAL_SMOOTH: float = 5.5
const NFS_LOOK_AHEAD_MAX: float = 3.5
const NFS_YAW_MAX: float = 0.10
const NFS_ROLL_MAX: float = 2.2 * PI / 180.0
const NFS_SPEED_ZOOM_MAX: float = 1.06
const MAX_LATERAL_OFFSET: float = 1.1

var lateral_offset: float = 0.0
var target_lateral_offset: float = 0.0
var steer: float = 0.0
var speed_ratio: float = 0.0
var look_ahead_offset: float = 0.0
var yaw_offset: float = 0.0
var roll: float = 0.0
var zoom: float = 1.0

func reset(race_car) -> void:
    if race_car == null:
        lateral_offset = 0.0
        target_lateral_offset = 0.0
        steer = 0.0
        speed_ratio = 0.0
        return

    var follow := LATERAL_FOLLOW
    if RaceLevelData.ACTIVE_HANDLING_PROFILE == RaceLevelData.HandlingProfile.NFS_UNDERGROUND2:
        follow = NFS_LATERAL_FOLLOW

    target_lateral_offset = clampf(
        float(race_car.lateral_offset) * follow,
        -MAX_LATERAL_OFFSET,
        MAX_LATERAL_OFFSET
    )
    lateral_offset = target_lateral_offset
    steer = clampf(float(race_car.steer_applied), -1.0, 1.0)
    speed_ratio = clampf(
        float(race_car.speed) / maxf(RaceLevelData.PLAYER_MAX_SPEED, 0.001),
        0.0,
        1.0
    )
    look_ahead_offset = 0.0
    yaw_offset = 0.0
    roll = 0.0
    zoom = 1.0
    if RaceLevelData.ACTIVE_HANDLING_PROFILE == RaceLevelData.HandlingProfile.NFS_UNDERGROUND2:
        look_ahead_offset = steer * speed_ratio * NFS_LOOK_AHEAD_MAX
        yaw_offset = clampf(
            float(race_car.heading_yaw) * 0.78,
            -NFS_YAW_MAX,
            NFS_YAW_MAX
        )
        roll = clampf(
            -steer * speed_ratio * NFS_ROLL_MAX,
            -NFS_ROLL_MAX,
            NFS_ROLL_MAX
        )
        zoom = lerpf(1.0, NFS_SPEED_ZOOM_MAX, speed_ratio)

func update_from_race_car(race_car, delta: float) -> void:
    if race_car == null:
        return

    var follow := LATERAL_FOLLOW
    var smooth := LATERAL_SMOOTH
    if RaceLevelData.ACTIVE_HANDLING_PROFILE == RaceLevelData.HandlingProfile.NFS_UNDERGROUND2:
        follow = NFS_LATERAL_FOLLOW
        smooth = NFS_LATERAL_SMOOTH

    target_lateral_offset = clampf(
        float(race_car.lateral_offset) * follow,
        -MAX_LATERAL_OFFSET,
        MAX_LATERAL_OFFSET
    )

    # Exponential smoothing keeps the chase response stable across render FPS.
    var blend := 1.0 - exp(-smooth * maxf(delta, 0.0))
    lateral_offset = lerpf(lateral_offset, target_lateral_offset, blend)
    steer = clampf(float(race_car.steer_applied), -1.0, 1.0)
    speed_ratio = clampf(
        float(race_car.speed) / maxf(RaceLevelData.PLAYER_MAX_SPEED, 0.001),
        0.0,
        1.0
    )

    if RaceLevelData.ACTIVE_HANDLING_PROFILE == RaceLevelData.HandlingProfile.NFS_UNDERGROUND2:
        look_ahead_offset = lerpf(
            look_ahead_offset,
            steer * speed_ratio * NFS_LOOK_AHEAD_MAX,
            blend
        )
        yaw_offset = lerpf(
            yaw_offset,
            clampf(
                float(race_car.heading_yaw) * 0.30,
                -NFS_YAW_MAX,
                NFS_YAW_MAX
            ),
            blend
        )
        roll = lerpf(
            roll,
            clampf(
                -steer * speed_ratio * NFS_ROLL_MAX,
                -NFS_ROLL_MAX,
                NFS_ROLL_MAX
            ),
            blend
        )
        zoom = lerpf(
            zoom,
            lerpf(1.0, NFS_SPEED_ZOOM_MAX, speed_ratio),
            blend
        )
    else:
        look_ahead_offset = 0.0
        yaw_offset = 0.0
        roll = 0.0
        zoom = 1.0
