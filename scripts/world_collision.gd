class_name WorldCollision
extends RefCounted

const LevelData = preload("res://scripts/level_data.gd")

# Pure world-grid collision query. Door cells remain blocked for AI/pathing;
# opening a Level1Door removes the physical player collision, while enemies
# keep their zone boundaries intact.
static func is_wall(x: float, z: float) -> bool:
    var cell := LevelData.world_to_cell(x, z)
    if cell.x < 0 or cell.x >= LevelData.MAP_WIDTH or cell.y < 0 or cell.y >= LevelData.MAP_HEIGHT:
        return true
    return LevelData.CANONICAL_MAP[cell.y].substr(cell.x, 1) == "#"

# Called only while restoring a garden save, before gameplay controls start.
# It never corrects a moving actor's height or bypasses a collider during play.
static func restore_clear_position(space: PhysicsDirectSpaceState3D,desired: Vector3,capsule: CapsuleShape3D,shape_offset:=Vector3.ZERO,fallback:=Vector3(0,.7,65)) -> Vector3:
    var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1|64;query.margin=0
    query.transform=Transform3D(Basis.IDENTITY,desired+shape_offset)
    if space.intersect_shape(query,1).is_empty():return desired
    var best=fallback;var score=INF
    for ring in range(10):
        var radius=ring*.5
        for i in range(1 if ring==0 else 12):
            var angle=i*TAU/12;var sample=desired+Vector3(cos(angle)*radius,0,sin(angle)*radius)
            var ray=PhysicsRayQueryParameters3D.create(sample+Vector3.UP*3,sample-Vector3.UP*4,1)
            var hit=space.intersect_ray(ray)
            if hit.is_empty() or hit.normal.y<.64:continue
            var candidate: Vector3=hit.position+Vector3.UP*(capsule.height*.5+.02)-shape_offset
            query.transform.origin=candidate+shape_offset
            if not space.intersect_shape(query,1).is_empty():continue
            # Require supporting area under the feet, rather than selecting a
            # thin rail or lamp top merely because the central ray hit it.
            var supported=true
            for side in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
                var foot: Vector3=hit.position+side*capsule.radius*.65
                var support=space.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.12,foot-Vector3.UP*.12,1))
                if support.is_empty() or support.normal.y<.64:supported=false;break
            if not supported:continue
            var distance=candidate.distance_squared_to(desired)
            if distance<score:best=candidate;score=distance
    return best
