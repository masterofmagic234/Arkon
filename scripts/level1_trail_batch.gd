extends RefCounted
# Small immutable decorations share one lit vertex-coloured surface per block.
var _surfaces: Dictionary={}
var _arrays: Dictionary={}
var chunk_metres := 12.0
func add(mesh: Mesh, transform: Transform3D, color: Color) -> void:
    var key := Vector2i.ZERO if chunk_metres<=0 else Vector2i(floori(transform.origin.x/chunk_metres),floori(transform.origin.z/chunk_metres))
    if not _surfaces.has(key):
        var surface := SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        _surfaces[key]=surface
    var id := mesh.get_instance_id()
    if not _arrays.has(id): _arrays[id]=mesh.surface_get_arrays(0)
    var data: Array=_arrays[id]
    var vertices: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
    var indices: PackedInt32Array=data[Mesh.ARRAY_INDEX] if data[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
    var normal_basis := transform.basis.inverse().transposed()
    var surface: SurfaceTool=_surfaces[key]
    for i in range(indices.size() if not indices.is_empty() else vertices.size()):
        var vertex := indices[i] if not indices.is_empty() else i
        surface.set_color(color)
        surface.set_normal((normal_basis*normals[vertex]).normalized())
        surface.add_vertex(transform*vertices[vertex])
func finish(parent: Node3D, prefix: String = "ParkGardenDetail", distance_: float = 38.0, override: Material = null) -> void:
    var material := override
    if material == null:
        var lit := StandardMaterial3D.new()
        lit.vertex_color_use_as_albedo=true
        lit.vertex_color_is_srgb=true
        lit.roughness=1.0
        lit.metallic_specular=.08
        material=lit
    for key: Vector2i in _surfaces:
        var surface: SurfaceTool=_surfaces[key]
        surface.index()
        var node := MeshInstance3D.new()
        node.name="%s_%d_%d"%[prefix,key.x,key.y]
        node.mesh=surface.commit()
        node.material_override=material
        node.visibility_range_end=distance_
        node.visibility_range_end_margin=4.0
        node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        parent.add_child(node)
    _surfaces.clear();_arrays.clear()
