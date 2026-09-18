extends RefCounted

# Reuse the ray-query object between visibility checks. The query is only used
# synchronously inside visible_from(), so updating from/to for each squirrel is
# safe and avoids a per-call heap allocation.
static var _visible_query: PhysicsRayQueryParameters3D

static func visible_from(origin: Vector3, target: Vector3, world: World3D, wall_mask: int = 1) -> bool:
    if world == null:
        return true
    if _visible_query == null:
        _visible_query = PhysicsRayQueryParameters3D.new()
    _visible_query.from = origin
    _visible_query.to = target
    _visible_query.collision_mask = wall_mask
    return world.direct_space_state.intersect_ray(_visible_query).is_empty()

static func nearby_squirrels(all_ais: Dictionary, origin: Vector3, radius: float, exclude_id := "") -> Array:
    var out: Array = []
    for id in all_ais.keys():
        if id == exclude_id: continue
        var ai = all_ais[id]
        if ai != null and not ai.is_stunned() and origin.distance_to(ai.position) <= radius: out.append(ai)
    return out

static func nearby_acorns(acorns, origin: Vector3, radius: float) -> Array:
    var out: Array = []
    if acorns == null:
        return out
    if acorns is Dictionary:
        for id in acorns.keys():
            var v = acorns[id]
            var p: Vector3
            if v is Vector3:
                p = v
            elif v is Dictionary:
                p = v.get("position", Vector3.ZERO)
            else:
                continue
            if origin.distance_to(p) <= radius:
                out.append({"id": str(id), "position": p})
        return out
    if acorns is Array:
        for a in acorns:
            if a is Dictionary:
                var p: Vector3 = a.get("position", Vector3.ZERO)
                if origin.distance_to(p) <= radius:
                    out.append(a)
            elif a is Vector3:
                if origin.distance_to(a) <= radius:
                    out.append({"id": "", "position": a})
    return out
