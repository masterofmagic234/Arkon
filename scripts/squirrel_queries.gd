extends RefCounted

static func visible_from(origin: Vector3, target: Vector3, world: World3D, wall_mask: int = 1) -> bool:
    if world == null: return true
    var params := PhysicsRayQueryParameters3D.create(origin, target)
    params.collision_mask = wall_mask
    return world.direct_space_state.intersect_ray(params).is_empty()

static func nearby_squirrels(all_ais: Dictionary, origin: Vector3, radius: float, exclude_id := "") -> Array:
    var out: Array = []
    for id in all_ais.keys():
        if id == exclude_id: continue
        var ai = all_ais[id]
        if ai != null and not ai.is_stunned() and origin.distance_to(ai.position) <= radius: out.append(ai)
    return out
