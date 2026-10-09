extends RefCounted

# Level 2 — ACORN GRAND PRIX tuning data.

const SEGMENT_HEIGHT := 40.0
const ROAD_WIDTH := 9.0
const LANE_OFFSETS := [-2.7, -0.9, 0.9, 2.7]

enum Seg { STRAIGHT, CURVE_L, CURVE_R, HAIRPIN_L, HAIRPIN_R, CHICANE }
enum HandlingProfile { NES_TRIBUTE, NFS_UNDERGROUND2 }

# Active Level2 feel. Switch to NES_TRIBUTE to keep the original tribute response
# while retaining the same pseudo-3D renderer and camera-state architecture.
const ACTIVE_HANDLING_PROFILE: int = HandlingProfile.NFS_UNDERGROUND2

const TRACK_DATA = preload("res://resources/race/race_track_default.tres")

static func get_track_pattern() -> Array:
    return TRACK_DATA.build_pattern()

const TOTAL_LAPS := 3
const RACER_COUNT := 4

const PLAYER_MAX_SPEED_KMH := 219.0
# The previous 32.0 simulation units represented 100 km/h.
const SPEED_UNITS_PER_KMH := 32.0 / 100.0
const PLAYER_MAX_SPEED := PLAYER_MAX_SPEED_KMH * SPEED_UNITS_PER_KMH
const PLAYER_ACCEL := 16.0
const PLAYER_BRAKE := 40.0
const PLAYER_DRAG := 0.55
const PLAYER_STEER_RATE := 6.4
const NFS_STEER_INPUT_RESPONSE := 8.0
const NFS_LATERAL_GRIP_RESPONSE := 9.0
const NFS_LOW_SPEED_LATERAL_LOCK := 0.8
const NFS_HEADING_RESPONSE := 7.0
# Strong enough to show the 240SX's direction through a corner.
const NFS_MAX_HEADING_YAW := 0.48

# Fixed simulation inside _process(); rendering interpolates between states.
const SIMULATION_HZ := 60.0
const SIMULATION_STEP := 1.0 / SIMULATION_HZ
const MAX_FRAME_DELTA := 0.25

# Relative-lateral arcade handling.
# Positive curve bends right; the car is pushed outward to the left.
const CENTRIFUGAL_FORCE := 0.022

const PLAYER_STEER_RESPONSE := 9.0

const OFFROAD_VEHICLE_HALF_WIDTH := 2.0
const OFFROAD_ASPHALT_MARGIN := 1.4
const OFFROAD_SHOULDER := 2.2
const OFFROAD_SOFT_PENALTY := 4.0
const OFFROAD_HARD_PENALTY := 8.0
const OFFROAD_MIN_DRIVE_SPEED := 6.0

const AI_SKILLS := [0.86, 0.78, 0.70]
const AI_LOOKAHEAD := 8

const ACORN_PICKUPS := [
    [12, 0], [22, 3], [40, 1], [58, 2], [72, 0], [90, 3], [110, 1],
]
