extends Node3D
class_name RaceTrackView

const RaceLevelData = preload("res://scripts/race_level_data.gd")
const RaceMath = preload("res://scripts/race_math.gd")

const ROAD_MESH_SUBDIVISIONS := 4
const SHOULDER_WIDTH := 0.55
const GROUND_MARGIN := 28.0
const GROUND_DEPTH := 0.6

var _road_mesh: MeshInstance3D
var _road_collision: StaticBody3D
var _ground_mesh: MeshInstance3D
var _ground_collision: StaticBody3D
var _built := false

func build(pattern: Array, track_x: PackedFloat32Array) -> void:
    if _built or pattern.size() < 2 or track_x.size() < pattern.size():
        return

    var n := pattern.size()
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    for i in range(n):
        for sub in range(ROAD_MESH_SUBDIVISIONS):
            var p0 := float(i) + (
                float(sub) / float(ROAD_MESH_SUBDIVISIONS)
            )
            var p1 := float(i) + (
                float(sub + 1)
                / float(ROAD_MESH_SUBDIVISIONS)
            )

            var c0 := RaceMath.track_world_position(
                p0,
                track_x,
                n,
                RaceLevelData.SEGMENT_HEIGHT
            )
            var c1 := RaceMath.track_world_position(
                p1,
                track_x,
                n,
                RaceLevelData.SEGMENT_HEIGHT
            )
            var tangent := (c1 - c0).normalized()
            var side := Vector3.UP.cross(tangent)
            if side.length_squared() < 0.0001:
                side = Vector3(1.0, 0.0, 0.0)
            else:
                side = side.normalized()

            var half := RaceLevelData.ROAD_WIDTH * 0.5
            var outer := half + SHOULDER_WIDTH

            var road_color := (
                Color(0.16, 0.18, 0.22)
                if (i % 4) < 2
                else Color(0.19, 0.21, 0.25)
            )
            var edge_color := (
                Color(0.90, 0.32, 0.28)
                if (i % 4) < 2
                else Color(0.94, 0.88, 0.76)
            )

            # For a clockwise/right-handed Godot surface, this winding keeps
            # the generated road normals pointing upward.
            _quad(
                st,
                c0 + side * half,
                c0 - side * half,
                c1 - side * half,
                c1 + side * half,
                road_color
            )

            _quad(
                st,
                c0 - side * half,
                c0 - side * outer,
                c1 - side * outer,
                c1 - side * half,
                edge_color
            )

            _quad(
                st,
                c0 + side * outer,
                c0 + side * half,
                c1 + side * half,
                c1 + side * outer,
                edge_color
            )

    st.generate_normals()

    var road_material := StandardMaterial3D.new()
    road_material.vertex_color_use_as_albedo = true
    road_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    road_material.roughness = 0.92
    road_material.cull_mode = BaseMaterial3D.CULL_DISABLED

    _road_mesh = MeshInstance3D.new()
    _road_mesh.name = "Road"
    _road_mesh.mesh = st.commit()
    _road_mesh.material_override = road_material
    add_child(_road_mesh)

    _road_collision = StaticBody3D.new()
    _road_collision.name = "RoadCollision"
    _road_collision.collision_layer = 1
    _road_collision.collision_mask = 2

    var road_shape := CollisionShape3D.new()
    road_shape.name = "CollisionShape3D"
    road_shape.shape = _road_mesh.mesh.create_trimesh_shape()
    _road_collision.add_child(road_shape)
    add_child(_road_collision)

    _update_start_line(
        pattern.size(),
        track_x
    )
    _build_ground(_road_mesh.get_aabb())

    _built = true

func _update_start_line(
        track_size: int,
        track_x: PackedFloat32Array
) -> void:
    var start_line := get_node_or_null(
        "StartLine"
    ) as MeshInstance3D
    if start_line == null:
        return

    var position := RaceMath.track_world_position(
        0.0,
        track_x,
        track_size,
        RaceLevelData.SEGMENT_HEIGHT
    )
    var tangent := RaceMath.track_world_tangent(
        0.0,
        track_x,
        track_size,
        RaceLevelData.SEGMENT_HEIGHT
    )

    start_line.position = position + Vector3.UP * 0.035
    start_line.rotation.y = atan2(
        tangent.x,
        tangent.z
    )

func _build_ground(road_aabb: AABB) -> void:
    var ground_size := Vector3(
        road_aabb.size.x + GROUND_MARGIN * 2.0,
        GROUND_DEPTH,
        road_aabb.size.z + GROUND_MARGIN * 2.0
    )
    var ground_position := Vector3(
        road_aabb.get_center().x,
        -2.5,
        road_aabb.get_center().z
    )

    var ground_material := StandardMaterial3D.new()
    ground_material.albedo_color = Color(0.035, 0.07, 0.045)
    ground_material.roughness = 1.0

    _ground_mesh = MeshInstance3D.new()
    _ground_mesh.name = "Ground"

    var ground_box := BoxMesh.new()
    ground_box.size = ground_size
    ground_box.material = ground_material
    _ground_mesh.mesh = ground_box
    _ground_mesh.position = ground_position
    add_child(_ground_mesh)

    _ground_collision = StaticBody3D.new()
    _ground_collision.name = "GroundCollision"
    _ground_collision.collision_layer = 1
    _ground_collision.collision_mask = 2

    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = ground_size
    shape.shape = box_shape
    _ground_collision.add_child(shape)
    _ground_collision.position = ground_position
    add_child(_ground_collision)

func _quad(
        st: SurfaceTool,
        a: Vector3,
        b: Vector3,
        c: Vector3,
        d: Vector3,
        col: Color
) -> void:
    for vertex in [a, b, c, a, c, d]:
        st.set_color(col)
        st.add_vertex(vertex)
