class_name CombatQuery
extends RefCounted

# Performs exactly the same ray query used by the proven V20 fire path.
static func raycast(world_3d: World3D, camera: Camera3D) -> Dictionary:
    var center := camera.get_viewport().get_visible_rect().size * 0.5
    var origin := camera.project_ray_origin(center)
    var direction := camera.project_ray_normal(center)

    var query := PhysicsRayQueryParameters3D.create(
        origin,
        origin + direction * LevelData.FIRE_RANGE,
        LevelData.SQUIRREL_LAYER | LevelData.WORLD_LAYER
    )
    query.collide_with_areas = true
    query.collide_with_bodies = true
    return world_3d.direct_space_state.intersect_ray(query)
