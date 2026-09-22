extends RefCounted
class_name Level3StoreData

const TILE_SIZE: int = 48
const MAP: Array[String] = [
    "################################",
    "#........#............#........#",
    "#........#............#........#",
    "#........D............D........#",
    "#........#............#........#",
    "#........#............#........#",
    "#..###...#............#...###..#",
    "####D###########D##########D###",
    "#.......#................#.....#",
    "#.......#................#.....#",
    "#.......D................D.....#",
    "#.......#................#.....#",
    "#.......#................#.....#",
    "#.......#................#.....#",
    "#....##.#................#.##..#",
    "######D##################D#####",
    "#...........#..................#",
    "#...........D..................#",
    "#...........#..................#",
    "################################"
]

const PLAYER_SPAWN: Vector2i = Vector2i(2, 17)

const ENEMY_SPAWNS: Array[Dictionary] = [
    {"cell": Vector2i(5, 3), "kind": &"melee", "patrol_radius": 54.0},
    {"cell": Vector2i(15, 3), "kind": &"gunman", "patrol_radius": 72.0},
    {"cell": Vector2i(27, 3), "kind": &"gunman", "patrol_radius": 64.0},
    {"cell": Vector2i(4, 11), "kind": &"melee", "patrol_radius": 58.0},
    {"cell": Vector2i(18, 11), "kind": &"gunman", "patrol_radius": 88.0},
    {"cell": Vector2i(26, 13), "kind": &"butcher", "patrol_radius": 60.0}
]

const PICKUPS: Array[Dictionary] = [
    {"cell": Vector2i(6, 4), "kind": &"bottle"},
    {"cell": Vector2i(10, 17), "kind": &"bat"},
    {"cell": Vector2i(21, 13), "kind": &"shotgun"},
    {"cell": Vector2i(27, 10), "kind": &"pistol"}
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

static func get_room_floor_regions() -> Array[Dictionary]:
    return [
        {"rect": Rect2(1, 1, 8, 6), "color": Color(0.17, 0.12, 0.13, 1.0)},
        {"rect": Rect2(10, 1, 12, 6), "color": Color(0.18, 0.15, 0.12, 1.0)},
        {"rect": Rect2(23, 1, 8, 6), "color": Color(0.12, 0.14, 0.17, 1.0)},
        {"rect": Rect2(1, 8, 30, 7), "color": Color(0.14, 0.13, 0.14, 1.0)},
        {"rect": Rect2(1, 16, 11, 3), "color": Color(0.13, 0.15, 0.13, 1.0)},
        {"rect": Rect2(13, 16, 18, 3), "color": Color(0.15, 0.13, 0.12, 1.0)}
    ]

static func get_furniture_layout() -> Array[Dictionary]:
    return [
        # Left room: compact dining cluster.
        {
            "texture": "res://assets/level3/source/Furniture/sprNoodleTable_strip3.png",
            "position": Vector2(3.2, 3.0),
            "scale": Vector2(0.90, 0.90),
            "z": 3,
            "collision": Rect2(2.45, 2.50, 1.55, 0.82)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprNoodleTable_strip3.png",
            "position": Vector2(6.2, 5.0),
            "scale": Vector2(0.90, 0.90),
            "z": 3,
            "collision": Rect2(5.45, 4.50, 1.55, 0.82)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprRestaurantChair.png",
            "position": Vector2(3.2, 2.25),
            "scale": Vector2(0.78, 0.78),
            "z": 4,
            "collision": null
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprRestaurantChair.png",
            "position": Vector2(3.2, 3.75),
            "scale": Vector2(0.78, 0.78),
            "z": 4,
            "collision": null
        },

        # Kitchen / service room: continuous work line against the north wall.
        {
            "texture": "res://assets/level3/source/Furniture/sprKitchenCounter.png",
            "position": Vector2(11.8, 1.82),
            "scale": Vector2(1.20, 1.20),
            "z": 2,
            "collision": Rect2(10.20, 1.28, 3.25, 0.88)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprKitchenSinkDown_strip5.png",
            "position": Vector2(15.1, 1.82),
            "scale": Vector2(0.88, 0.88),
            "z": 2,
            "collision": Rect2(14.50, 1.30, 1.25, 0.82)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprWokKitchen_strip4.png",
            "position": Vector2(17.4, 1.88),
            "scale": Vector2(0.92, 0.92),
            "z": 3,
            "collision": Rect2(16.72, 1.25, 1.35, 1.00)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprMCKitchenShelf_strip4.png",
            "position": Vector2(20.0, 2.05),
            "scale": Vector2(0.86, 0.86),
            "z": 3,
            "collision": Rect2(19.35, 1.30, 1.30, 1.10)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprRegister.png",
            "position": Vector2(20.1, 5.15),
            "scale": Vector2(0.82, 0.82),
            "z": 3,
            "collision": Rect2(19.52, 4.65, 1.16, 0.76)
        },

        # Right room: service / storage composition along edges.
        {
            "texture": "res://assets/level3/source/Furniture/sprStoreShelf_strip3.png",
            "position": Vector2(25.1, 1.85),
            "scale": Vector2(0.82, 0.82),
            "z": 2,
            "collision": Rect2(24.25, 1.25, 1.65, 0.92)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprFreezer_strip2.png",
            "position": Vector2(28.3, 2.55),
            "scale": Vector2(0.82, 0.82),
            "z": 3,
            "collision": Rect2(27.58, 1.85, 1.30, 1.26)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprStoreShelf_strip3.png",
            "position": Vector2(29.0, 5.25),
            "scale": Vector2(0.78, 0.78),
            "z": 2,
            "collision": Rect2(28.25, 4.62, 1.48, 0.92)
        },

        # Main hall: two compact furniture islands leave clean shooting lanes.
        {
            "texture": "res://assets/level3/source/Furniture/sprRestaurantTable_strip5.png",
            "position": Vector2(12.0, 10.35),
            "scale": Vector2(0.88, 0.88),
            "z": 3,
            "collision": Rect2(10.80, 9.80, 2.45, 1.05)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprRestaurantChair.png",
            "position": Vector2(10.55, 10.35),
            "scale": Vector2(0.78, 0.78),
            "z": 4,
            "collision": null
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprRestaurantChair.png",
            "position": Vector2(13.45, 10.35),
            "scale": Vector2(0.78, 0.78),
            "z": 4,
            "collision": null
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprRestaurantTable_strip5.png",
            "position": Vector2(19.5, 12.2),
            "scale": Vector2(0.88, 0.88),
            "z": 3,
            "collision": Rect2(18.30, 11.65, 2.45, 1.05)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprRestaurantChair.png",
            "position": Vector2(18.00, 12.2),
            "scale": Vector2(0.78, 0.78),
            "z": 4,
            "collision": null
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprRestaurantChair.png",
            "position": Vector2(21.00, 12.2),
            "scale": Vector2(0.78, 0.78),
            "z": 4,
            "collision": null
        },

        # Left lower room: wall-side props, leaving the center for combat.
        {
            "texture": "res://assets/level3/source/Furniture/sprStoreShelf_strip3.png",
            "position": Vector2(2.0, 12.65),
            "scale": Vector2(0.78, 0.78),
            "z": 2,
            "collision": Rect2(1.28, 12.10, 1.35, 1.05)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprTrashcan_strip3.png",
            "position": Vector2(6.1, 13.2),
            "scale": Vector2(0.82, 0.82),
            "z": 4,
            "collision": null
        },

        # Right lower room: large service block and a table.
        {
            "texture": "res://assets/level3/source/Furniture/sprVendingMachine.png",
            "position": Vector2(29.0, 9.25),
            "scale": Vector2(1.15, 1.15),
            "z": 4,
            "collision": Rect2(28.25, 8.48, 1.30, 1.58)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprFreezer_strip2.png",
            "position": Vector2(27.9, 13.0),
            "scale": Vector2(0.82, 0.82),
            "z": 4,
            "collision": Rect2(27.20, 12.30, 1.30, 1.26)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprRestaurantTable_strip5.png",
            "position": Vector2(25.3, 11.45),
            "scale": Vector2(0.86, 0.86),
            "z": 3,
            "collision": Rect2(24.15, 10.98, 2.35, 0.96)
        },

        # Bottom rooms: sparse storage rather than a furniture maze.
        {
            "texture": "res://assets/level3/source/Furniture/sprStoreShelf_strip3.png",
            "position": Vector2(2.0, 17.55),
            "scale": Vector2(0.78, 0.78),
            "z": 2,
            "collision": Rect2(1.30, 17.00, 1.25, 0.95)
        },
        {
            "texture": "res://assets/level3/source/Furniture/sprFreezer_strip2.png",
            "position": Vector2(28.5, 17.55),
            "scale": Vector2(0.82, 0.82),
            "z": 3,
            "collision": Rect2(27.78, 16.88, 1.30, 1.22)
        }
    ]

static func get_product_layout() -> Array[Dictionary]:
    return [
        {"texture": "res://assets/level3/source/Items/sprDrink.png", "position": Vector2(15.1, 2.24)},
        {"texture": "res://assets/level3/source/Items/sprChipsBag.png", "position": Vector2(17.4, 2.32)},
        {"texture": "res://assets/level3/source/Items/sprDrink.png", "position": Vector2(20.1, 5.58)},
        {"texture": "res://assets/level3/source/Items/sprChipsBag.png", "position": Vector2(12.0, 9.80)},
        {"texture": "res://assets/level3/source/Items/sprDrink.png", "position": Vector2(19.5, 11.62)},
        {"texture": "res://assets/level3/source/Items/sprChipsBag.png", "position": Vector2(25.3, 10.86)}
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
    var up_blocked := tile_at(cell + Vector2i(0, -1)) == "#"
    var down_blocked := tile_at(cell + Vector2i(0, 1)) == "#"
    var left_blocked := tile_at(cell + Vector2i(-1, 0)) == "#"
    var right_blocked := tile_at(cell + Vector2i(1, 0)) == "#"

    if up_blocked and down_blocked and not left_blocked and not right_blocked:
        return PI * 0.5

    return 0.0
