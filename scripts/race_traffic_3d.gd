extends RefCounted
# All rivals share the existing player vehicle world and camera. No atlas
# angles and no per-opponent viewport; normal depth testing handles overtakes.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const MODEL_PATH := "res://assets/level2/camry/camry_runtime.glb"
const TRAFFIC_SHADER=preload("res://shaders/race_traffic.gdshader")
const FLEET_PATHS := {
    "patrol": "res://assets/level2/fleet155/camry_patrol.glb",
    "interceptor": "res://assets/level2/fleet155/camry_interceptor.glb",
    "wagon": "res://assets/level2/fleet155/camry_wagon.glb",
}
const FLEET_BADGE=preload("res://assets/level2/fleet155/patrol_badge.png")
const FLEET_MARKS=preload("res://assets/level2/fleet155/patrol_marks.svg")
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
var fleet_definitions: Dictionary={}
var last_visible_cars := 0
var last_material_updates := 0
var last_occlusion_sample_count := 0
const CAMERA_CLEARANCE := .18
const CAMERA_GHOST_COVERAGE := .10

func setup(world: Node3D) -> void:
    _world=world
    for variant: String in FLEET_PATHS:
        fleet_definitions[variant]=_load_fleet_definition(variant,FLEET_PATHS[variant])
    var baseline: Dictionary=fleet_definitions["patrol"]
    var baseline_bounds: AABB=baseline.bounds
    # Every variant keeps the donor unit-to-metre scale. Fitting each to4.88m
    # would stretch the compact's wheels and erase the authored proportions.
    _scale=4.88/baseline_bounds.size.z
    for variant: String in fleet_definitions:
        var definition: Dictionary=fleet_definitions[variant]
        var bounds: AABB=definition.bounds
        definition["size"]=bounds.size*_scale
        definition["center"]=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
        definition["base_position"]=-definition.center*_scale
    _mesh=baseline.mesh;_shared=baseline.shared
    _base_position=baseline.base_position;fitted_size=baseline["size"]
    var rival_variants := ["patrol","interceptor","patrol"]
    var rival_units := [7,24,36]
    for index in range(Data.RACER_COUNT-1):
        models.append(_new_car("CamryRival%d"%index,rear_materials,rival_variants[index],"police",rival_units[index],Color.WHITE))
    var civilian_variants := ["patrol","wagon","interceptor","patrol","wagon","interceptor"]
    var civilian_colors := [Color(.24,.31,.35),Color(.46,.25,.12),Color(.20,.29,.20),Color(.34,.07,.10),Color(.52,.36,.11),Color(.09,.14,.23)]
    for index in range(6):
        civilian_models.append(_new_car("OncomingCamry%d"%index,civilian_rears,civilian_variants[index],"civilian",0,civilian_colors[index]))
    for index in range(10):
        var variant: String="patrol" if index%2==0 else "wagon"
        block_models.append(_new_car("SquirrelRoadblock%d"%index,block_rears,variant,"police",41+index,Color.WHITE))

func _load_fleet_definition(variant: String,path: String) -> Dictionary:
    var source: Node3D=(load(path) as PackedScene).instantiate() as Node3D
    var nodes := source.find_children("*","MeshInstance3D",true,false)
    var visual: MeshInstance3D=nodes[0] if not nodes.is_empty() else source as MeshInstance3D
    var mesh: Mesh=visual.mesh
    var shared: Array[ShaderMaterial]=[]
    for surface in range(mesh.get_surface_count()):
        var original:=mesh.surface_get_material(surface) as StandardMaterial3D
        var material:=ShaderMaterial.new();material.shader=TRAFFIC_SHADER
        material.set_shader_parameter("camera_visibility",1.0)
        material.set_shader_parameter("albedo_texture",original.albedo_texture)
        material.set_shader_parameter("normal_texture",original.normal_texture)
        material.set_shader_parameter("emission_texture",original.emission_texture)
        material.set_shader_parameter("lamp_energy",2.0 if original.resource_name=="FrontLenses" else 0.0)
        material.set_shader_parameter("fleet_livery",original.resource_name=="Body")
        if original.resource_name=="Body":
            material.set_shader_parameter("fleet_badge",FLEET_BADGE)
            material.set_shader_parameter("fleet_marks",FLEET_MARKS)
        shared.append(material)
    var definition := {"id":variant,"path":path,"mesh":mesh,"bounds":mesh.get_aabb(),"shared":shared}
    # Templates never enter World3D. Strong mesh/material references above
    # survive immediate deletion and cannot appear in the initial GPU frame.
    source.free()
    return definition

func _new_car(name_: String,rears: Array[ShaderMaterial],variant: String="patrol",role: String="police",unit_number: int=7,tint: Color=Color.WHITE) -> Node3D:
    var definition: Dictionary=fleet_definitions[variant]
    var mesh: Mesh=definition.mesh
    var size: Vector3=definition["size"]
    var pivot:=Node3D.new();pivot.name=name_;_world.add_child(pivot)
    var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.scale=Vector3.ONE*_scale;visual.position=definition.base_position
    var instance_materials: Array[ShaderMaterial]=[]
    visual.set_meta("fitted_scale",_scale)
    visual.set_meta("fleet_variant",variant)
    visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;pivot.add_child(visual)
    for surface in range(mesh.get_surface_count()):
        var original:=mesh.surface_get_material(surface) as StandardMaterial3D
        # Camera clearance belongs to this actual car. Sharing its body/front
        # material would ghost every Camry when just one blocks the chase view.
        var shared: Array[ShaderMaterial]=definition.shared
        var material: ShaderMaterial=shared[surface].duplicate() as ShaderMaterial
        material.set_shader_parameter("fleet_police",role=="police")
        material.set_shader_parameter("fleet_scale",_scale)
        material.set_shader_parameter("fleet_center",definition.center)
        material.set_shader_parameter("fleet_half_width",size.x*.5)
        material.set_shader_parameter("fleet_rear_z",-size.z*.5)
        material.set_shader_parameter("fleet_front_z",size.z*.5)
        material.set_shader_parameter("fleet_unit_number",unit_number)
        material.set_shader_parameter("fleet_tint",tint)
        if original.resource_name=="Body" and role=="police":
            beacon_materials.append(material)
            pivot.set_meta("beacon_material",material)
            pivot.set_meta("beacon_phase",float((beacon_materials.size()-1)%3)*.75)
        if original.resource_name=="RearLenses":
            material.set_shader_parameter("lamp_energy",1.2);rears.append(material)
        if not materials.has(material):materials.append(material)
        instance_materials.append(material)
        visual.set_surface_override_material(surface,material)
    pivot.visible=false
    pivot.set_meta("camera_visibility",1.0)
    pivot.set_meta("camera_coverage_initialized",false)
    pivot.set_meta("fleet_variant",variant)
    pivot.set_meta("fleet_role",role)
    pivot.set_meta("fitted_length",size.z)
    pivot.set_meta("fitted_size",size)
    pivot.set_meta("visualfitted_scale",_scale)
    pivot.set_meta("asset_path",definition.path)
    pivot.set_meta("instance_materials",instance_materials)
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
    var origin := Vector3(rear_x,Data.road_height(player.world_z)+rear_z*grade,player.world_z+rear_z)
    var camera_origin := Vector3(camera_x,Data.road_height(player.world_z)-host._behind()*grade+height,camera_z)
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
    var visible_cars: Array[Node3D]=[]
    for collection in [models,civilian_models,block_models]:
        for pivot: Node3D in collection:
            if pivot.visible: visible_cars.append(pivot)
            else: pivot.set_meta("camera_coverage_initialized",false)
    last_visible_cars=visible_cars.size();last_material_updates=0
    var samples := PackedVector4Array() if plain or visible_cars.is_empty() else ground_samples(host,camera_z)
    last_occlusion_sample_count=samples.size()
    # Hidden pool cars need no GPU uniform updates. A car becoming visible is
    # transformed above and receives ALL current uniforms before its first
    # submission, including after a camera yaw or a terrain-sector change.
    for pivot: Node3D in visible_cars:
        for material: ShaderMaterial in pivot.get_meta("instance_materials"):
            material.set_shader_parameter("vehicle_origin",origin)
            material.set_shader_parameter("camera_world",camera_origin)
            material.set_shader_parameter("road_grade",grade)
            material.set_shader_parameter("occlusion_sample_count",samples.size())
            if not samples.is_empty(): material.set_shader_parameter("occlusion_samples",samples)
            last_material_updates+=1
        var beacon_material: ShaderMaterial=pivot.get_meta("beacon_material") if pivot.has_meta("beacon_material") else null
        if beacon_material!=null:
            beacon_material.set_shader_parameter("fleet_flash",clock*8.0+float(pivot.get_meta("beacon_phase",0.0)))
    var overlay=host.get_parent().car_3d_overlay
    var eye: Vector3=overlay.camera.global_position
    var target: Vector3=overlay.model_root.global_transform*overlay.model_visual_center
    for pivot: Node3D in visible_cars:
        _clear_chase_camera(pivot,eye,target,delta)

func _clear_chase_camera(pivot: Node3D,eye: Vector3,target: Vector3,delta: float) -> void:
    var visual: MeshInstance3D=pivot.get_child(0)
    var desired := _camera_coverage(visual,eye,target)
    var previous: float=pivot.get_meta("camera_visibility",1.0)
    var initialized: bool=pivot.get_meta("camera_coverage_initialized",false)
    # A camera already inside the padded body must never spend another frame
    # drawing its hood across the whole framebuffer. Clear side cars recover
    # immediately; a merely intervening body ghosts over a short transition.
    var amount := desired if not initialized or desired==0.0 or desired==1.0 else lerpf(previous,desired,1.0-exp(-18.0*maxf(delta,0.0)))
    pivot.set_meta("camera_visibility",amount)
    pivot.set_meta("camera_coverage_initialized",true)
    if is_equal_approx(amount,previous): return
    for child in pivot.get_children():
        if not child is MeshInstance3D: continue
        var mesh: MeshInstance3D=child
        for surface in range(mesh.mesh.get_surface_count()):
            var material:=mesh.get_active_material(surface) as ShaderMaterial
            if material!=null: material.set_shader_parameter("camera_visibility",amount)

func _camera_coverage(visual: MeshInstance3D,eye: Vector3,target: Vector3) -> float:
    # Segment/OBB intersection uses the complete fitted model, including its
    # overhang and current heading/grade. A centre-distance toggle misses the
    # hood behind the camera and incorrectly hides ordinary adjacent passes.
    var inverse := visual.global_transform.affine_inverse()
    var actual_scale: float=visual.get_meta("fitted_scale",_scale)
    var box := visual.get_aabb().grow(CAMERA_CLEARANCE/actual_scale)
    var origin := inverse*eye
    var motion := inverse*target-origin
    if box.has_point(origin): return 0.0
    var enter := 0.0
    var leave := 1.0
    for axis in range(3):
        if absf(motion[axis])<.000001:
            if origin[axis]<box.position[axis] or origin[axis]>box.end[axis]: return 1.0
            continue
        var first: float=(box.position[axis]-origin[axis])/motion[axis]
        var last: float=(box.end[axis]-origin[axis])/motion[axis]
        enter=maxf(enter,minf(first,last));leave=minf(leave,maxf(first,last))
        if enter>leave: return 1.0
    return CAMERA_GHOST_COVERAGE if leave>0.0 and enter<1.0 else 1.0

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
