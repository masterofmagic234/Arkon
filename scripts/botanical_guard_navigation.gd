extends Node
## Shared, physically sampled garden routes. Built incrementally once, rather
## than asking every squirrel to steer straight into the same retaining wall.
const STEP := 3.0
const MINIMUM := Vector2(-84, -96)
const WIDTH := 57
const DEPTH := 58
const STEP_HEIGHT := .20
const FLOOR_CLEARANCE := .025
const SUPPORT_INTERVAL := .55
const FLOOR_DOT := .6156614753 # cos(52 degrees), matching both actors.
const LINKS := [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(-1,1)]
var director: Node3D
var is_ready := false
var revision := 0
var point_count := 0
var connection_count := 0
var query_count := 0
var route_requests := 0
var cache_hits := 0
var graph := AStar3D.new()
var tank_graph := AStar3D.new()
var _scout_capsule := CapsuleShape3D.new()
var _tank_capsule := CapsuleShape3D.new()
var cells: Dictionary = {}
var _query := PhysicsShapeQueryParameters3D.new()
var _space: PhysicsDirectSpaceState3D
var _cache: Dictionary = {}
var _support_cache: Dictionary = {}
var _building := false
var _gate_was_open := false
var _bridge_was_open := false
var _gate_poll := 0.0

func setup(owner_: Node3D) -> void:
    director = owner_
    name = "GuardNavigation"
    # Match the actual bodies, including headroom and the guardian's width.
    _scout_capsule.radius=.36;_scout_capsule.height=1.45
    _tank_capsule.radius=.58;_tank_capsule.height=2.05
    _query.shape = _scout_capsule
    # A triangle shell alone cannot report a capsule wholly inside a rock.
    # The same source-derived convex queries used at load reject such nodes;
    # actor movement and floor rays continue to use the actual layer1 mesh.
    _query.collision_mask = 1 | 64
    _query.margin = .008
    call_deferred("_bootstrap")

func _bootstrap() -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    await _build()

func _process(delta: float) -> void:
    _gate_poll -= delta
    if _gate_poll > 0 or not is_ready or _building: return
    _gate_poll = .5
    var open_now := _gate_open()
    if open_now != _gate_was_open:
        _gate_was_open = open_now
        _refresh_gate()
    var bridge_now := _bridge_open()
    if bridge_now != _bridge_was_open:
        _bridge_was_open=bridge_now
        # The pressure bridge has a different earned state and footprint from
        # the store shutter. Its final deck appears above the old pond floor.
        _refresh_area(Rect2i(26,35,5,14)) # x -6..6, z 9..48.

func _gate_open() -> bool:
    var water=director.get("water_flow")
    if not is_instance_valid(water):return false
    var opened=water.get("gate_open")
    return (opened is float or opened is int) and float(opened)>=.98

func _bridge_open() -> bool:
    var routes=director.get("mission_routes")
    if not is_instance_valid(routes):return false
    var opened=routes.get("opened")
    return (opened is float or opened is int) and float(opened)>=.995

func _point(cell: Vector2i) -> Vector3:
    var x := MINIMUM.x + cell.x * STEP
    var z := MINIMUM.y + cell.y * STEP
    return _support(Vector3(x,director.world.surface_height_at(x,z),z))

func _id(cell: Vector2i) -> int:
    return cell.y * WIDTH + cell.x

func ground_goal(point: Vector3) -> Vector3:
    # Tactical offsets may cross terrace heights. Project the order onto a
    # physical floor using the terrain only as the ray's search window.
    return _support(Vector3(point.x,director.world.surface_height_at(point.x,point.z),point.z))

func _support(point: Vector3) -> Vector3:
    var floor := _floor_sample(point)
    return floor.point if not floor.is_empty() else Vector3.INF

func _floor_sample(point: Vector3) -> Dictionary:
    # Height data supplies only a search window. The returned floor is always
    # a real collision triangle: stairs, stone decks and ribbons included.
    var key := Vector3i(roundi(point.x*1024),roundi(point.y*4),roundi(point.z*1024))
    if _support_cache.has(key):return _support_cache[key]
    var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.3,point-Vector3.UP*1.0,1)
    query_count+=1
    var hit := _space.intersect_ray(ray)
    if _bridge_open() and absf(point.x)<2.2 and point.z>=9 and point.z<=46:
        # The south approach can stand2.25m above terrain. A taller second
        # search may find that deck, but must never select the pergola above
        # a guard already standing on the lower end of the wooden ramp.
        if hit.is_empty() or not hit.collider.get_meta("guard_walkable_bridge",false):
            ray.from=point+Vector3.UP*3.0
            query_count+=1
            var upper := _space.intersect_ray(ray)
            if not upper.is_empty() and upper.collider.get_meta("guard_walkable_bridge",false):hit=upper
    var sample: Dictionary={}
    var walkable := not hit.is_empty()
    if walkable:
        # This retained solid volume blocks entering water; its invisible lid
        # is not a route. A lowered physical bridge is hit above it instead.
        walkable=str(hit.collider.name)!="PondWaterVolume" and bool(hit.collider.get_meta("walkable_support",true))
    if walkable and hit.normal.y>=FLOOR_DOT:sample={"point":hit.position+Vector3.UP*FLOOR_CLEARANCE,"normal":hit.normal}
    if _support_cache.size()>65000:_support_cache.clear()
    _support_cache[key]=sample
    return sample

func _profile(tank: bool) -> CapsuleShape3D:
    return _tank_capsule if tank else _scout_capsule

func _slope_clearance(normal: Vector3, shape: CapsuleShape3D) -> float:
    # The bottom hemisphere rests above a tilted plane at its centre column.
    return shape.radius*(1.0/maxf(FLOOR_DOT,normal.y)-1.0)

func _open(point: Vector3, tank:=false) -> bool:
    if not point.is_finite():return false
    var shape := _profile(tank)
    var floor := _floor_sample(point)
    if floor.is_empty():return false
    var lift := _slope_clearance(floor.normal,shape)
    _query.shape=shape
    _query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP*(shape.height*.5+STEP_HEIGHT+lift))
    _query.motion = Vector3.ZERO
    query_count += 1
    return _space.intersect_shape(_query, 1).is_empty()

func segment_clear(a: Vector3, b: Vector3, tank:=false) -> bool:
    if _space == null or not a.is_finite() or not b.is_finite(): return false
    var shape := _profile(tank)
    var distance := Vector2(a.x-b.x,a.z-b.z).length()
    if absf(b.y-a.y) > maxf(.4,distance*1.28):return false
    var count := maxi(1,ceili(distance/SUPPORT_INTERVAL))
    var previous_floor := _floor_sample(a)
    if previous_floor.is_empty():return false
    var previous: Vector3=previous_floor.point
    if not _open(previous,tank):return false
    for index in range(1,count+1):
        var floor := _floor_sample(a.lerp(b,float(index)/count))
        if floor.is_empty():return false
        var point: Vector3=floor.point
        var span := point-previous
        var start_normal: Vector3=previous_floor.normal
        var end_normal: Vector3=floor.normal
        var start_slope := -(start_normal.x*span.x+start_normal.z*span.z)/start_normal.y
        var end_slope := -(end_normal.x*span.x+end_normal.z*span.z)/end_normal.y
        # Smooth ramps earn their rise from the actual floor normals. Two
        # horizontal caps may differ by one real stair riser, never by a .7m
        # ledge merely because the samples happen to be half a meter apart.
        var uphill := maxf(0,maxf(start_slope,end_slope))
        var downhill := maxf(0,maxf(-start_slope,-end_slope))
        if span.y>STEP_HEIGHT+.012+uphill or -span.y>STEP_HEIGHT+.012+downhill:return false
        # A physical step sweep has .20m of lift, never the old small capsule
        # floating above a wall. The movement helper uses the same limit and
        # independently validates headroom, forward motion and a floor landing.
        _query.shape=shape
        var start_lift := _slope_clearance(start_normal,shape)
        var end_lift := _slope_clearance(end_normal,shape)
        _query.transform=Transform3D(Basis.IDENTITY,previous+Vector3.UP*(shape.height*.5+STEP_HEIGHT+start_lift))
        _query.motion=point-previous+Vector3.UP*(end_lift-start_lift)
        query_count+=1
        var hit := _space.cast_motion(_query)
        if not hit.is_empty() and hit[0]<.999:return false
        previous=point
        previous_floor=floor
    return _open(previous,tank)

func _build() -> void:
    _building = true
    _space = director.get_world_3d().direct_space_state
    graph.clear();tank_graph.clear();cells.clear();_cache.clear();_support_cache.clear()
    connection_count = 0
    for row in range(DEPTH):
        for column in range(WIDTH):
            var cell := Vector2i(column,row)
            var point := _point(cell)
            if _open(point):
                cells[cell] = _id(cell)
                graph.add_point(_id(cell),point)
                if _open(point,true):tank_graph.add_point(_id(cell),point)
        if row % 5 == 4: await get_tree().physics_frame
    for row in range(DEPTH):
        for column in range(WIDTH):
            var cell := Vector2i(column,row)
            if cells.has(cell): _connect(cell)
        if row % 5 == 4: await get_tree().physics_frame
    point_count = graph.get_point_count()
    _gate_was_open = _gate_open()
    _bridge_was_open = _bridge_open()
    revision += 1
    is_ready = true
    _building = false

func _connect(cell: Vector2i) -> void:
    for offset: Vector2i in LINKS:
        var other := cell + offset
        if not cells.has(other): continue
        if offset.x != 0 and offset.y != 0:
            if not cells.has(cell+Vector2i(offset.x,0)) or not cells.has(cell+Vector2i(0,offset.y)): continue
        var a: int = cells[cell]
        var b: int = cells[other]
        if graph.are_points_connected(a,b): continue
        if segment_clear(graph.get_point_position(a),graph.get_point_position(b)):
            graph.connect_points(a,b)
            connection_count += 1
        if tank_graph.has_point(a) and tank_graph.has_point(b) and not tank_graph.are_points_connected(a,b):
            if segment_clear(tank_graph.get_point_position(a),tank_graph.get_point_position(b),true):tank_graph.connect_points(a,b)

func _refresh_gate() -> void:
    # Only the moving shutter region changes. A whole-garden rebuild would
    # needlessly resample thousands of unchanged trees and terrace walls.
    _refresh_area(Rect2i(26,18,5,6))

func _refresh_area(area: Rect2i) -> void:
    _support_cache.clear()
    for row in range(area.position.y,area.end.y):
        for column in range(area.position.x,area.end.x):
            var cell := Vector2i(column,row)
            var id := _id(cell)
            if graph.has_point(id):
                connection_count-=graph.get_point_connections(id).size()
                graph.remove_point(id)
            if tank_graph.has_point(id):tank_graph.remove_point(id)
            cells.erase(cell)
            var point := _point(cell)
            if _open(point):
                graph.add_point(id,point);cells[cell]=id
                if _open(point,true):tank_graph.add_point(id,point)
    for row in range(area.position.y-1,area.end.y+1):
        for column in range(area.position.x-1,area.end.x+1):
            var cell := Vector2i(column,row)
            if cells.has(cell): _connect(cell)
    point_count = graph.get_point_count()
    _cache.clear();revision += 1

func _nearest(point: Vector3, tank:=false) -> int:
    var active := tank_graph if tank else graph
    var foot := _support(point)
    if not foot.is_finite() or not _open(foot,tank):return -1
    var centre := Vector2i(roundi((point.x-MINIMUM.x)/STEP),roundi((point.z-MINIMUM.y)/STEP))
    var candidates: Array[Dictionary]=[]
    for row in range(-4,5):
        for column in range(-4,5):
            var cell := centre+Vector2i(column,row)
            if not cells.has(cell):continue
            var id: int=cells[cell]
            if not active.has_point(id):continue
            var p := active.get_point_position(id)
            var offset := p-foot
            candidates.append({"id":id,"score":offset.x*offset.x+offset.z*offset.z+offset.y*offset.y*3})
    candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return a.score<b.score)
    for candidate in candidates:
        var id: int=candidate.id
        # Proximity alone can attach an actor to the other side of glass or a
        # retaining wall. Every endpoint earns a traversable capsule segment.
        if segment_clear(foot,active.get_point_position(id),tank):return id
    return -1

func path(origin: Vector3, target: Vector3, tank:=false) -> PackedVector3Array:
    if not is_ready: return PackedVector3Array()
    route_requests += 1
    var start := _nearest(origin,tank)
    var finish := _nearest(target,tank)
    if start < 0 or finish < 0: return PackedVector3Array()
    var key := Vector3i(start,finish,1 if tank else 0)
    if _cache.has(key):
        cache_hits += 1
        return _cache[key]
    var active := tank_graph if tank else graph
    var points := active.get_point_path(start,finish)
    if _cache.size() > 96: _cache.clear()
    _cache[key] = points
    return points
