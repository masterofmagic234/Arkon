extends Node3D
class_name RaceTrackView

const RaceLevelData = preload("res://scripts/race_level_data.gd")
const TRACK_SCENE_PATH := "res://nfs_shift_psp_-_london_short.glb"
const TRACK_TARGET_DIAMETER := 380.0
const FALLBACK_GROUND_SIZE := Vector3(540.0, 0.6, 540.0)
const FALLBACK_GROUND_Y := -30.0

var _authored_track: Node3D = null
var _road_collision: StaticBody3D = null
var _ground_mesh: MeshInstance3D = null
var _ground_collision: StaticBody3D = null
var _built := false

func build(_pattern: Array, _track_x: PackedFloat32Array) -> void:
    if _built:
        return

    var packed := load(TRACK_SCENE_PATH) as PackedScene
    if packed == null:
        push_error("[Level2] Failed to load authored track: %s" % TRACK_SCENE_PATH)
        _build_fallback_ground()
        _built = true
        return

    _authored_track = packed.instantiate() as Node3D
    if _authored_track == null:
        push_error("[Level2] Authored track GLB root is not Node3D.")
        _build_fallback_ground()
        _built = true
        return

    _authored_track.name = "AuthoredTrack"
    add_child(_authored_track)

    _fit_authored_track()
    _build_authored_collision()
    _build_fallback_ground()

    _built = true

    print(
        "[Level2] Authored NFS Shift London Short track loaded: scale=%.4f meshes=%d"
        % [
            _authored_track.scale.x,
            _authored_track.find_children("*", "MeshInstance3D", true, false).size()
        ]
    )

func _fit_authored_track() -> void:
    if _authored_track == null:
        return

    var meshes := _authored_track.find_children(
        "*",
        "MeshInstance3D",
        true,
        false
    )

    var bounds := AABB()
    var has_bounds := false
    for node in meshes:
        var mesh_node := node as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue

        var mesh_aabb := mesh_node.get_aabb()
        var node_transform := _authored_track.global_transform.affine_inverse() * mesh_node.global_transform
        for corner in [
            Vector3(mesh_aabb.position.x, mesh_aabb.position.y, mesh_aabb.position.z),
            Vector3(mesh_aabb.end.x, mesh_aabb.position.y, mesh_aabb.position.z),
            Vector3(mesh_aabb.position.x, mesh_aabb.end.y, mesh_aabb.position.z),
            Vector3(mesh_aabb.position.x, mesh_aabb.end.y, mesh_aabb.end.z),
            Vector3(mesh_aabb.end.x, mesh_aabb.end.y, mesh_aabb.position.z),
            Vector3(mesh_aabb.end.x, mesh_aabb.position.y, mesh_aabb.end.z),
            Vector3(mesh_aabb.position.x, mesh_aabb.end.y, mesh_aabb.end.z),
            Vector3(mesh_aabb.end.x, mesh_aabb.end.y, mesh_aabb.end.z)
        ]:
            var point: Vector3 = node_transform * corner
            if not has_bounds:
                bounds = AABB(point, Vector3.ZERO)
                has_bounds = true
            else:
                bounds = bounds.expand(point)

    if not has_bounds:
        return

    var horizontal_diameter := maxf(bounds.size.x, bounds.size.z)
    if horizontal_diameter < 0.1:
        return

    var scale_factor := TRACK_TARGET_DIAMETER / horizontal_diameter
    _authored_track.scale = Vector3.ONE * scale_factor

    var center := bounds.get_center()
    _authored_track.position = Vector3(
        -center.x * scale_factor,
        -bounds.position.y * scale_factor,
        -center.z * scale_factor
    )

func _build_authored_collision() -> void:
    if _authored_track == null:
        return

    _road_collision = StaticBody3D.new()
    _road_collision.name = "RoadCollision"
    _road_collision.collision_layer = 1
    _road_collision.collision_mask = 2

    var material := PhysicsMaterial.new()
    material.friction = 1.0
    material.bounce = 0.0
    _road_collision.physics_material_override = material
    add_child(_road_collision)

    var meshes := _authored_track.find_children(
        "*",
        "MeshInstance3D",
        true,
        false
    )

    var collision_index := 0
    for node in meshes:
        var mesh_node := node as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue

        var shape := mesh_node.mesh.create_trimesh_shape()
        if shape == null:
            continue

        var section := CollisionShape3D.new()
        section.name = "AuthoredMesh_%04d" % collision_index
        section.shape = shape
        section.transform = (
            global_transform.affine_inverse()
            * mesh_node.global_transform
        )
        _road_collision.add_child(section)
        collision_index += 1

    print(
        "[Physics] Level 2 authored track collision built from %d mesh shapes"
        % collision_index
    )

func _build_fallback_ground() -> void:
    var ground_material := StandardMaterial3D.new()
    ground_material.albedo_color = Color(0.018, 0.025, 0.03)
    ground_material.roughness = 1.0

    _ground_mesh = MeshInstance3D.new()
    _ground_mesh.name = "Ground"
    var ground_box := BoxMesh.new()
    ground_box.size = FALLBACK_GROUND_SIZE
    ground_box.material = ground_material
    _ground_mesh.mesh = ground_box
    _ground_mesh.position.y = FALLBACK_GROUND_Y
    add_child(_ground_mesh)

    _ground_collision = StaticBody3D.new()
    _ground_collision.name = "GroundCollision"
    _ground_collision.collision_layer = 1
    _ground_collision.collision_mask = 2

    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    var box_shape := BoxShape3D.new()
    box_shape.size = FALLBACK_GROUND_SIZE
    shape.shape = box_shape
    shape.position.y = FALLBACK_GROUND_Y
    _ground_collision.add_child(shape)
    add_child(_ground_collision)
