class_name LevelData
extends RefCounted

# EXPERIMENTAL LEVEL 1 — dense 56x16 four-zone labyrinth.
# Runtime state remains outside this data module.

const CELL_SIZE := 1.8
const MAP_WIDTH := 56
const MAP_HEIGHT := 16
const MAP_WORLD_ORIGIN := Vector2(-50.4, -13.5)

const ACORN_COUNT := 8
const KEY_COUNT := 3

const WALK_SPEED := 4.2
const TURN_SPEED := 2.15
const JOYSTICK_RADIUS := 58.0
const ACORN_PICKUP_RADIUS := 1.25
const KEY_PICKUP_RADIUS := 1.4
const SQUIRREL_ATTACK_DISTANCE := 1.0
const FIRE_RANGE := 30.0

const SQUIRREL_LAYER := 2
const WORLD_LAYER := 1

const MAX_AMMO := 38
const MAX_HP := 100

const ACORN_NAMES := [
    "Acorn01", "Acorn02", "Acorn03", "Acorn04",
    "Acorn05", "Acorn06", "Acorn07", "Acorn08"
]
const KEY_NAMES := ["Key01", "Key02", "Key03"]
const DOOR_NAMES := ["Door01", "Door02", "Door03"]

# Door cells correspond to the authored gateway positions in the experiment.
const DOOR_CELLS := [Vector2i(12, 13), Vector2i(26, 13), Vector2i(40, 1)]

const SQUIRREL_NAMES := [
    "Squirrel01", "Squirrel02", "Squirrel03", "Squirrel04",
    "Squirrel05", "Squirrel06", "Squirrel07", "Squirrel08",
    "Squirrel09", "Squirrel10", "Squirrel11", "Squirrel12"
]

const SQUIRREL_HP := {
    "Squirrel01": 2, "Squirrel02": 2, "Squirrel03": 1,
    "Squirrel04": 4, "Squirrel05": 1, "Squirrel06": 1,
    "Squirrel07": 2, "Squirrel08": 1, "Squirrel09": 4,
    "Squirrel10": 1, "Squirrel11": 2, "Squirrel12": 1
}

# Home points are snapped to open cells of the supplied matrix so no AI spawns
# inside a wall. The intended locations remain in the same visual zone.
const SQUIRREL_HOME := {
    "Squirrel01": Vector2(-41.4, -4.5),
    "Squirrel02": Vector2(-45.0, 2.7),
    "Squirrel03": Vector2(-37.8, 9.9),

    "Squirrel04": Vector2(-18.0, -4.5),
    "Squirrel05": Vector2(-12.6, 2.7),
    "Squirrel06": Vector2(-18.0, 6.3),

    "Squirrel07": Vector2(5.4, -4.5),
    "Squirrel08": Vector2(12.6, 2.7),
    "Squirrel09": Vector2(5.4, 9.9),

    "Squirrel10": Vector2(30.6, -4.5),
    "Squirrel11": Vector2(39.6, 2.7),
    "Squirrel12": Vector2(32.4, 9.9)
}

const SQUIRREL_PHASE := {
    "Squirrel01": 0.0, "Squirrel02": 1.1, "Squirrel03": 2.2,
    "Squirrel04": 3.3, "Squirrel05": 4.4, "Squirrel06": 5.5,
    "Squirrel07": 0.5, "Squirrel08": 1.6, "Squirrel09": 2.7,
    "Squirrel10": 3.8, "Squirrel11": 4.9, "Squirrel12": 6.0
}

const ACORN_LINES := [
    "Отлично. Еще один.",
    "Желудь. Зачем я это делаю?",
    "Собрано %d.",
    "Надеюсь, Дарина будет довольна.",
    "Осталось немного.",
    "Какой абсурд."
]

const CONE_LINES := [
    "Ай! Фальшивка!",
    "Это была растяжка?!",
    "Минус 12 ХП. Опасные шишки.",
    "Кто заминировал лес?",
    "Надо смотреть под ноги."
]

const HIT_LINES := ["Попала.", "Есть.", "Минус один.", "Готов.", "Отдыхай."]
const STUN_LINES := ["Оглушен.", "Поспи.", "Не вставай.", "Отключился.", "В нокауте."]
const DAMAGE_LINES := ["Аргх!", "Больно!", "Зацепило!", "Черт!"]

# Плотная 56x16 матрица без неиспользуемых пустот.
const CANONICAL_MAP := [
    "########################################################",
    "#.......#.....#.........#.....#.......#.........#......#",
    "#.#####.###.#.#.#######.#.###.#.#####.#.#######.#.####.#",
    "#...#.....#.#.#.......#.#...#.#...#...#.#.....#.#....#.#",
    "###.#.###.#.#.#######.#.###.#.###.#.###.#.###.#.####.#.#",
    "#...#.#...#.#.......#.#...#.#...#.#...#.#.#...#....#.#.#",
    "#.###.#.###.#######.#.###.#.###.#.#.#.######.#.#.#.#.#.#",
    "#.#...#...#.........#...#.#...#.#.#.#......#.#.#.#.#.#.#",
    "#.#.#####.#############.#.###.#.###.#.#.#.######.#.#.#.#",
    "#.#.....#.#...........#.#...#.#...#.#.#.#......#.#.#.#.#",
    "#.#####.#.#.#########.#.###.#.###.#.#.#.######.#.#.#.#.#",
    "#.....#.#.#.#.......#.#...#.#...#.#...#......#.#...#...#",
    "#####.#.#.#.#.#####.#.###.#.###.#.##########.#.#######.#",
    "#.......#...#.......#.....#.....#............#.........#",
    "#.####################################################.#",
    "########################################################"
]
