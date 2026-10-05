extends Node3D
class_name RaceTrackView

const RaceAuthoredTrackData = preload(
    "res://scripts/race_authored_track_data.gd"
)

const TRACK_SCENE_PATH := "res://nfs_shift_psp_-_london_short.glb"
const ROAD_COLLISION_WIDTH := 8.0
const ROAD_COLLISION_THICKNESS := 0.30
const ROAD_COLLISION_OVERLAP := 0.35
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

    _build_authored_road_collision(centerline)
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

func _build_authored_road_collision(
        centerline: PackedVector3Array
) -> void:
    _road_collision = StaticBody3D.new()
    _road_collision.name = "RoadCollision"
    _road_collision.collision_layer = 1
    _road_collision.collision_mask = 2

    var material := PhysicsMaterial.new()
    material.friction = 1.0
    material.bounce = 0.0
    _road_collision.physics_material_override = material
    add_child(_road_collision)

    if centerline.size() < 2:
        push_error("[Level2] Cannot build road collision from an empty centerline.")
        return

    var count := centerline.size()
    for i in range(count):
        var a := centerline[i]
        var b := centerline[(i + 1) % count]
        var delta := b - a
        delta.y = 0.0
        var segment_length := delta.length()
        if segment_length < 0.05:
            continue

        var collision := CollisionShape3D.new()
        collision.name = "Road_%04d" % i

        var shape := BoxShape3D.new()
        shape.size = Vector3(
            ROAD_COLLISION_WIDTH,
            ROAD_COLLISION_THICKNESS,
            segment_length + ROAD_COLLISION_OVERLAP
        )
        collision.shape = shape
        collision.position = (a + b) * 0.5 + Vector3.UP * 0.02
        collision.rotation.y = atan2(delta.x, delta.z)
        _road_collision.add_child(collision)

    print(
        "[Physics] London gameplay road collision segments=%d width=%.1fm"
        % [
            _road_collision.get_child_count(),
            ROAD_COLLISION_WIDTH
        ]
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
    var body := get_node_or_null(
        "GroundCollision"
    ) as StaticBody3D

    if body == null:
        body = StaticBody3D.new()
        body.name = "GroundCollision"
        add_child(body)

    body.collision_layer = 1
    body.collision_mask = 2

    var shape := body.get_node_or_null(
        "CollisionShape3D"
    ) as CollisionShape3D
    if shape == null:
        shape = CollisionShape3D.new()
        shape.name = "CollisionShape3D"
        body.add_child(shape)

    var box := shape.shape as BoxShape3D
    if box == null:
        box = BoxShape3D.new()
        shape.shape = box

    box.size = FALLBACK_GROUND_SIZE
    shape.position.y = FALLBACK_GROUND_Y
    _ground_collision = body
