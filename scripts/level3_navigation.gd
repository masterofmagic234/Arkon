extends RefCounted
class_name Level3Navigation
# Sample the real authored bodies after synchronization. Moving actors do not
# enter the static grid; closed doors are traversable plans and opened locally.
const STEP := 12.0
var grid := AStarGrid2D.new()
var ready := false
var samples := 0
var walkable := 0

func build(world: Node2D, size_: Vector2, doors: Array[Level3Door]) -> void:
    grid.region = Rect2i(Vector2i.ZERO,Vector2i((size_/STEP).ceil()))
    grid.cell_size = Vector2.ONE*STEP
    grid.offset = Vector2.ONE*STEP*0.5
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    grid.update()
    var shape := CircleShape2D.new()
    shape.radius = 8.0
    var params := PhysicsShapeQueryParameters2D.new()
    params.shape = shape
    params.collision_mask = 1
    params.collide_with_areas = false
    var excluded: Array[RID] = []
    for door in doors: excluded.append(door.pivot.get_rid())
    params.exclude = excluded
    for y in range(grid.region.size.y):
        for x in range(grid.region.size.x):
            var id := Vector2i(x,y)
            params.transform = Transform2D(0.0,grid.get_point_position(id))
            var solid := not world.get_world_2d().direct_space_state.intersect_shape(params,1).is_empty()
            grid.set_point_solid(id,solid)
            samples += 1
            if not solid: walkable += 1
    ready = true

func nearest_id(point: Vector2) -> Vector2i:
    var id := Vector2i((point/STEP).floor())
    id.x = clampi(id.x,0,grid.region.size.x-1)
    id.y = clampi(id.y,0,grid.region.size.y-1)
    if not grid.is_point_solid(id): return id
    for radius in range(1,7):
        for y in range(-radius,radius+1):
            for x in range(-radius,radius+1):
                var test := id+Vector2i(x,y)
                if grid.region.has_point(test) and not grid.is_point_solid(test): return test
    return id

func path(from: Vector2, to: Vector2) -> PackedVector2Array:
    if not ready: return PackedVector2Array()
    var start := nearest_id(from)
    var goal := nearest_id(to)
    if grid.is_point_solid(start) or grid.is_point_solid(goal): return PackedVector2Array()
    return grid.get_point_path(start,goal,false)
