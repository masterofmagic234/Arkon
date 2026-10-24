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
    for surface in range(mesh.get_surface_count()):
        var original := mesh.surface_get_material(surface) as StandardMaterial3D
        var material := ShaderMaterial.new();material.shader=TRAFFIC_SHADER
        material.set_shader_parameter("albedo_texture",original.albedo_texture)
        material.set_shader_parameter("normal_texture",original.normal_texture)
        material.set_shader_parameter("emission_texture",original.emission_texture)
        material.set_shader_parameter("lamp_energy",2.0 if original.resource_name=="FrontLenses" else 0.0)
        shared.append(material)
    for index in range(Data.RACER_COUNT-1):
        var pivot := Node3D.new();pivot.name="CamryRival%d"%index;world.add_child(pivot)
        var visual := MeshInstance3D.new();visual.mesh=mesh;visual.scale=Vector3.ONE*scale_;visual.position=base_position
        visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        pivot.add_child(visual)
        for surface in range(mesh.get_surface_count()):
            var original := mesh.surface_get_material(surface) as StandardMaterial3D
            var material: ShaderMaterial=shared[surface]
            if original.resource_name=="RearLenses":
                material=material.duplicate() as ShaderMaterial
                material.set_shader_parameter("lamp_energy",1.2)
                rear_materials.append(material)
            if not materials.has(material): materials.append(material)
            visual.set_surface_override_material(surface,material)
        models.append(pivot)
    source.queue_free()

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
    var plain: bool = (camera_z<Data.ELEVATION_Z[1] and player.world_z+486<Data.ELEVATION_Z[1]) or (camera_z>Data.ELEVATION_Z[-2] and player.world_z-16>Data.ELEVATION_Z[-2])
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
        var car=host.ai_cars[index].car
        var dz: float=car.world_z-player.world_z
        var pivot: Node3D=models[index]
        pivot.visible=dz>-10 and dz<480
        if not pivot.visible: continue
        pivot.position=Vector3(rear_x-car.world_x,host._road_relative_height(car.world_z),dz-rear_z)
        pivot.rotation=Vector3(-atan(Data.road_grade(car.world_z)-grade),-float(car.heading_yaw),0)
        var energy: float=rear_materials[index].get_shader_parameter("lamp_energy")
        rear_materials[index].set_shader_parameter("lamp_energy",lerpf(energy,7.0 if car.brake_in>.12 else 1.2,1-exp(-14*delta)))

func ground_samples(host,camera_z: float) -> PackedVector4Array:
    var samples := PackedVector4Array()
    for i in range(33):
        var z := camera_z+i*16.0
        samples.append(Vector4(z,Math.track_center_x(z/40,host.track_x),Data.road_height(z),Data.sector_at(z)))
    # Exact mouth planes are mandatory even between two ordinary ray slices.
    for z: float in [Data.TUNNEL_START+.02,Data.TUNNEL_END-.02]:
        samples.append(Vector4(z,Math.track_center_x(z/40,host.track_x),Data.road_height(z),4))
    return samples
