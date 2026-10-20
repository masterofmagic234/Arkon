extends RefCounted
# One set of footprints drives scenery, physics and navigation.
const Data = preload("res://scripts/level_data.gd")
const LAMPS := [Vector2i(4,29),Vector2i(11,26),Vector2i(21,23),Vector2i(13,19),Vector2i(9,20),Vector2i(13,14),Vector2i(16,10),Vector2i(19,4),Vector2i(22,8),Vector2i(5,13),Vector2i(6,6),Vector2i(21,16),Vector2i(27,7),Vector2i(32,5),Vector2i(34,13),Vector2i(43,15),Vector2i(44,7),Vector2i(38,11),Vector2i(37,20),Vector2i(33,22),Vector2i(42,25),Vector2i(41,26),Vector2i(43,30),Vector2i(35,31),Vector2i(43,33)]
const BENCHES := [
    [Vector2i(7,31),Vector2i(9,28)], [Vector2i(21,25),Vector2i(18,24)],
    [Vector2i(6,13),Vector2i(10,9)], [Vector2i(18,4),Vector2i(17,9)],
    [Vector2i(21,11),Vector2i(10,9)], [Vector2i(33,3),Vector2i(34,7)],
    [Vector2i(44,17),Vector2i(35,13)], [Vector2i(33,29),Vector2i(38,27)],
    [Vector2i(44,28),Vector2i(38,27)], [Vector2i(40,32),Vector2i(38,27)],
]
const URNS := [Vector2i(7,32),Vector2i(20,26),Vector2i(5,14),Vector2i(20,3),Vector2i(22,11),Vector2i(32,3),Vector2i(43,18),Vector2i(32,30),Vector2i(45,28),Vector2i(41,33)]
const BENCH_SIZE := Vector3(2.15,1.40,0.90)
const PORTAL_CELL := Vector2i(7,29)
const PORTAL_YAW := -PI/4.0
const SUPPLY_CELLS := [Vector2i(6,5),Vector2i(44,5),Vector2i(33,32)]
static var _footprint_cache: Array[Dictionary] = []

static func bench_yaw(bench: Array) -> float:
    var direction: Vector2 = Vector2(bench[1]-bench[0])
    return atan2(-direction.x,-direction.y)

static func bench_position(bench: Array) -> Vector3:
    return Data.cell_center_world(bench[0])+Vector3.UP*(0.20 if bench[0]==Vector2i(18,4) else 0.0)

static func footprints() -> Array[Dictionary]:
    if not _footprint_cache.is_empty(): return _footprint_cache
    var out: Array[Dictionary] = []
    for cell in LAMPS:
        out.append({"id":"Lamp_%02d_%02d"%[cell.x,cell.y],"p":Data.cell_center_world(cell),"size":Vector3(0.42,3.65,0.42),"yaw":0.0})
    out.append({"id":"PavilionLamp","p":Data.cell_center_world(Vector2i(17,4))+Vector3.UP*0.20,"size":Vector3(0.42,3.3,0.42),"yaw":0.0})
    for cell in URNS:
        out.append({"id":"GardenUrn_%02d_%02d"%[cell.x,cell.y],"p":Data.cell_center_world(cell),"size":Vector3(.88,.90,.88),"yaw":0.0})
    for cell in SUPPLY_CELLS:
        out.append({"id":"GardenSupply_%02d_%02d"%[cell.x,cell.y],"p":Data.cell_center_world(cell),"size":Vector3(.80,.72,.62),"yaw":0.0})
    for spec: Dictionary in preload("res://scripts/level1_heist_data.gd").DEVICES:
        out.append({"id":spec.id,"p":Data.cell_center_world(spec.cell),"size":preload("res://scripts/level1_heist_data.gd").footprint(spec),"yaw":0.0})
    for bench in BENCHES:
        var cell: Vector2i = bench[0]
        out.append({"id":"Bench_%02d_%02d"%[cell.x,cell.y],"p":bench_position(bench),"size":BENCH_SIZE,"yaw":bench_yaw(bench)})
    for side: float in [-1,1]:
        out.append({"id":"MoonPortalLeft" if side<0 else "MoonPortalRight","p":Data.cell_center_world(PORTAL_CELL)+Basis(Vector3.UP,PORTAL_YAW)*Vector3(side*2.15,0,0),"size":Vector3(.36,3.35,.36),"yaw":PORTAL_YAW})
    for x: float in [-2.5,2.5]:
        out.append({"id":"ArchColumn_Left" if x<0 else "ArchColumn_Right","p":Data.cell_center_world(Vector2i(34,5))+Vector3.RIGHT*x,"size":Vector3(0.9,5.6,0.9),"yaw":0.0})
    _footprint_cache = out
    return out

static func outline(prop: Dictionary) -> PackedVector3Array:
    var p: Vector3 = prop.p
    var size_: Vector3 = prop.size
    var basis_ := Basis(Vector3.UP,float(prop.yaw))
    var points := PackedVector3Array()
    for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
        points.append(p+basis_*Vector3(corner.x*size_.x*0.5,0,corner.y*size_.z*0.5))
    return points

static func contains_point(world: Vector3, margin: float = 0.0) -> bool:
    for prop in footprints():
        var local: Vector3 = Basis(Vector3.UP,float(prop.yaw)).inverse()*(world-prop.p)
        var size_: Vector3 = prop.size
        if absf(local.x)<size_.x*0.5+margin and absf(local.z)<size_.z*0.5+margin and local.y>=0 and local.y<size_.y:
            return true
    return false

static func blocks_cell(cell: Vector2i) -> bool:
    return contains_point(Data.cell_center_world(cell)+Vector3.UP*0.4,0.43)

static func build_collisions(parent: Node3D) -> void:
    var root_ := Node3D.new()
    root_.name = "ParkPropCollisions"
    parent.add_child(root_)
    for prop in footprints():
        var body := StaticBody3D.new()
        body.name = prop.id
        body.collision_layer = Data.WORLD_LAYER
        body.collision_mask = 0
        body.position = prop.p
        body.rotation.y = prop.yaw
        var collider := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = prop.size
        collider.shape = box
        collider.position.y = box.size.y*0.5
        body.add_child(collider)
        root_.add_child(body)
