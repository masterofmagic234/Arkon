class_name CombatQuery
extends RefCounted

# Performs exactly the same ray query used by the proven V20 fire path.
static func raycast(world_3d: World3D, camera: Camera3D) -> Dictionary:
    var camera_forward := -camera.global_transform.basis.z
    # PlayerView pitches the camera down for presentation. Keep the gameplay
    # fire ray horizontal so the 30 m range does not dive into the floor and
    # pass beneath the 0.95 m squirrel hitboxes.
    var horizontal_forward := Vector3(camera_forward.x, 0.0, camera_forward.z)
    if horizontal_forward.length_squared() <= 0.0001:
        horizontal_forward = Vector3(0.0, 0.0, -1.0)
    horizontal_forward = horizontal_forward.normalized()

    var query := PhysicsRayQueryParameters3D.create(
        camera.global_position,
        camera.global_position + horizontal_forward * LevelData.FIRE_RANGE,
        LevelData.SQUIRREL_LAYER | LevelData.WORLD_LAYER
    )
    query.collide_with_areas = true
    query.collide_with_bodies = true
    return world_3d.direct_space_state.intersect_ray(query)
