extends Node3D

# Рисует дорогу как ArrayMesh.

const RaceLevelData = preload("res://scripts/race_level_data.gd")

var _road_mesh: MeshInstance3D
var _built := false

func build(pattern: Array, track_x: PackedFloat32Array) -> void:
    if _built or pattern.size() < 2:
        return
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var half := RaceLevelData.ROAD_WIDTH * 0.5
    var h := RaceLevelData.SEGMENT_HEIGHT
    for i in pattern.size():
        var x0: float = track_x[i]
        var z0: float = float(i) * h
        var next_i := (i + 1) % pattern.size()
        var x1: float = track_x[next_i]
        var z1: float = float(i + 1) * h
        var dark := (i % 4) < 2
        var c_road := Color(0.28, 0.30, 0.34) if dark else Color(0.33, 0.35, 0.39)
        var c_edge := Color(0.85, 0.55, 0.45) if dark else Color(0.95, 0.95, 0.95)
        _quad(st, Vector3(x0 - half, 0, z0), Vector3(x0 + half, 0, z0), Vector3(x1 + half, 0, z1), Vector3(x1 - half, 0, z1), c_road)
        _quad(st, Vector3(x0 - half - 0.35, 0, z0), Vector3(x0 - half, 0, z0), Vector3(x1 - half, 0, z1), Vector3(x1 - half - 0.35, 0, z1), c_edge)
        _quad(st, Vector3(x0 + half, 0, z0), Vector3(x0 + half + 0.35, 0, z0), Vector3(x1 + half + 0.35, 0, z1), Vector3(x1 + half, 0, z1), c_edge)
    st.generate_normals()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    _road_mesh = MeshInstance3D.new()
    _road_mesh.name = "Road"
    _road_mesh.mesh = st.commit()
    _road_mesh.material_override = mat
    add_child(_road_mesh)
    _built = true

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
    for v in [a, b, c, a, c, d]:
        st.set_color(col)
        st.add_vertex(v)
