extends RefCounted
class_name Level3StoreData

# One authored plan drives the scene generator, floor, doors and navigation.
const TILE_SIZE: int = 16
const MAP_DATA = preload("res://resources/level3/level3_map.tres")
const PLAYER_SPAWN := Vector2i(6, 28)
const ORDER_CELL := Vector2i(28, 7)
const EXIT_CELL := Vector2i(6, 29)
const ENEMY_SPAWNS: Array[Dictionary] = [
    {"cell": Vector2i(8, 7), "kind": &"melee", "patrol_radius": 34.0},
    {"cell": Vector2i(15, 12), "kind": &"gunman", "patrol_radius": 36.0},
    {"cell": Vector2i(5, 20), "kind": &"melee", "patrol_radius": 30.0},
    {"cell": Vector2i(25, 10), "kind": &"gunman", "patrol_radius": 40.0},
    {"cell": Vector2i(33, 6), "kind": &"butcher", "patrol_radius": 36.0},
    {"cell": Vector2i(43, 10), "kind": &"gunman", "patrol_radius": 36.0},
    {"cell": Vector2i(22, 23), "kind": &"melee", "patrol_radius": 36.0},
    {"cell": Vector2i(29, 26), "kind": &"gunman", "patrol_radius": 34.0},
    {"cell": Vector2i(34, 20), "kind": &"gunman", "patrol_radius": 34.0},
    {"cell": Vector2i(43, 24), "kind": &"butcher", "patrol_radius": 34.0}
]
const PICKUPS: Array[Dictionary] = [
    {"cell": Vector2i(9, 27), "kind": &"ammo"},
    {"cell": Vector2i(4, 26), "kind": &"bat"},
    {"cell": Vector2i(10, 20), "kind": &"medkit"},
    {"cell": Vector2i(22, 29), "kind": &"shotgun"},
    {"cell": Vector2i(30, 12), "kind": &"ammo"},
    {"cell": Vector2i(43, 28), "kind": &"medkit"},
    {"cell": Vector2i(17, 7), "kind": &"bottle"},
    {"cell": Vector2i(33, 29), "kind": &"bottle"}
]

static func get_map() -> PackedStringArray: return MAP_DATA.to_rows()
static func tile_size() -> int: return TILE_SIZE
static func map_size() -> Vector2i: return MAP_DATA.map_size()
static func player_spawn() -> Vector2i: return PLAYER_SPAWN
static func get_enemy_spawns() -> Array[Dictionary]: return ENEMY_SPAWNS
static func get_pickups() -> Array[Dictionary]: return PICKUPS
static func cell_to_world(cell: Vector2i) -> Vector2: return (Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE
static func world_to_cell(world: Vector2) -> Vector2i: return Vector2i((world / TILE_SIZE).floor())
static func is_inside(cell: Vector2i) -> bool: return MAP_DATA.is_inside(cell)
static func is_walkable(cell: Vector2i) -> bool: return MAP_DATA.is_walkable(cell)
static func tile_at(cell: Vector2i) -> String:
    return [".", "#", "D"][MAP_DATA.tile_at(cell)]

static func get_room_floor_regions() -> Array[Dictionary]:
    return [
        {"id":&"diner", "title":"ЗАЛ", "rect":Rect2(1,1,18,22), "color":Color("a18b72"), "style":&"checker"},
        {"id":&"kitchen", "title":"КУХНЯ", "rect":Rect2(20,1,17,14), "color":Color("71878b"), "style":&"tile"},
        {"id":&"stock", "title":"ХОЛОДНЫЙ СКЛАД", "rect":Rect2(38,1,9,14), "color":Color("455b65"), "style":&"tile"},
        {"id":&"entry", "title":"ВХОД", "rect":Rect2(1,24,13,7), "color":Color("7d7464"), "style":&"checker"},
        {"id":&"bar", "title":"БАР / АВТОМАТЫ", "rect":Rect2(15,16,22,15), "color":Color("685342"), "style":&"wood"},
        {"id":&"service", "title":"ПОДСОБКА", "rect":Rect2(38,16,9,15), "color":Color("4b5959"), "style":&"tile"}
    ]

static func room_at(world_local: Vector2) -> Dictionary:
    var point := world_local / TILE_SIZE
    for room in get_room_floor_regions():
        if (room["rect"] as Rect2).has_point(point): return room
    return {"id":&"bar", "title":"ПРОХОД", "rect":Rect2(), "color":Color.WHITE}

static func _prop(id: String, file: String, at: Vector2, size: float = 1.0, turn: float = 0.0, solid: bool = true, frame: int = 0) -> Dictionary:
    return {"id":id, "texture":"res://assets/level3/source/Furniture/"+file+".png", "position":at*TILE_SIZE, "scale":size, "rotation":turn, "solid":solid, "frame":frame}

static func get_furniture_layout() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    # Booths, tables and chairs share a consistent physical scale. Tables leave
    # two continuous north/south lanes and a generous aisle at every doorway.
    for row in range(3):
        var y := 4.6 + row * 5.6
        result.append(_prop("BoothLeft%d"%row,"sprHighballBooth_strip4",Vector2(3.5,y),0.86,0.0,true,1))
        result.append(_prop("PizzaTable%d"%row,"sprPizzaTables_strip4",Vector2(7.1,y),0.65,0.0,true,row%4))
        result.append(_prop("Chair%d"%row,"sprRestaurantChair",Vector2(9.0,y),0.88))
        result.append(_prop("BoothRight%d"%row,"sprHighballBooth_strip4",Vector2(15.8,y),0.86,PI,true,1))
        result.append(_prop("TableRight%d"%row,"sprBarTable_strip5",Vector2(12.5,y),0.88))
    result.append_array([
        _prop("DinerJukebox","sprJukebox_strip3",Vector2(16.5,20.5),1.05),
        _prop("Aquarium","sprAquarium_strip6",Vector2(3.0,2.0),0.95),
        _prop("DinerPalm","sprPlant1_strip2",Vector2(17.4,2.8),0.70,0.0,false),
        _prop("DinerPalm2","sprPlant2_strip2",Vector2(2.5,21.0),0.65,0.0,false),
        _prop("PizzaRegister","sprPizzaRegister",Vector2(7.5,25.2),0.95),
        _prop("EntryCouch","sprWhiteSofa",Vector2(2.1,27.6),0.74),
        _prop("EntryPlant","sprPlant1_strip2",Vector2(11.8,25.3),0.62,0.0,false),
        _prop("KitchenOven","sprPizzaOven_strip10",Vector2(23.8,2.7),1.05),
        _prop("KitchenSink","sprKitchenSinkDown_strip5",Vector2(29.0,2.3),1.08),
        _prop("Wok","sprWokKitchen_strip4",Vector2(33.8,3.6),0.94),
        _prop("PrepTable","sprPizzaCounter",Vector2(27.3,5.1),1.14),
        _prop("PrepShelf","sprMCKitchenShelf_strip4",Vector2(24.0,12.7),1.12),
        _prop("KitchenFridge","sprDoubleFridge",Vector2(33.7,13.0),0.91),
        _prop("KitchenPlant","sprPlant2_strip2",Vector2(35.5,2.0),0.5,0.0,false),
        _prop("Freezer1","sprFreezer_strip2",Vector2(40.0,4.7),0.95),
        _prop("Freezer2","sprFreezer_strip2",Vector2(45.0,4.7),0.95),
        _prop("StoreShelf","sprStoreShelf_strip3",Vector2(45.0,11.0),0.85),
        _prop("Crate1","sprBox",Vector2(39.4,12.7),1.18),
        _prop("Crate2","sprBoxOpen_strip2",Vector2(41.2,12.7),0.74),
        _prop("BarCounter","sprDiscoBar",Vector2(25.0,18.4),1.35),
        _prop("BarBackShelf","sprBarShelf",Vector2(25.0,16.8),0.66,0.0,false),
        _prop("Stool0","sprBarStool",Vector2(21.0,20.5),0.91),
        _prop("Stool1","sprBarStool",Vector2(24.0,20.5),0.91),
        _prop("Stool2","sprBarStool",Vector2(27.0,20.5),0.91),
        _prop("Arcade1","sprArcadeCabinet1_strip2",Vector2(30.8,17.9),0.95),
        _prop("Arcade4","sprArcadeCabinet4_strip2",Vector2(33.0,17.9),0.95),
        _prop("Arcade7","sprArcadeCabinet7_strip2",Vector2(35.2,17.9),0.95),
        _prop("SofaBar","sprKaraokeCouchBlack",Vector2(18.2,28.0),0.86),
        _prop("BarTable","sprBarTable_strip5",Vector2(22.0,26.1),0.82),
        _prop("BarChair","sprDiningChair",Vector2(24.0,26.1),0.92),
        _prop("BarBooth","sprHighballBooth_strip4",Vector2(34.1,25.8),0.91,0.0,true,1),
        _prop("BarTable2","sprSmallTable_strip5",Vector2(31.0,25.8),0.90),
        _prop("BarPlant","sprPlant1_strip2",Vector2(35.7,29.5),0.69,0.0,false),
        _prop("BarJukebox","sprJukebox_strip3",Vector2(16.5,17.5),1.05),
        _prop("OfficeDesk","sprOfficeDesk_strip9",Vector2(43.2,18.5),1.0),
        _prop("OfficeCabinet","sprFileCabinet_strip5",Vector2(45.0,21.0),0.92),
        _prop("WorkBench","sprWorkTable",Vector2(40.4,26.0),0.80),
        _prop("ServiceShelf","sprGymLocker_strip4",Vector2(45.3,29.0),0.70),
        _prop("ServiceCouch","sprOldCouch",Vector2(43.5,30.0),0.68)
    ])
    return result

static func get_door_cells() -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for y in range(map_size().y):
        for x in range(map_size().x):
            var c := Vector2i(x,y)
            if tile_at(c) == "D" and tile_at(c-Vector2i.RIGHT) != "D" and tile_at(c-Vector2i.DOWN) != "D": result.append(c)
    return result
static func door_rotation(cell: Vector2i) -> float:
    return PI*0.5 if tile_at(cell+Vector2i.DOWN)=="D" else 0.0
static func door_center(cell: Vector2i) -> Vector2:
    return cell_to_world(cell)+(Vector2.DOWN if door_rotation(cell)>0.0 else Vector2.RIGHT)*TILE_SIZE*0.5
static func get_door_texture(_cell: Vector2i) -> String: return "res://assets/level3/source/Doors/sprDoorH.png"
