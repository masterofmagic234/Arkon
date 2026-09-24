extends RefCounted

# Level 2 — ACORN GRAND PRIX. Все константы тюнинга здесь.

const SEGMENT_HEIGHT := 40.0
const ROAD_WIDTH := 9.0
const LANE_OFFSETS := [-2.7, -0.9, 0.9, 2.7]

enum Seg { STRAIGHT, CURVE_L, CURVE_R, HAIRPIN_L, HAIRPIN_R, CHICANE }

const TRACK_DATA = preload("res://resources/race/race_track_default.tres")

static func get_track_pattern() -> Array:
    return TRACK_DATA.build_pattern()

const TRACK_PATTERN_LEGACY_REMOVED := []

# Track shape is authored by RaceTrackData sections.

const TOTAL_LAPS := 3
const RACER_COUNT := 4

const PLAYER_MAX_SPEED := 32.0
const PLAYER_ACCEL := 18.0
const PLAYER_BRAKE := 42.0
const PLAYER_DRAG := 0.55
const PLAYER_STEER_RATE := 6.0

const AI_SKILLS := [0.86, 0.78, 0.70]
const AI_LOOKAHEAD := 8

const ACORN_PICKUPS := [
    [12, 0], [22, 3], [40, 1], [58, 2], [72, 0], [90, 3], [110, 1],
]
