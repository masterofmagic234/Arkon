extends RefCounted
# One set of footprints drives scenery, physics and navigation.
const Data = preload("res://scripts/level_data.gd")
const LAMPS := [Vector2i(11,52),Vector2i(26,50),Vector2i(27,38),Vector2i(19,31),Vector2i(13,23),Vector2i(14,12),Vector2i(27,9),Vector2i(35,20),Vector2i(41,15),Vector2i(53,17),Vector2i(64,10),Vector2i(78,20),Vector2i(67,38),Vector2i(74,46),Vector2i(58,52),Vector2i(35,48)]
const BENCHES := [
    [Vector2i(14,55),Vector2i(20,49)], [Vector2i(33,42),Vector2i(43,38)],
    [Vector2i(11,19),Vector2i(23,20)], [Vector2i(31,9),Vector2i(20,7)],
    [Vector2i(80,18),Vector2i(70,17)], [Vector2i(78,54),Vector2i(64,48)],
]
const URNS := [Vector2i(11,50),Vector2i(17,8),Vector2i(53,16),Vector2i(60,46)]
const GALLERY_COLUMNS := [Vector2i(62,10),Vector2i(68,10),Vector2i(74,10),Vector2i(62,26),Vector2i(68,26),Vector2i(74,26)]
const BENCH_SIZE := Vector3(2.15,1.40,0.90)
const PORTAL_CELL := Vector2i(12,53)
const PORTAL_YAW := -PI/3.0
const SUPPLY_CELLS := [Vector2i(11,25),Vector2i(78,11),Vector2i(76,54)]
static var _footprint_cache: Array[Dictionary] = []

static func bench_yaw(bench: Array) -> float:
    var direction: Vector2 = Vector2(bench[1]-bench[0])
    return atan2(-direction.x,-direction.y)

static func bench_position(bench: Array) -> Vector3:
    return Data.cell_center_world(bench[0])

static func footprints() -> Array[Dictionary]:
    if not _footprint_cache.is_empty(): return _footprint_cache
    var out: Array[Dictionary] = []
    for cell in LAMPS:
        out.append({"id":"Lamp_%02d_%02d"%[cell.x,cell.y],"p":Data.cell_center_world(cell),"size":Vector3(0.42,3.65,0.42),"yaw":0.0})
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
        out.append({"id":"MoonPortalLeft" if side<0 else "MoonPortalRight","p":Data.cell_center_world(PORTAL_CELL)+Basis(Vector3.UP,PORTAL_YAW)*Vector3(side*2.8,0,0),"size":Vector3(.36,3.35,.36),"yaw":PORTAL_YAW})
    for x: float in [-4.4,4.4]:
        for z: float in [-3.5,3.5]:
            out.append({"id":"ObservatoryColumn_%s_%s"%[x,z],"p":Data.cell_center_world(Data.OBSERVATORY_CELL)+Vector3(x,0,z),"size":Vector3(.55,5.2,.55),"yaw":0.0})
    for cell in GALLERY_COLUMNS:
        out.append({"id":"GreenhouseColumn_%s_%s"%[cell.x,cell.y],"p":Data.cell_center_world(cell),"size":Vector3(.70,5.6,.70),"yaw":0.0})
    for cell in preload("res://scripts/level1_heist_data.gd").SCANNERS:
        out.append({"id":"Scanner_%s_%s"%[cell.x,cell.y],"p":Data.cell_center_world(cell),"size":Vector3(.28,2.9,.28),"yaw":0.0})
    for side: float in [-1,1]:
        out.append({"id":"BridgeRail_%s"%side,"p":Data.cell_center_world(Data.RETURN_BRIDGE_CELL)+Vector3(0,0,side*4.35),"size":Vector3(28.8,1.1,.16),"yaw":0.0})
    for i in range(1,Data.HUB_BRIDGE.size()):
        var a:=Data.cell_center_world(Data.HUB_BRIDGE[i-1]);var b:=Data.cell_center_world(Data.HUB_BRIDGE[i])
        var direction:=a.direction_to(b);var yaw:=atan2(-direction.x,-direction.z)
        for side: float in [-1,1]:
            out.append({"id":"EastBridgeRail_%s_%s"%[i,side],"p":(a+b)*.5+Basis(Vector3.UP,yaw)*Vector3(side*4.32,0,0),"size":Vector3(.16,1.1,a.distance_to(b)),"yaw":yaw})
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
        if absf(local.x)<size_.x*0.5+margin+.0001 and absf(local.z)<size_.z*0.5+margin+.0001 and local.y>=0 and local.y<size_.y:
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
