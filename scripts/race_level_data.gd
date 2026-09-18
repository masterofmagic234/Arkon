extends RefCounted

# Level 2 — ACORN GRAND PRIX. Все константы тюнинга здесь.

const SEGMENT_HEIGHT := 1.8
const ROAD_WIDTH := 9.0
const LANE_OFFSETS := [-2.7, -0.9, 0.9, 2.7]

enum Seg { STRAIGHT, CURVE_L, CURVE_R, HAIRPIN_L, HAIRPIN_R, CHICANE }

const TRACK_PATTERN := [
    # Стартовая прямая
    Seg.STRAIGHT, Seg.STRAIGHT, Seg.STRAIGHT, Seg.STRAIGHT, Seg.STRAIGHT,
    # Плавный левый
    Seg.CURVE_L, Seg.CURVE_L, Seg.CURVE_L, Seg.CURVE_L, Seg.CURVE_L,
    # Короткая прямая
    Seg.STRAIGHT, Seg.STRAIGHT,
    # Правый с шпилькой
    Seg.CURVE_R, Seg.CURVE_R, Seg.CURVE_R, Seg.HAIRPIN_R, Seg.HAIRPIN_R,
    # Прямая с шиканой
    Seg.STRAIGHT, Seg.STRAIGHT, Seg.CHICANE, Seg.CHICANE, Seg.CHICANE,
    Seg.STRAIGHT, Seg.STRAIGHT,
    # Длинный левый
    Seg.CURVE_L, Seg.CURVE_L, Seg.CURVE_L, Seg.CURVE_L, Seg.CURVE_L,
    Seg.CURVE_L, Seg.CURVE_L,
    # Прямая
    Seg.STRAIGHT, Seg.STRAIGHT, Seg.STRAIGHT,
    # Правый
    Seg.CURVE_R, Seg.CURVE_R, Seg.CURVE_R,
    # Шпилька левая
    Seg.HAIRPIN_L, Seg.HAIRPIN_L,
    # Прямая
    Seg.STRAIGHT, Seg.STRAIGHT,
    # Шикана
    Seg.CHICANE, Seg.CHICANE,
    # Корректирующая секция перед финишем — замыкает накопленное смещение трассы
    Seg.CHICANE, Seg.CHICANE, Seg.CHICANE,
    Seg.STRAIGHT, Seg.STRAIGHT, Seg.STRAIGHT,
    # Финишная прямая
    Seg.STRAIGHT, Seg.STRAIGHT, Seg.STRAIGHT, Seg.STRAIGHT, Seg.STRAIGHT,
    Seg.STRAIGHT, Seg.STRAIGHT, Seg.STRAIGHT, Seg.STRAIGHT,
]

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
