extends RefCounted
# A read-only depth raster of the EXISTING projected meshes. This does not
# create a second road scene or chase camera. It uses the same ArrayMeshes,
# including clipped foliage alpha, buildings, boards, rails, terrain and roof.
# No CPU pixel loops, readback, ray marching or per-frame mesh duplication.
const DEPTH_SHADER=preload("res://shaders/race_scenery_depth.gdshader")
var viewport: SubViewport
var camera: Camera3D
var entries: Array[Dictionary]=[]
var materials: Array[ShaderMaterial]=[]

func setup(overlay,host) -> void:
    viewport=SubViewport.new();viewport.name="SceneryDepth"
    viewport.size=Vector2i(1,1);viewport.world_3d=World3D.new()
    viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
    viewport.msaa_3d=Viewport.MSAA_DISABLED
    # A SubViewportContainer would display every direct child viewport.
    # Keep this data target under the owning level, never on the visible canvas.
    overlay.get_parent().add_child(viewport)
    var world:=Node3D.new();viewport.add_child(world)
    var environment:=WorldEnvironment.new();environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR
    environment.environment.background_color=Color.BLACK
    environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
    world.add_child(environment)
    camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.near=.01;camera.far=2000;world.add_child(camera);camera.make_current()
    for source in [host.road_mesh.road_node,host.road_mesh.verge_node,host.road_mesh.far_road_node,host.road_mesh.far_verge_node,host.scenery.underpass.batch.node]:
        _share(world,source,true)
    for source in [host.scenery.opaque.node,host.scenery.distant_opaque.node,host.scenery.boards.node,host.scenery.distant_boards.node]:
        _share(world,source,false)

func _share(world: Node3D,source: MeshInstance2D,ground: bool) -> void:
    var material:=ShaderMaterial.new();material.shader=DEPTH_SHADER
    material.set_shader_parameter("ground_mesh",ground)
    material.set_shader_parameter("coverage_texture",source.texture)
    materials.append(material)
    var mesh:=MeshInstance3D.new();mesh.mesh=source.mesh
    mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world.add_child(mesh);entries.append({"source":source,"mesh":mesh})

func sync(overlay,host,active: bool,airframe_materials: Dictionary) -> void:
    # The secondary target stays asleep for the whole interval between attacks.
    if viewport==null and not active: return
    if viewport==null: setup(overlay,host)
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
    if not active: return
    var size_: Vector2i=overlay.viewport.size
    if viewport.size!=size_: viewport.size=size_
    camera.position=Vector3(size_.x*.5,size_.y*.5,1000)
    camera.size=float(size_.x)
    for material in materials: material.set_shader_parameter("logical_size",Vector2(size_))
    var transform: Transform2D=overlay.get_transform()
    for material: ShaderMaterial in airframe_materials.values():
        material.set_shader_parameter("scenery_depth",viewport.get_texture())
        material.set_shader_parameter("scenery_depth_enabled",true)
        material.set_shader_parameter("logical_size",Vector2(size_))
        material.set_shader_parameter("viewport_to_canvas_x",Vector3(transform.x.x,transform.y.x,transform.origin.x))
        material.set_shader_parameter("viewport_to_canvas_y",Vector3(transform.x.y,transform.y.y,transform.origin.y))
