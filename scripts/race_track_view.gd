extends Node3D
class_name RaceTrackView

const RaceLevelData = preload("res://scripts/race_level_data.gd")
const RaceMath = preload("res://scripts/race_math.gd")

const ROAD_MESH_SUBDIVISIONS := 4
const SHOULDER_WIDTH := 0.55
const GROUND_MARGIN := 90.0
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
    var segment_length := RaceLevelData.SEGMENT_HEIGHT
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    for i in range(n):
        for sub in range(ROAD_MESH_SUBDIVISIONS):
            var p0 := float(i) + float(sub) / float(ROAD_MESH_SUBDIVISIONS)
            var p1 := float(i) + float(sub + 1) / float(ROAD_MESH_SUBDIVISIONS)

            var c0 := _track_point(p0, track_x, n)
            var c1 := _track_point(p1, track_x, n)
            var tangent := (c1 - c0).normalized()
            var side := tangent.cross(Vector3.UP)
            if side.length_squared() < 0.0001:
                side = Vector3(-1.0, 0.0, 0.0)
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

            # Winding is explicitly chosen for an upward-facing surface.
            _quad(
                st,
                c0 - side * half,
                c0 + side * half,
                c1 + side * half,
                c1 - side * half,
                road_color
            )

            _quad(
                st,
                c0 + side * half,
                c0 + side * outer,
                c1 + side * outer,
                c1 + side * half,
                edge_color
            )

            _quad(
                st,
                c0 - side * outer,
                c0 - side * half,
                c1 - side * half,
                c1 - side * outer,
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

    _build_ground(n)

    _built = true

func _track_point(
        track_position: float,
        track_x: PackedFloat32Array,
        track_size: int
) -> Vector3:
    var wrapped := fposmod(track_position, float(track_size))
    var center_x := RaceMath.track_center_x(
        wrapped,
        track_x
    )
    var next_x := RaceMath.track_center_x(
        wrapped + 0.01,
        track_x
    )
    var dx := next_x - center_x
    var forward := Vector3(
        dx,
        RaceMath.track_elevation(wrapped + 0.01, track_size)
            - RaceMath.track_elevation(wrapped, track_size),
        0.01 * RaceLevelData.SEGMENT_HEIGHT
    ).normalized()

    var side := forward.cross(Vector3.UP)
    if side.length_squared() < 0.0001:
        side = Vector3(-1.0, 0.0, 0.0)
    else:
        side = side.normalized()

    var elevation := RaceMath.track_elevation(wrapped, track_size)
    var center := Vector3(
        center_x,
        elevation,
        wrapped * RaceLevelData.SEGMENT_HEIGHT
    )

    # The z coordinate is monotonic for the authored run. A tiny final seam is
    # physically connected by the collision mesh; lap management handles the
    # actual start/finish reset.
    return center + side * 0.0

func _build_ground(track_size: int) -> void:
    var total_length := (
        float(track_size) * RaceLevelData.SEGMENT_HEIGHT
    )
    var ground_size := Vector3(
        180.0,
        GROUND_DEPTH,
        total_length + GROUND_MARGIN * 2.0
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
    _ground_mesh.position = Vector3(
        0.0,
        -2.5,
        total_length * 0.5
    )
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
    _ground_collision.position = _ground_mesh.position
    add_child(_ground_collision)

func _quad(
        st: SurfaceTool,
        a: Vector3,
        b: Vector3,
        c: Vector3,
        d: Vector3,
        col: Color
) -> void:
    for v in [a, b, c, a, c, d]:
        st.set_color(col)
        st.add_vertex(v)
