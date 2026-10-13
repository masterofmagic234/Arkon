extends RefCounted
# Small immutable decorations share one lit vertex-coloured surface per block.
var _surfaces: Dictionary={}
var _arrays: Dictionary={}
func add(mesh: Mesh, transform: Transform3D, color: Color) -> void:
    var key := Vector2i(floori(transform.origin.x/12.0),floori(transform.origin.z/12.0))
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
func finish(parent: Node3D) -> void:
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo=true
    material.vertex_color_is_srgb=true
    material.roughness=1.0
    material.metallic_specular=.08
    for key: Vector2i in _surfaces:
        var surface: SurfaceTool=_surfaces[key]
        surface.index()
        var node := MeshInstance3D.new()
        node.name="ParkTrailDetail_%d_%d"%[key.x,key.y]
        node.mesh=surface.commit()
        node.material_override=material
        node.visibility_range_end=22.0
        node.visibility_range_end_margin=2.0
        node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        parent.add_child(node)
    _surfaces.clear();_arrays.clear()
