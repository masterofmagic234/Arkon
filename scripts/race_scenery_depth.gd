extends RefCounted
# Depth-only proxies in the EXISTING vehicle viewport. No second World3D,
# camera, full-screen render target or texture readback/encoding pass.
# Ordinary cars/glass render first, proxies next, aircraft and rotor blur last.
const DEPTH_SHADER=preload("res://shaders/race_scenery_depth.gdshader")
const PRIORITY := 100
var root: Node3D
var entries: Array[Dictionary]=[]
var materials: Array[ShaderMaterial]=[]
var _material_cache: Dictionary={}
var _size := Vector2i.ZERO
var _transform := Transform2D.IDENTITY

func setup(overlay,host) -> void:
    root=Node3D.new();root.name="AirframeSceneryDepth";root.visible=false
    overlay.world_root.add_child(root)
    for source in [host.road_mesh.road_node,host.road_mesh.verge_node,host.road_mesh.far_road_node,host.road_mesh.far_verge_node,host.scenery.underpass.batch.node]:
        _share(source,true)
    for source in [host.scenery.opaque.node,host.scenery.distant_opaque.node,host.scenery.boards.node,host.scenery.distant_boards.node]:
        _share(source,false)

func _share(source: MeshInstance2D,ground: bool) -> void:
    var key: String="ground" if ground else str(source.texture.get_instance_id())
    if not _material_cache.has(key):
        var material:=ShaderMaterial.new();material.shader=DEPTH_SHADER
        material.render_priority=PRIORITY
        material.set_shader_parameter("ground_mesh",ground)
        if not ground: material.set_shader_parameter("coverage_texture",source.texture)
        _material_cache[key]=material;materials.append(material)
    var mesh:=MeshInstance3D.new();mesh.mesh=source.mesh
    mesh.material_override=_material_cache[key]
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # POSITION is written by the shader; the source bounds are canvas pixels.
    mesh.custom_aabb=AABB(Vector3(-100000,-100000,-100000),Vector3(200000,200000,200000))
    root.add_child(mesh);entries.append({"source":source,"mesh":mesh})

func set_enabled(active: bool) -> void:
    if root!=null: root.visible=active

func sync(overlay,host,active: bool,airframe: Node3D) -> void:
    # Set up on the first idle/loading frame, before an air attack appears.
    if root==null: setup(overlay,host)
    set_enabled(active)
    if not active: return
    var size_: Vector2i=overlay.viewport.size
    var transform: Transform2D=overlay.get_transform().affine_inverse()
    if size_!=_size or transform!=_transform:
        _size=size_;_transform=transform
        for material in materials:
            material.set_shader_parameter("logical_size",Vector2(size_))
            material.set_shader_parameter("canvas_to_viewport_x",Vector3(transform.x.x,transform.y.x,transform.origin.x))
            material.set_shader_parameter("canvas_to_viewport_y",Vector3(transform.x.y,transform.y.y,transform.origin.y))
    # Reject outside a conservative aircraft rectangle BEFORE foliage sampling.
    var bounds:=_airframe_bounds(overlay.camera,airframe,Vector2(size_))
    for material in materials:
        material.set_shader_parameter("airframe_rect",Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))

func _airframe_bounds(camera: Camera3D,airframe: Node3D,size_: Vector2) -> Rect2:
    var center:=camera.to_local(airframe.global_position)
    if -center.z<=8.0+camera.near: return Rect2(Vector2.ZERO,size_)
    var bounds:=Rect2(camera.unproject_position(airframe.global_position),Vector2.ZERO)
    for x: float in [-8,8]:
        for y: float in [-8,8]:
            for z: float in [-8,8]:
                bounds=bounds.expand(camera.unproject_position(camera.to_global(center+Vector3(x,y,z))))
    return bounds.grow(2).intersection(Rect2(Vector2.ZERO,size_))
