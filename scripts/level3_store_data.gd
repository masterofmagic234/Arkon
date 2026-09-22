extends RefCounted
class_name Level3StoreData

const TILE_SIZE: int = 48
const MAP: Array[String] = [
    "##############################",
    "#............#...............#",
    "#..####......#....###........#",
    "#..#..#......#....#.#........#",
    "#..#..#..........#.#..###....#",
    "#.....#######..#.#....#......#",
    "#..............#.#....#......#",
    "#######..####D#####.D#########",
    "#............................#",
    "#..###.....####.....###......#",
    "#..#........#.......#........#",
    "#..#........#.......#........#",
    "#..#####....#.......#####....#",
    "#............................#",
    "#....###.............###.....#",
    "#....#...............#.......#",
    "#...........###..............#",
    "#............................#",
    "##############################"
]

const PLAYER_SPAWN: Vector2i = Vector2i(2, 14)

const ENEMY_SPAWNS: Array[Dictionary] = [
    {"cell": Vector2i(8, 2), "kind": &"gunman", "patrol_radius": 88.0},
    {"cell": Vector2i(17, 2), "kind": &"gunman", "patrol_radius": 72.0},
    {"cell": Vector2i(23, 4), "kind": &"melee", "patrol_radius": 120.0},
    {"cell": Vector2i(25, 9), "kind": &"butcher", "patrol_radius": 90.0},
    {"cell": Vector2i(8, 12), "kind": &"melee", "patrol_radius": 96.0},
    {"cell": Vector2i(20, 15), "kind": &"gunman", "patrol_radius": 78.0}
]

const PICKUPS: Array[Dictionary] = [
    {"cell": Vector2i(4, 3), "kind": &"bottle"},
    {"cell": Vector2i(5, 14), "kind": &"bat"},
    {"cell": Vector2i(21, 10), "kind": &"shotgun"},
    {"cell": Vector2i(4, 16), "kind": &"pistol"}
]

const INTRO_DIALOGUE: Array[Dictionary] = [
    {"speaker": "КАРОЛИНА", "text": "Быстро заберу заказ — и домой."},
    {"speaker": "ПРОДАВЕЦ", "text": "Ночью магазин лучше бы не устраивать."},
    {"speaker": "КАРОЛИНА", "text": "Я только зайду, заберу своё и уйду."}
]

const CLEAR_DIALOGUE: Array[Dictionary] = [
    {"speaker": "КАРОЛИНА", "text": "Всё. Теперь точно домой."},
    {"speaker": "ДАРИНА", "text": "А жёлуди?"},
    {"speaker": "КАРОЛИНА", "text": "..." }
]

static func get_map() -> PackedStringArray:
    return PackedStringArray(MAP)

static func tile_size() -> int:
    return TILE_SIZE

static func player_spawn() -> Vector2i:
    return PLAYER_SPAWN

static func get_enemy_spawns() -> Array[Dictionary]:
    return ENEMY_SPAWNS

static func get_pickups() -> Array[Dictionary]:
    return PICKUPS

static func get_intro_dialogue() -> Array[Dictionary]:
    return INTRO_DIALOGUE

static func get_clear_dialogue() -> Array[Dictionary]:
    return CLEAR_DIALOGUE

static func map_size() -> Vector2i:
    return Vector2i(MAP[0].length(), MAP.size())

static func cell_to_world(cell: Vector2i) -> Vector2:
    return Vector2(
        float(cell.x * TILE_SIZE) + float(TILE_SIZE) * 0.5,
        float(cell.y * TILE_SIZE) + float(TILE_SIZE) * 0.5
    )

static func world_to_cell(world: Vector2) -> Vector2i:
    return Vector2i(
        int(floor(world.x / float(TILE_SIZE))),
        int(floor(world.y / float(TILE_SIZE)))
    )

static func is_inside(cell: Vector2i) -> bool:
    return (
        cell.x >= 0
        and cell.y >= 0
        and cell.y < MAP.size()
        and cell.x < MAP[cell.y].length()
    )

static func tile_at(cell: Vector2i) -> String:
    if not is_inside(cell):
        return "#"
    return String(MAP[cell.y][cell.x])

static func is_walkable(cell: Vector2i) -> bool:
    return tile_at(cell) != "#"

static func get_door_cells() -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for y in range(MAP.size()):
        for x in range(MAP[y].length()):
            if MAP[y][x] == "D":
                result.append(Vector2i(x, y))
    return result
