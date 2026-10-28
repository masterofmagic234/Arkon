extends RefCounted
# All rivals share the existing player vehicle world and camera. No atlas
# angles and no per-opponent viewport; normal depth testing handles overtakes.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const MODEL_PATH := "res://assets/level2/camry/camry_runtime.glb"
const TRAFFIC_SHADER=preload("res://shaders/race_traffic.gdshader")
var models: Array=[]
var materials: Array[ShaderMaterial]=[]
var rear_materials: Array[ShaderMaterial]=[]
var fitted_size := Vector3.ZERO
var civilian_models: Array=[]
var block_models: Array=[]
var civilian_rears: Array[ShaderMaterial]=[]
var block_rears: Array[ShaderMaterial]=[]
var beacon_materials: Array[ShaderMaterial]=[]
var _mesh: Mesh
var _scale := 1.0
var _base_position := Vector3.ZERO
var _shared: Array[ShaderMaterial]=[]
var _world: Node3D

func setup(world: Node3D) -> void:
    var packed := load(MODEL_PATH) as PackedScene
    var source := packed.instantiate() as Node3D
    world.add_child(source)
    var nodes := source.find_children("*","MeshInstance3D",true,false)
    var mesh_node: MeshInstance3D=nodes[0] if not nodes.is_empty() else source as MeshInstance3D
    var mesh := mesh_node.mesh
    var bounds := mesh.get_aabb()
    var scale_ := 4.88/bounds.size.z
    fitted_size=bounds.size*scale_
    var base_position := -Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*scale_
    var shared: Array[ShaderMaterial]=[]
    _mesh=mesh;_scale=scale_;_base_position=base_position;_world=world
    for surface in range(mesh.get_surface_count()):
        var original := mesh.surface_get_material(surface) as StandardMaterial3D
        var material := ShaderMaterial.new();material.shader=TRAFFIC_SHADER
        material.set_shader_parameter("albedo_texture",original.albedo_texture)
        material.set_shader_parameter("normal_texture",original.normal_texture)
        material.set_shader_parameter("emission_texture",original.emission_texture)
        material.set_shader_parameter("lamp_energy",2.0 if original.resource_name=="FrontLenses" else 0.0)
        shared.append(material)
    _shared=shared
    for index in range(Data.RACER_COUNT-1):
        models.append(_new_car("CamryRival%d"%index,rear_materials))
    for index in range(6):
        civilian_models.append(_new_car("OncomingCamry%d"%index,civilian_rears))
    for index in range(10):
        var pivot:=_new_car("SquirrelRoadblock%d"%index,block_rears)
        for side in [-1.0,1.0]:
            var beacon:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=Vector3(.28,.16,.25);beacon.mesh=shape
            beacon.position=Vector3(side*.17,1.55,0)
            beacon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            var material:=ShaderMaterial.new();material.shader=TRAFFIC_SHADER
            material.set_shader_parameter("albedo_texture",_solid_texture(Color(.06,.09,.13)))
            material.set_shader_parameter("normal_texture",_solid_texture(Color(.5,.5,1)))
            material.set_shader_parameter("emission_texture",_solid_texture(Color(.04,.24,1) if side<0 else Color(1,.03,.03)))
            material.set_shader_parameter("lamp_energy",5.0)
            beacon.material_override=material;materials.append(material);beacon_materials.append(material)
            pivot.add_child(beacon)
        block_models.append(pivot)
    source.queue_free()

func _solid_texture(color: Color) -> ImageTexture:
    var image:=Image.create(2,2,false,Image.FORMAT_RGB8);image.fill(color);image.generate_mipmaps()
    return ImageTexture.create_from_image(image)

func _new_car(name_: String,rears: Array[ShaderMaterial]) -> Node3D:
    var pivot:=Node3D.new();pivot.name=name_;_world.add_child(pivot)
    var visual:=MeshInstance3D.new();visual.mesh=_mesh;visual.scale=Vector3.ONE*_scale;visual.position=_base_position
    visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;pivot.add_child(visual)
    for surface in range(_mesh.get_surface_count()):
        var original:=_mesh.surface_get_material(surface) as StandardMaterial3D
        var material: ShaderMaterial=_shared[surface]
        if original.resource_name=="RearLenses":
            material=material.duplicate() as ShaderMaterial;material.set_shader_parameter("lamp_energy",1.2);rears.append(material)
        if not materials.has(material):materials.append(material)
        visual.set_surface_override_material(surface,material)
    pivot.visible=false
    return pivot

func sync(host,player,camera,delta: float) -> void:
    var rear_x: float=player.world_x+sin(float(player.heading_yaw))*.45
    var rear_z: float=cos(float(player.heading_yaw))*.45
    var grade: float=camera.road_grade
    var size_: Vector2=host.get_viewport_rect().size
    var h: float=size_.y*host.PLAYFIELD_FRACTION
    var height: float=(h-host._horizon(h))*6.0/(.84*size_.x*.75)
    var camera_z: float=player.world_z-host._behind()
    var camera_x: float=host._camera_world_x(player.track_phase())
    # Every visible model (including its body extent) is on level, open earth.
    # No hill, bridge or vault can intersect these rays. Avoid 35 tests for
    # every shaded rival pixel, especially the three large cars at the grid.
    var plain: bool = (camera_z+520<Data.ELEVATION_Z[1]) or (camera_z-520>Data.ELEVATION_Z[-2])
    var samples := PackedVector4Array() if plain else ground_samples(host,camera_z)
    var origin := Vector3(rear_x,Data.road_height(player.world_z)+rear_z*grade,player.world_z+rear_z)
    var camera_origin := Vector3(camera_x,Data.road_height(player.world_z)-host._behind()*grade+height,camera_z)
    for material in materials:
        material.set_shader_parameter("vehicle_origin",origin)
        material.set_shader_parameter("camera_world",camera_origin)
        material.set_shader_parameter("road_grade",grade)
        material.set_shader_parameter("occlusion_sample_count",0 if plain else samples.size())
        if not plain: material.set_shader_parameter("occlusion_samples",samples)
    for index in range(models.size()):
        _sync_car(models[index],host.ai_cars[index].car,host,player,rear_x,rear_z,grade,delta,rear_materials[index],false)
    var director=host.pursuit.encounters if host.pursuit!=null else null
    for index in range(civilian_models.size()):
        var car=director.traffic[index] if director!=null and index<director.traffic.size() else null
        _sync_car(civilian_models[index],car,host,player,rear_x,rear_z,grade,delta,civilian_rears[index],true)
    var barriers: Array=[]
    if director!=null:
        for block in director.roadblocks:
            for car in block.cars:barriers.append(car)
    for index in range(block_models.size()):
        _sync_car(block_models[index],barriers[index] if index<barriers.size() else null,host,player,rear_x,rear_z,grade,delta,block_rears[index],true)
    var clock: float=director.clock if director!=null else 0.0
    for index in range(beacon_materials.size()):
        beacon_materials[index].set_shader_parameter("lamp_energy",6.0 if posmod(floori(clock*8)+index,2)==0 else .25)

func _sync_car(pivot: Node3D,car,host,player,rear_x: float,rear_z: float,grade: float,delta: float,rear: ShaderMaterial,interpolate: bool) -> void:
    if car==null:pivot.visible=false;return
    var x: float=car.world_x;var z: float=car.world_z;var yaw: float=car.heading_yaw
    if interpolate and host.get_parent().is_physics_processing():
        var fraction:=clampf(Engine.get_physics_interpolation_fraction(),0,1)
        x=lerpf(car.old_position.x,x,fraction);z=lerpf(car.old_position.y,z,fraction);yaw=lerp_angle(car.old_heading,yaw,fraction)
    var dz: float=z-player.world_z
    var depth: float=host._camera_point(Vector3(x,0,z)).z
    pivot.visible=absf(dz)<483 and depth> -3 and depth<523
    if not pivot.visible:return
    pivot.position=Vector3(rear_x-x,host._road_relative_height(z),dz-rear_z)
    pivot.rotation=Vector3(-atan(Data.road_grade(z)-grade),-yaw,0)
    var energy: float=rear.get_shader_parameter("lamp_energy")
    rear.set_shader_parameter("lamp_energy",lerpf(energy,7.0 if car.brake_in>.12 else 1.2,1-exp(-14*delta)))

func ground_samples(host,camera_z: float) -> PackedVector4Array:
    var samples := PackedVector4Array()
    var forward: float=cos(float(host.camera_state.yaw_offset) if host.camera_state!=null else 0.0)
    for i in range(33):
        var offset: float=i*16.0*(1.0 if forward>=0 else -1.0) if absf(forward)>.2 else (i-16)*32.0
        var z := camera_z+offset
        samples.append(Vector4(z,Math.track_center_x(z/40,host.track_x),Data.road_height(z),Data.sector_at(z)))
    # Exact mouth planes are mandatory even between two ordinary ray slices.
    for z: float in [Data.TUNNEL_START+.02,Data.TUNNEL_END-.02]:
        samples.append(Vector4(z,Math.track_center_x(z/40,host.track_x),Data.road_height(z),4))
    return samples
