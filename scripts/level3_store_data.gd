extends RefCounted
class_name Level3StoreData

const TILE_SIZE: int = 16

const MAP: Array[String] = [
    "################################",
    "#........#............#........#",
    "#........#............#........#",
    "#........D............D........#",
    "#........D............D........#",
    "#........#............#........#",
    "#..###...#............#...###..#",
    "####DD#########DD########DD####",
    "#.......#................#.....#",
    "#.......#................#.....#",
    "#.......D................D.....#",
    "#.......D................D.....#",
    "#.......#................#.....#",
    "#.......#................#.....#",
    "#....##.#................#.##..#",
    "####DD####################DD####",
    "#...........#..................#",
    "#...........#..................#",
    "#...........#..................#",
    "#...........D..................#",
    "#...........D..................#",
    "#...........#..................#",
    "#..............................#",
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
        {"rect": Rect2(1, 1, 8, 6), "color": Color(0.20, 0.13, 0.14, 1.0), "texture": "res://assets/level3/source/Floor/sprFloor_strip4.png", "alpha": 0.10},
        {"rect": Rect2(10, 1, 12, 6), "color": Color(0.18, 0.15, 0.11, 1.0), "texture": "res://assets/level3/source/Floor/sprDanceFloor_strip8.png", "alpha": 0.07},
        {"rect": Rect2(23, 1, 8, 6), "color": Color(0.10, 0.13, 0.17, 1.0), "texture": "res://assets/level3/source/Floor/sprGlassFloor.png", "alpha": 0.08},
        {"rect": Rect2(1, 8, 30, 7), "color": Color(0.13, 0.12, 0.13, 1.0), "texture": "res://assets/level3/source/Floor/sprDanceFloor1_strip35.png", "alpha": 0.06},
        {"rect": Rect2(1, 16, 11, 7), "color": Color(0.12, 0.14, 0.12, 1.0), "texture": "res://assets/level3/source/Floor/sprFloor_strip4.png", "alpha": 0.08},
        {"rect": Rect2(13, 16, 18, 7), "color": Color(0.15, 0.12, 0.11, 1.0), "texture": "res://assets/level3/source/Floor/sprPelletsSide_strip4.png", "alpha": 0.08}
    ]

static func get_furniture_layout() -> Array[Dictionary]:
    return [
        # FRONT / DINER ROOM
        {"texture":"res://assets/level3/source/Furniture/sprPizzaTables_strip4.png","position":Vector2(3.0,2.6),"scale":Vector2(0.70,0.70),"z":3,"collision":Rect2(2.25,2.08,1.55,0.86)},
        {"texture":"res://assets/level3/source/Furniture/sprRestaurantChair.png","position":Vector2(2.45,1.95),"scale":Vector2(0.68,0.68),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprRestaurantChair.png","position":Vector2(3.65,3.20),"scale":Vector2(0.68,0.68),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprBarStool.png","position":Vector2(6.15,1.80),"scale":Vector2(0.72,0.72),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprBarStool.png","position":Vector2(7.10,1.80),"scale":Vector2(0.72,0.72),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprBarTable_strip5.png","position":Vector2(6.65,2.65),"scale":Vector2(0.75,0.75),"z":3,"collision":Rect2(5.65,2.15,2.10,0.78)},
        {"texture":"res://assets/level3/source/Furniture/sprJukebox_strip3.png","position":Vector2(7.40,5.45),"scale":Vector2(0.78,0.78),"z":4,"collision":Rect2(7.05,5.10,0.75,0.55)},
        {"texture":"res://assets/level3/source/Furniture/sprAquarium_strip6.png","position":Vector2(1.65,5.35),"scale":Vector2(0.74,0.74),"z":4,"collision":Rect2(1.20,4.75,0.90,0.95)},
        {"texture":"res://assets/level3/source/Furniture/sprPlant1_strip2.png","position":Vector2(7.55,5.55),"scale":Vector2(0.72,0.72),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprModernArt_strip7.png","position":Vector2(5.05,5.82),"scale":Vector2(0.72,0.72),"z":4,"collision":null},

        # KITCHEN / SERVICE LINE
        {"texture":"res://assets/level3/source/Furniture/sprPizzaCounter.png","position":Vector2(11.25,1.78),"scale":Vector2(0.95,0.95),"z":2,"collision":Rect2(10.10,1.25,2.30,0.92)},
        {"texture":"res://assets/level3/source/Furniture/sprPizzaOven_strip10.png","position":Vector2(13.35,1.95),"scale":Vector2(0.86,0.86),"z":3,"collision":Rect2(12.80,1.30,1.15,1.24)},
        {"texture":"res://assets/level3/source/Furniture/sprKitchenSinkDown_strip5.png","position":Vector2(15.10,1.82),"scale":Vector2(0.82,0.82),"z":3,"collision":Rect2(14.55,1.26,1.18,0.86)},
        {"texture":"res://assets/level3/source/Furniture/sprWokKitchen_strip4.png","position":Vector2(17.15,1.88),"scale":Vector2(0.90,0.90),"z":3,"collision":Rect2(16.55,1.25,1.25,1.00)},
        {"texture":"res://assets/level3/source/Furniture/sprMCKitchenShelf_strip4.png","position":Vector2(19.15,1.92),"scale":Vector2(0.78,0.78),"z":3,"collision":Rect2(18.52,1.25,1.25,1.18)},
        {"texture":"res://assets/level3/source/Furniture/sprFryingKitchen_strip4.png","position":Vector2(21.0,1.90),"scale":Vector2(0.84,0.84),"z":3,"collision":Rect2(20.40,1.30,1.20,1.06)},
        {"texture":"res://assets/level3/source/Furniture/sprMicrowaveDown_strip2.png","position":Vector2(21.15,5.60),"scale":Vector2(0.76,0.76),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprToaster_strip3.png","position":Vector2(19.75,5.72),"scale":Vector2(0.74,0.74),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprBuffe.png","position":Vector2(12.40,5.50),"scale":Vector2(0.80,0.80),"z":3,"collision":Rect2(11.72,4.95,1.35,0.92)},
        {"texture":"res://assets/level3/source/Furniture/sprBuffePlates.png","position":Vector2(13.60,5.55),"scale":Vector2(0.70,0.70),"z":4,"collision":null},

        # STORAGE / BACK ROOM
        {"texture":"res://assets/level3/source/Furniture/sprStoreShelf_strip3.png","position":Vector2(24.55,1.85),"scale":Vector2(0.80,0.80),"z":3,"collision":Rect2(23.75,1.25,1.62,1.02)},
        {"texture":"res://assets/level3/source/Furniture/sprShelvesDown_strip4.png","position":Vector2(26.40,1.85),"scale":Vector2(0.74,0.74),"z":3,"collision":Rect2(25.82,1.24,1.20,1.05)},
        {"texture":"res://assets/level3/source/Furniture/sprFreezer_strip2.png","position":Vector2(28.45,2.42),"scale":Vector2(0.84,0.84),"z":3,"collision":Rect2(27.72,1.70,1.40,1.34)},
        {"texture":"res://assets/level3/source/Furniture/sprWineRack.png","position":Vector2(30.15,4.40),"scale":Vector2(0.72,0.72),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprBox.png","position":Vector2(25.0,5.28),"scale":Vector2(0.72,0.72),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprBoxOpen_strip2.png","position":Vector2(27.0,5.25),"scale":Vector2(0.70,0.70),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprEuroTrash_strip2.png","position":Vector2(30.10,5.65),"scale":Vector2(0.72,0.72),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprCameraHolder.png","position":Vector2(29.35,1.55),"scale":Vector2(0.74,0.74),"z":4,"collision":null},

        # MAIN HALL — BAR / ARCADE / FURNITURE ISLANDS
        {"texture":"res://assets/level3/source/Furniture/sprDiscoBar.png","position":Vector2(12.0,9.10),"scale":Vector2(0.86,0.86),"z":3,"collision":Rect2(10.80,8.55,2.45,1.10)},
        {"texture":"res://assets/level3/source/Furniture/sprHighballBar.png","position":Vector2(15.2,9.10),"scale":Vector2(0.78,0.78),"z":3,"collision":Rect2(14.30,8.58,1.85,1.02)},
        {"texture":"res://assets/level3/source/Furniture/sprHighballBooth_strip4.png","position":Vector2(18.35,9.85),"scale":Vector2(0.86,0.86),"z":3,"collision":Rect2(17.30,9.28,2.15,1.14)},
        {"texture":"res://assets/level3/source/Furniture/sprArcadeCabinet1_strip2.png","position":Vector2(21.10,9.15),"scale":Vector2(0.88,0.88),"z":4,"collision":Rect2(20.50,8.50,1.25,1.10)},
        {"texture":"res://assets/level3/source/Furniture/sprArcadeCabinet4_strip2.png","position":Vector2(22.75,9.15),"scale":Vector2(0.88,0.88),"z":4,"collision":Rect2(22.15,8.50,1.25,1.10)},
        {"texture":"res://assets/level3/source/Furniture/sprArcadeCabinet7_strip2.png","position":Vector2(24.40,9.15),"scale":Vector2(0.88,0.88),"z":4,"collision":Rect2(23.80,8.50,1.25,1.10)},
        {"texture":"res://assets/level3/source/Furniture/sprSpeakerBooth.png","position":Vector2(27.90,9.10),"scale":Vector2(0.76,0.76),"z":4,"collision":Rect2(27.35,8.58,1.15,0.96)},
        {"texture":"res://assets/level3/source/Furniture/sprDJTable.png","position":Vector2(29.45,11.0),"scale":Vector2(0.74,0.74),"z":4,"collision":Rect2(28.75,10.42,1.35,0.92)},
        {"texture":"res://assets/level3/source/Furniture/sprRestaurantTable1_strip5.png","position":Vector2(12.3,12.45),"scale":Vector2(0.76,0.76),"z":3,"collision":Rect2(11.25,11.92,2.20,1.00)},
        {"texture":"res://assets/level3/source/Furniture/sprDiningChair.png","position":Vector2(11.10,12.45),"scale":Vector2(0.68,0.68),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprDiningChair.png","position":Vector2(13.55,12.45),"scale":Vector2(0.68,0.68),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprSmallTable_strip5.png","position":Vector2(17.25,13.10),"scale":Vector2(0.78,0.78),"z":3,"collision":Rect2(16.50,12.60,1.55,0.90)},
        {"texture":"res://assets/level3/source/Furniture/sprArmchair.png","position":Vector2(18.80,13.10),"scale":Vector2(0.74,0.74),"z":4,"collision":Rect2(18.35,12.60,0.92,0.88)},
        {"texture":"res://assets/level3/source/Furniture/sprPlant2_strip2.png","position":Vector2(20.70,13.15),"scale":Vector2(0.70,0.70),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprJukeboxGlow_strip8.png","position":Vector2(23.45,13.55),"scale":Vector2(0.75,0.75),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprBarTable_strip5.png","position":Vector2(26.10,13.0),"scale":Vector2(0.74,0.74),"z":3,"collision":Rect2(25.35,12.52,1.55,0.84)},
        {"texture":"res://assets/level3/source/Furniture/sprBarStool.png","position":Vector2(25.20,13.75),"scale":Vector2(0.68,0.68),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprBarStool.png","position":Vector2(27.00,13.75),"scale":Vector2(0.68,0.68),"z":4,"collision":null},

        # LEFT LOWER BACK ROOM — OFFICE / LIVING
        {"texture":"res://assets/level3/source/Furniture/sprOfficeDesk_strip9.png","position":Vector2(2.75,17.15),"scale":Vector2(0.66,0.66),"z":3,"collision":Rect2(2.0,16.58,1.70,0.96)},
        {"texture":"res://assets/level3/source/Furniture/sprComputer_strip2.png","position":Vector2(2.85,16.62),"scale":Vector2(0.68,0.68),"z":4,"collision":null},
        {"texture":"res://assets/level3/source/Furniture/sprFileCabinetOffice_strip4.png","position":Vector2(5.0,17.45),"scale":Vector2(0.70,0.70),"z":3,"collision":Rect2(4.55,16.85,0.92,1.15)},
        {"texture":"res://assets/level3/source/Furniture/sprBookshelfMiddle_strip4.png","position":Vector2(7.55,17.45),"scale":Vector2(0.70,0.70),"z":3,"collision":Rect2(7.10,16.82,0.92,1.18)},
        {"texture":"res://assets/level3/source/Furniture/sprOldCouch.png","position":Vector2(9.45,17.48),"scale":Vector2(0.72,0.72),"z":3,"collision":Rect2(8.30,17.00,2.25,0.92)},
        {"texture":"res://assets/level3/source/Furniture/sprTVSet_strip2.png","position":Vector2(10.70,16.60),"scale":Vector2(0.66,0.66),"z":4,"collision":null},

        # RIGHT LOWER BACK ROOM — WORK / CLEANING / STORAGE
        {"texture":"res://assets/level3/source/Furniture/sprWorkTable.png","position":Vector2(15.05,17.15),"scale":Vector2(0.76,0.76),"z":3,"collision":Rect2(14.20,16.60,1.72,1.00)},
        {"texture":"res://assets/level3/source/Furniture/sprJanitorWorkBench.png","position":Vector2(17.60,17.25),"scale":Vector2(0.70,0.70),"z":3,"collision":Rect2(16.88,16.72,1.48,0.94)},
        {"texture":"res://assets/level3/source/Furniture/sprCleaningCart.png","position":Vector2(20.30,17.30),"scale":Vector2(0.68,0.68),"z":4,"collision":Rect2(19.85,16.78,0.88,0.92)},
        {"texture":"res://assets/level3/source/Furniture/sprToolTable.png","position":Vector2(22.65,17.15),"scale":Vector2(0.72,0.72),"z":3,"collision":Rect2(21.82,16.60,1.65,1.00)},
        {"texture":"res://assets/level3/source/Furniture/sprGymLocker_strip4.png","position":Vector2(25.15,17.32),"scale":Vector2(0.68,0.68),"z":3,"collision":Rect2(24.60,16.62,1.10,1.34)},
        {"texture":"res://assets/level3/source/Furniture/sprHeater_strip11.png","position":Vector2(28.55,17.20),"scale":Vector2(0.66,0.66),"z":3,"collision":Rect2(28.10,16.78,0.92,0.84)}
    ]

static func get_floor_decor_layout() -> Array[Dictionary]:
    return [
        {"texture":"res://assets/level3/source/Furniture/sprFloorTable.png","position":Vector2(4.7,4.75),"scale":Vector2(0.74,0.74),"z":-3},
        {"texture":"res://assets/level3/source/Furniture/sprWaterPuddle_strip5.png","position":Vector2(8.0,4.7),"scale":Vector2(0.68,0.68),"z":-3},
        {"texture":"res://assets/level3/source/Furniture/sprWetSpot.png","position":Vector2(14.25,6.0),"scale":Vector2(0.66,0.66),"z":-3},
        {"texture":"res://assets/level3/source/Furniture/sprPellets.png","position":Vector2(18.10,6.0),"scale":Vector2(0.70,0.70),"z":-3},
        {"texture":"res://assets/level3/source/Furniture/sprTinyShard_strip11.png","position":Vector2(23.4,6.2),"scale":Vector2(0.66,0.66),"z":-3},
        {"texture":"res://assets/level3/source/Furniture/sprVomit.png","position":Vector2(28.0,6.0),"scale":Vector2(0.62,0.62),"z":-3},
        {"texture":"res://assets/level3/source/Furniture/sprTurd_strip4.png","position":Vector2(5.75,14.1),"scale":Vector2(0.60,0.60),"z":-3},
        {"texture":"res://assets/level3/source/Furniture/sprShards_strip11.png","position":Vector2(15.7,14.0),"scale":Vector2(0.66,0.66),"z":-3},
        {"texture":"res://assets/level3/source/Furniture/sprWaterPuddle_strip5.png","position":Vector2(22.4,14.0),"scale":Vector2(0.66,0.66),"z":-3},
        {"texture":"res://assets/level3/source/Furniture/sprOpenTrashbag_strip6.png","position":Vector2(29.1,14.1),"scale":Vector2(0.62,0.62),"z":-3}
    ]

static func get_wall_props_layout() -> Array[Dictionary]:
    return [
        {"texture":"res://assets/level3/source/Walls/sprWindowOpen_strip7.png","position":Vector2(2.0,1.0),"scale":Vector2(0.78,0.78),"z":1},
        {"texture":"res://assets/level3/source/Walls/sprWindowRight_strip2.png","position":Vector2(7.2,1.0),"scale":Vector2(0.74,0.74),"z":1},
        {"texture":"res://assets/level3/source/Walls/sprBannerH_strip16.png","position":Vector2(15.0,7.08),"scale":Vector2(0.78,0.78),"z":1},
        {"texture":"res://assets/level3/source/Walls/sprBannerH_strip16.png","position":Vector2(20.0,7.08),"scale":Vector2(0.78,0.78),"z":1},
        {"texture":"res://assets/level3/source/Furniture/sprNeonSign_strip2.png","position":Vector2(27.5,7.35),"scale":Vector2(0.72,0.72),"z":1},
        {"texture":"res://assets/level3/source/Furniture/sprChineseLight_strip3.png","position":Vector2(23.85,7.45),"scale":Vector2(0.74,0.74),"z":1},
        {"texture":"res://assets/level3/source/Furniture/sprLight.png","position":Vector2(12.8,7.35),"scale":Vector2(0.70,0.70),"z":1},
        {"texture":"res://assets/level3/source/Furniture/sprSpot.png","position":Vector2(18.1,7.35),"scale":Vector2(0.66,0.66),"z":1}
    ]

static func get_door_cells() -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for y in range(MAP.size()):
        for x in range(MAP[y].length()):
            if MAP[y][x] != "D":
                continue

            var has_left_pair := x > 0 and MAP[y][x - 1] == "D"
            var has_up_pair := y > 0 and MAP[y - 1][x] == "D"
            if has_left_pair or has_up_pair:
                continue

            result.append(Vector2i(x, y))
    return result

static func door_rotation(cell: Vector2i) -> float:
    if tile_at(cell + Vector2i(1, 0)) == "D":
        return 0.0
    if tile_at(cell + Vector2i(0, 1)) == "D":
        return PI * 0.5
    return 0.0

static func door_center(cell: Vector2i) -> Vector2:
    var center := cell_to_world(cell)
    if tile_at(cell + Vector2i(1, 0)) == "D":
        center += Vector2(float(TILE_SIZE) * 0.5, 0.0)
    elif tile_at(cell + Vector2i(0, 1)) == "D":
        center += Vector2(0.0, float(TILE_SIZE) * 0.5)
    return center

static func get_door_texture(cell: Vector2i) -> String:
    return "res://assets/level3/source/Doors/sprDoorH.png"


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

