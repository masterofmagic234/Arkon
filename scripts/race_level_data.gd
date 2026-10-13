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

const IS_SPRINT := true
const TOTAL_LAPS := 1
const GRID_SPACING := 7.0
const PLAYER_GRID_SLOT := 3
# Boundaries are world metres. Objects choose their own sector, so the next
# location appears in the distance before the car actually enters it.
const BRIDGE_START := 2080.0
const BRIDGE_END := 2720.0
const TUNNEL_START := 3280.0
const TUNNEL_END := 4080.0
const SECTOR_STARTS := [0.0, 960.0, BRIDGE_START, BRIDGE_END, TUNNEL_START, TUNNEL_END]
const SECTOR_NAMES := ["ЛЕСНАЯ ОКРАИНА", "ЗОЛОТЫЕ ПОЛЯ", "ЛУННЫЙ МОСТ", "ГОРНЫЙ СПУСК", "ГОРНЫЙ ТОННЕЛЬ", "ОГНИ ГОРОДА"]
# Metres, shared by the main camera, road, vehicles and roadside architecture.
const ELEVATION_Z := [0.0,1640.0,2080.0,2480.0,2720.0,2920.0,3280.0,4080.0,4440.0,4800.0]
const ELEVATION_Y := [0.0,0.0,18.0,20.0,18.0,16.0,-12.0,-12.0,0.0,0.0]
static func road_height(world_z: float) -> float:
    for i in range(1,ELEVATION_Z.size()):
        if world_z<=ELEVATION_Z[i]:
            var t := clampf((world_z-ELEVATION_Z[i-1])/(ELEVATION_Z[i]-ELEVATION_Z[i-1]),0.0,1.0)
            return lerpf(ELEVATION_Y[i-1],ELEVATION_Y[i],(1.0-cos(PI*t))*0.5)
    return ELEVATION_Y[-1]
static func road_grade(world_z: float) -> float:
    for i in range(1,ELEVATION_Z.size()):
        if world_z<=ELEVATION_Z[i]:
            var span: float=ELEVATION_Z[i]-ELEVATION_Z[i-1]
            var t := clampf((world_z-ELEVATION_Z[i-1])/span,0.0,1.0)
            return (ELEVATION_Y[i]-ELEVATION_Y[i-1])*PI*sin(PI*t)/(2.0*span)
    return 0.0
static func sector_at(world_z: float) -> int:
    for i in range(SECTOR_STARTS.size()-1,-1,-1):
        if world_z>=SECTOR_STARTS[i]: return i
    return 0
static func route_length() -> float:
    return TRACK_DATA.total_segments()*SEGMENT_HEIGHT
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
# Heading is measured clockwise from +Z, like movement and projection.
const NFS_MAX_HEADING_YAW := 0.65

# Fixed simulation inside _process(); rendering interpolates between states.
const SIMULATION_HZ := 60.0
const SIMULATION_STEP := 1.0 / SIMULATION_HZ
const MAX_FRAME_DELTA := 0.25

# Relative-lateral arcade handling.
# Positive curve bends right; the car is pushed outward to the left.
const CENTRIFUGAL_FORCE := 0.022

const PLAYER_STEER_RESPONSE := 9.0

const OFFROAD_VEHICLE_HALF_WIDTH := 0.85
const OFFROAD_ASPHALT_MARGIN := 0.25
const OFFROAD_SHOULDER := 2.2
const OFFROAD_SOFT_PENALTY := 4.0
const OFFROAD_HARD_PENALTY := 8.0
const OFFROAD_MIN_DRIVE_SPEED := 6.0

const AI_SKILLS := [0.86, 0.78, 0.70]
const AI_LOOKAHEAD := 8

const ACORN_PICKUPS := [
    [12, 0], [22, 3], [40, 1], [58, 2], [72, 0], [90, 3], [110, 1],
]
