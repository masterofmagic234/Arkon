extends Node3D
class_name RaceTrackView

const RaceAuthoredTrackData = preload(
    "res://scripts/race_authored_track_data.gd"
)

const TRACK_SCENE_PATH := "res://nfs_shift_psp_-_london_short.glb"
const ROAD_MATERIAL_HINTS := [
    "material_046",
    "material_047",
    "material_048"
]
const FALLBACK_GROUND_SIZE := Vector3(180.0, 0.6, 140.0)
const FALLBACK_GROUND_Y := -12.0

var _authored_track: Node3D = null
var _road_collision: StaticBody3D = null
var _ground_collision: StaticBody3D = null
var _built := false

func build(centerline: PackedVector3Array) -> void:
    if _built:
        return

    var packed := load(TRACK_SCENE_PATH) as PackedScene
    if packed == null:
        push_error(
            "[Level2] Failed to load authored track: %s"
            % TRACK_SCENE_PATH
        )
        _build_fallback_ground()
        _built = true
        return

    _authored_track = packed.instantiate() as Node3D
    if _authored_track == null:
        push_error(
            "[Level2] Authored London GLB root is not Node3D."
        )
        _build_fallback_ground()
        _built = true
        return

    _authored_track.name = "AuthoredTrack"
    _authored_track.transform = (
        RaceAuthoredTrackData.get_track_transform()
    )
    add_child(_authored_track)

    _build_authored_road_collision()
    _build_fallback_ground()
    _update_start_line(centerline)
    _built = true

    print(
        "[Level2] Authored London Short loaded: "
        + "scale=%.2f meshes=%d"
        % [
            RaceAuthoredTrackData.TRACK_SCALE,
            _authored_track.find_children(
                "*",
                "MeshInstance3D",
                true,
                false
            ).size()
        ]
    )

func _build_authored_road_collision() -> void:
    _road_collision = StaticBody3D.new()
    _road_collision.name = "RoadCollision"
    _road_collision.collision_layer = 1
    _road_collision.collision_mask = 2

    var material := PhysicsMaterial.new()
    material.friction = 1.0
    material.bounce = 0.0
    _road_collision.physics_material_override = material
    add_child(_road_collision)

    var count := 0
    for node in _authored_track.find_children(
        "*",
        "MeshInstance3D",
        true,
        false
    ):
        var mesh_node := node as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue

        var name := mesh_node.name.to_lower()
        var road := false
        for hint in ROAD_MATERIAL_HINTS:
            if name.contains(hint):
                road = true
                break

        if not road:
            continue

        var shape := mesh_node.mesh.create_trimesh_shape()
        if shape == null:
            continue

        var collision := CollisionShape3D.new()
        collision.name = "Road_%04d" % count
        collision.shape = shape
        collision.transform = (
            global_transform.affine_inverse()
            * mesh_node.global_transform
        )
        _road_collision.add_child(collision)
        count += 1

    print(
        "[Physics] London road collision shapes=%d"
        % count
    )

func _update_start_line(
        centerline: PackedVector3Array
) -> void:
    var line := get_node_or_null(
        "StartLine"
    ) as MeshInstance3D
    if line == null or centerline.size() < 2:
        return

    var tangent := centerline[1] - centerline[0]
    tangent.y = 0.0
    if tangent.length_squared() < 0.0001:
        return

    tangent = tangent.normalized()
    line.position = centerline[0] + Vector3.UP * 0.045
    line.rotation.y = atan2(
        tangent.x,
        tangent.z
    )

func _build_fallback_ground() -> void:
    var body := StaticBody3D.new()
    body.name = "GroundCollision"
    body.collision_layer = 1
    body.collision_mask = 2

    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = FALLBACK_GROUND_SIZE
    shape.shape = box
    shape.position.y = FALLBACK_GROUND_Y
    body.add_child(shape)
    add_child(body)
    _ground_collision = body
