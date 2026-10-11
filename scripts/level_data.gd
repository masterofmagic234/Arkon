class_name LevelData
extends RefCounted

# Level configuration and static data. Runtime state remains in game.gd.
# This module is deliberately data-only so changing level configuration does not
# change input, physics, scene, or presentation code.

const CELL_SIZE := 1.8
const MAP_WIDTH := 48
const MAP_HEIGHT := 36
const MAP_WORLD_ORIGIN := Vector2(-42.3, -31.5)
const ACORN_COUNT := 6
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

static func world_to_cell(world_x: float, world_z: float) -> Vector2i:
    return Vector2i(
        int(floor((world_x - MAP_WORLD_ORIGIN.x) / CELL_SIZE + 0.5)),
        int(floor((world_z - MAP_WORLD_ORIGIN.y) / CELL_SIZE + 0.5))
    )

static func cell_center_world(cell: Vector2i) -> Vector3:
    return Vector3(
        MAP_WORLD_ORIGIN.x + float(cell.x) * CELL_SIZE,
        0.0,
        MAP_WORLD_ORIGIN.y + float(cell.y) * CELL_SIZE
    )

static func cell_bounds_world(cell: Vector2i) -> Rect2:
    var center := cell_center_world(cell)
    var half := CELL_SIZE * 0.5
    return Rect2(
        center.x - half,
        center.z - half,
        CELL_SIZE,
        CELL_SIZE
    )

const ACORN_NAMES := ["Acorn01", "Acorn02", "Acorn03", "Acorn04", "Acorn05", "Acorn06"]
const KEY_NAMES := ["Key01", "Key02", "Key03"]
const DOOR_NAMES := ["Door01", "Door02", "Door03"]
const DOOR_CELLS := [Vector2i(12, 18), Vector2i(24, 8), Vector2i(36, 18)]

const SQUIRREL_NAMES := ["Squirrel01", "Squirrel02", "Squirrel03", "Squirrel04", "Squirrel05"]

const ACORN_LINES := [
    "ЖЁЛУДЬ ДОБЫТ. Дарина, ставь чайник.",
    "Один есть. Белки нервничают.",
    "Исторический жёлудь №%d.",
    "Данил сообщает: прогресс подозрительно хороший.",
    "В карман! И никому не отдавать.",
    "Найден. Официально настоящий.",
    "Ещё один — и можно открывать музей.",
    "Жёлудь найден. Серьёзная археология."
]
const CONE_LINES := [
    "ЭТО ШИШКА. Лес тебя переиграл.",
    "Поздравляю: ты нашла не то.",
    "Дарина просила жёлуди, а не ботанику.",
    "Шишка нанесла 12 урона самолюбию.",
    "Неправильный орех. Очень неправильный.",
    "Каролина, это буквально НЕ ЖЁЛУДЬ.",
    "Лес говорит: внимательнее, пожалуйста."
]
const HIT_LINES := [
    "ПОПАЛА. Белка задумалась о жизни.",
    "Белка получила аргумент.",
    "Точно в пушистую проблему.",
    "Попадание! Белка пересматривает карьеру.",
    "Минус одна попытка украсть жёлудь.",
    "Белка: это было неожиданно.",
    "Тихо. Я всё видела. Отличный выстрел."
]
const STUN_LINES := [
    "Белка контужена. Звёздочки прилагаются.",
    "Белка прилегла подумать.",
    "Пушистый отпуск объявлен досрочно.",
    "Белка временно недееспособна. Достойно.",
    "Она не мёртвая. Она просто очень впечатлена.",
    "Звёздочки — официальный эффект поражения.",
    "Белка выбыла. Жёлуди в безопасности."
]
const DAMAGE_LINES := [
    "АЙ! Белка кусается.",
    "Урон. Пушистый террор продолжается.",
    "Белка сказала: не подходи.",
    "Это было больно. Очень по-беличьи."
]

const CANONICAL_MAP := [
    "################################################",
    "################################################",
    "##......................#.....................##",
    "##...#..................#.....................##",
    "##..###.................#.............#####...##",
    "##...#..................#....#........#####...##",
    "##........#.............#....#.....#..........##",
    "##......#####...........#....#....###.........##",
    "##......######...............#.....#..........##",
    "##.....#######..........#....#..........####..##",
    "##......#######.........#....#..........####..##",
    "##......######..........#....#................##",
    "##.......#####...####...#....#####............##",
    "##.........#.....####...#.....................##",
    "##...............####...#.....................##",
    "##...............####...#..####...............##",
    "##......................#..####...............##",
    "##......................#.....................##",
    "############.#######################.###########",
    "##......................#.....................##",
    "##...............######.#.....................##",
    "##...............######.#..................#..##",
    "##...............######.#.................###.##",
    "#######.................#...####...........#..##",
    "#######.................#...####..............##",
    "#######.................#...####..............##",
    "##..............####....#.....................##",
    "##..............####....#.............#.......##",
    "##.......#......####....#.....................##",
    "##..............####....#.###.................##",
    "##..............####....#.###.................##",
    "##..............####....#.###.................##",
    "##......................#.###.................##",
    "##......................#.###.................##",
    "################################################",
    "################################################",
]

const PARK_CELLS := {
    "Player": Vector2i(5, 30),
    "Acorn01": Vector2i(7, 28),
    "Acorn02": Vector2i(14, 24),
    "Acorn03": Vector2i(16, 5),
    "Acorn04": Vector2i(34, 9),
    "Acorn05": Vector2i(42, 14),
    "Acorn06": Vector2i(38, 25),
    "Key01": Vector2i(20, 24),
    "Key02": Vector2i(19, 6),
    "Key03": Vector2i(43, 13),
    "Squirrel01": Vector2i(12, 27),
    "Squirrel02": Vector2i(19, 24),
    "Squirrel03": Vector2i(15, 8),
    "Squirrel04": Vector2i(35, 10),
    "Squirrel05": Vector2i(36, 24),
    "FakePineCone": Vector2i(5, 7),
    "Exit": Vector2i(43, 31),
    "Secret": Vector2i(4, 3),
}

const PATH_CELLS := [Vector2i(5,30),Vector2i(7,28),Vector2i(14,27),Vector2i(14,24),Vector2i(20,24),Vector2i(14,23),Vector2i(12,21),Vector2i(12,18),Vector2i(14,15),Vector2i(16,12),Vector2i(17,9),Vector2i(16,5),Vector2i(19,6),Vector2i(21,8),Vector2i(24,8),Vector2i(27,8),Vector2i(32,9),Vector2i(34,9),Vector2i(36,12),Vector2i(42,14),Vector2i(36,16),Vector2i(36,18),Vector2i(35,22),Vector2i(38,25),Vector2i(40,28),Vector2i(43,31)]

static func park_position(id: String, height: float = 0.0) -> Vector3:
    var p := cell_center_world(PARK_CELLS[id])
    p.y = height
    return p

static func episode_at(world: Vector3) -> int:
    var c := world_to_cell(world.x, world.z)
    if c.x < 24:
        return 0 if c.y > 18 else 1
    return 3 if c.y > 18 else 2

static func is_pond(cell: Vector2i) -> bool:
    return (Vector2(cell) - Vector2(10, 9)).length() <= 3.0 or (Vector2(cell) - Vector2(11, 10)).length() <= 3.0

static func on_gravel(world: Vector3) -> bool:
    var p := Vector2(world.x,world.z)
    for i in range(1,PATH_CELLS.size()):
        var a3 := cell_center_world(PATH_CELLS[i-1])
        var b3 := cell_center_world(PATH_CELLS[i])
        var a := Vector2(a3.x,a3.z)
        var b := Vector2(b3.x,b3.z)
        var line := b-a
        var closest := a+line*clampf((p-a).dot(line)/maxf(line.length_squared(),0.001),0.0,1.0)
        if p.distance_squared_to(closest)<1.05: return true
    return false
