extends RefCounted
class_name Level3StoreData

const TILE_SIZE: int = 48
const MAP: Array[String] = [
    "################################",
    "#...........#........#.........#",
    "#...........#........#.........#",
    "#...........D........#.........#",
    "#...........#........D.........#",
    "#...........#........#.........#",
    "#...........#........#.........#",
    "######D#########D#########D#####",
    "#.......#.............#........#",
    "#.......#.............#........#",
    "#.......#.............#........#",
    "#.......D.............#........#",
    "#.......#.............D........#",
    "#.......#.............#........#",
    "#.......#.............#........#",
    "####D###.............#####D#####",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "################################"
]

const PLAYER_SPAWN: Vector2i = Vector2i(2, 17)

const ENEMY_SPAWNS: Array[Dictionary] = [
    {"cell": Vector2i(7, 2), "kind": &"gunman", "patrol_radius": 74.0},
    {"cell": Vector2i(23, 5), "kind": &"gunman", "patrol_radius": 90.0},
    {"cell": Vector2i(26, 12), "kind": &"melee", "patrol_radius": 72.0},
    {"cell": Vector2i(3, 10), "kind": &"melee", "patrol_radius": 72.0},
    {"cell": Vector2i(24, 17), "kind": &"butcher", "patrol_radius": 74.0},
    {"cell": Vector2i(16, 12), "kind": &"gunman", "patrol_radius": 82.0}
]

const PICKUPS: Array[Dictionary] = [
    {"cell": Vector2i(5, 4), "kind": &"bottle"},
    {"cell": Vector2i(10, 16), "kind": &"bat"},
    {"cell": Vector2i(20, 14), "kind": &"shotgun"},
    {"cell": Vector2i(25, 9), "kind": &"pistol"}
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

static func get_furniture_layout() -> Array[Dictionary]:
    return [
        {
            "texture": "res://assets/level3/source/Furniture/sprKitchenCounter.png",
            "position": Vector2(4.5, 1.65),
            "scale": Vector2(1.45, 1.45),
            "z": 2,
            "collision": Rect2(2.4, 1.18, 4.8, 0.78)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprKitchenSinkDown_strip5.png",
            "position": Vector2(8.25, 1.62),
            "scale": Vector2(0.92, 0.92),
            "z": 2,
            "collision": Rect2(7.75, 1.20, 1.05, 0.72)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprWokKitchen_strip4.png",
            "position": Vector2(10.25, 1.70),
            "scale": Vector2(0.95, 0.95),
            "z": 3,
            "collision": Rect2(9.65, 1.18, 1.15, 0.86)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprStoreShelf_strip3.png",
            "position": Vector2(15.2, 1.62),
            "scale": Vector2(0.88, 0.88),
            "z": 2,
            "collision": Rect2(13.8, 1.18, 2.55, 0.72)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprRegister.png",
            "position": Vector2(25.45, 1.70),
            "scale": Vector2(0.95, 0.95),
            "z": 3,
            "collision": Rect2(24.75, 1.18, 1.35, 0.74)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprFreezer_strip2.png",
            "position": Vector2(28.3, 3.55),
            "scale": Vector2(0.90, 0.90),
            "z": 3,
            "collision": Rect2(27.55, 2.55, 1.32, 1.38)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprStoreShelf_strip3.png",
            "position": Vector2(2.0, 13.15),
            "scale": Vector2(0.84, 0.84),
            "z": 2,
            "collision": Rect2(1.25, 12.10, 1.15, 2.10)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprVendingMachine.png",
            "position": Vector2(29.0, 9.65),
            "scale": Vector2(1.35, 1.35),
            "z": 4,
            "collision": Rect2(28.18, 8.75, 1.35, 1.75)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprFreezer_strip2.png",
            "position": Vector2(28.35, 13.05),
            "scale": Vector2(0.90, 0.90),
            "z": 4,
            "collision": Rect2(27.60, 12.25, 1.35, 1.35)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprNoodleTable_strip3.png",
            "position": Vector2(4.55, 11.05),
            "scale": Vector2(0.92, 0.92),
            "z": 3,
            "collision": Rect2(3.70, 10.50, 1.62, 0.88)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprNoodleTable_strip3.png",
            "position": Vector2(11.65, 10.20),
            "scale": Vector2(0.92, 0.92),
            "z": 3,
            "collision": Rect2(10.80, 9.68, 1.62, 0.88)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprNoodleTable_strip3.png",
            "position": Vector2(17.05, 10.20),
            "scale": Vector2(0.92, 0.92),
            "z": 3,
            "collision": Rect2(16.20, 9.68, 1.62, 0.88)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprNoodleTable_strip3.png",
            "position": Vector2(12.65, 15.05),
            "scale": Vector2(0.92, 0.92),
            "z": 3,
            "collision": Rect2(11.80, 14.52, 1.62, 0.88)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprNoodleTable_strip3.png",
            "position": Vector2(18.15, 15.05),
            "scale": Vector2(0.92, 0.92),
            "z": 3,
            "collision": Rect2(17.30, 14.52, 1.62, 0.88)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprNoodleTable_strip3.png",
            "position": Vector2(25.55, 11.25),
            "scale": Vector2(0.92, 0.92),
            "z": 3,
            "collision": Rect2(24.72, 10.72, 1.62, 0.88)
        }
    ]

static func get_product_layout() -> Array[Dictionary]:
    return [
        {"texture": "res://assets/level3/source/Items/sprDrink.png", "position": Vector2(4.5, 1.88)},
        {"texture": "res://assets/level3/source/Items/sprChipsBag.png", "position": Vector2(10.2, 2.02)},
        {"texture": "res://assets/level3/source/Items/sprDrink.png", "position": Vector2(4.55, 10.66)},
        {"texture": "res://assets/level3/source/Items/sprChipsBag.png", "position": Vector2(11.65, 9.78)},
        {"texture": "res://assets/level3/source/Items/sprDrink.png", "position": Vector2(17.05, 9.78)},
        {"texture": "res://assets/level3/source/Items/sprChipsBag.png", "position": Vector2(25.55, 10.83)},
        {"texture": "res://assets/level3/source/Items/sprDrink.png", "position": Vector2(12.65, 14.63)},
        {"texture": "res://assets/level3/source/Items/sprChipsBag.png", "position": Vector2(18.15, 14.63)}
    ]

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

static func door_rotation(cell: Vector2i) -> float:
    var left_blocked := tile_at(cell + Vector2i(-1, 0)) == "#"
    var right_blocked := tile_at(cell + Vector2i(1, 0)) == "#"
    if left_blocked and right_blocked:
        return PI * 0.5
    return 0.0
