extends Node
## Shared, physically sampled garden routes. Built incrementally once, rather
## than asking every squirrel to steer straight into the same retaining wall.
const STEP := 3.0
const MINIMUM := Vector2(-84, -96)
const WIDTH := 57
const DEPTH := 58
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
var cells: Dictionary = {}
var _query := PhysicsShapeQueryParameters3D.new()
var _space: PhysicsDirectSpaceState3D
var _cache: Dictionary = {}
var _building := false
var _gate_was_open := false
var _gate_poll := 0.0

func setup(owner_: Node3D) -> void:
    director = owner_
    name = "GuardNavigation"
    var capsule := CapsuleShape3D.new()
    capsule.radius = .32
    capsule.height = 1.22
    _query.shape = capsule
    _query.collision_mask = 1
    _query.margin = .02
    call_deferred("_bootstrap")

func _bootstrap() -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    await _build()

func _process(delta: float) -> void:
    _gate_poll -= delta
    if _gate_poll > 0 or not is_ready or _building: return
    _gate_poll = .5
    var open_now: bool = is_instance_valid(director.water_flow) and director.water_flow.gate_open >= .98
    if open_now != _gate_was_open:
        _gate_was_open = open_now
        _refresh_gate()

func _point(cell: Vector2i) -> Vector3:
    var x := MINIMUM.x + cell.x * STEP
    var z := MINIMUM.y + cell.y * STEP
    return Vector3(x, director.world.surface_height_at(x,z) + .035, z)

func _id(cell: Vector2i) -> int:
    return cell.y * WIDTH + cell.x

func _open(point: Vector3) -> bool:
    _query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * .79)
    _query.motion = Vector3.ZERO
    query_count += 1
    return _space.intersect_shape(_query, 1).is_empty()

func segment_clear(a: Vector3, b: Vector3) -> bool:
    if _space == null: return false
    if absf(b.y-a.y) > maxf(1.35, Vector2(a.x-b.x,a.z-b.z).length()*.52): return false
    _query.transform = Transform3D(Basis.IDENTITY, a + Vector3.UP * .79)
    _query.motion = b-a
    query_count += 1
    var hit := _space.cast_motion(_query)
    return hit.is_empty() or hit[0] > .995

func _build() -> void:
    _building = true
    _space = director.get_world_3d().direct_space_state
    graph.clear();cells.clear();_cache.clear()
    connection_count = 0
    for row in range(DEPTH):
        for column in range(WIDTH):
            var cell := Vector2i(column,row)
            var point := _point(cell)
            if _open(point):
                cells[cell] = _id(cell)
                graph.add_point(_id(cell),point)
        if row % 5 == 4: await get_tree().physics_frame
    for row in range(DEPTH):
        for column in range(WIDTH):
            var cell := Vector2i(column,row)
            if cells.has(cell): _connect(cell)
        if row % 5 == 4: await get_tree().physics_frame
    point_count = graph.get_point_count()
    _gate_was_open = is_instance_valid(director.water_flow) and director.water_flow.gate_open >= .98
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

func _refresh_gate() -> void:
    # Only the moving shutter region changes. A whole-garden rebuild would
    # needlessly resample thousands of unchanged trees and terrace walls.
    for row in range(18,24):
        for column in range(26,31):
            var cell := Vector2i(column,row)
            var id := _id(cell)
            if graph.has_point(id):
                connection_count-=graph.get_point_connections(id).size()
                graph.remove_point(id)
            cells.erase(cell)
            var point := _point(cell)
            if _open(point): graph.add_point(id,point);cells[cell]=id
    for row in range(17,25):
        for column in range(25,32):
            var cell := Vector2i(column,row)
            if cells.has(cell): _connect(cell)
    point_count = graph.get_point_count()
    _cache.clear();revision += 1

func _nearest(point: Vector3) -> int:
    var centre := Vector2i(roundi((point.x-MINIMUM.x)/STEP),roundi((point.z-MINIMUM.y)/STEP))
    var best := -1
    var score := INF
    for radius in range(5):
        for row in range(-radius,radius+1):
            for column in range(-radius,radius+1):
                if radius > 0 and maxi(absi(row),absi(column)) != radius: continue
                var cell := centre + Vector2i(column,row)
                if not cells.has(cell): continue
                var id: int = cells[cell]
                var p := graph.get_point_position(id)
                var delta := p-point
                var weight := delta.x*delta.x+delta.z*delta.z+delta.y*delta.y*3
                if weight < score:
                    best=id;score=weight
        if best >= 0 and score < STEP*STEP*2.5: break
    return best

func path(origin: Vector3, target: Vector3) -> PackedVector3Array:
    if not is_ready: return PackedVector3Array()
    route_requests += 1
    var start := _nearest(origin)
    var finish := _nearest(target)
    if start < 0 or finish < 0: return PackedVector3Array()
    var key := Vector2i(start,finish)
    if _cache.has(key):
        cache_hits += 1
        return _cache[key]
    var points := graph.get_point_path(start,finish,true)
    if _cache.size() > 96: _cache.clear()
    _cache[key] = points
    return points
