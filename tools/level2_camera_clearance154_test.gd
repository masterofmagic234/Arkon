extends SceneTree
## Geometry invariants complementary to the real-input/native slow-rival test.
## Uses complete production Camry meshes and actual camera/vehicle transforms.
var level
var failures: Array[String]=[]
var cases:=[]
var output := "/tmp/level2-camera-clearance154"
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")
func check(ok: bool,message: String) -> void:
    if not ok:failures.append(message);push_error("CAMERA CLEARANCE154: "+message)
func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    # Headless windows default to a square; use the actual supplied phone
    # aspect so this fixture's camera height matches the demonstrated hood.
    root.size=Vector2i(2582,1220)
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    level=load("res://scenes/level2.tscn").instantiate()
    var template_names: Array[String]=[]
    for path in ["res://assets/level2/camry/camry_runtime.glb","res://assets/level2/fleet155/camry_patrol.glb","res://assets/level2/fleet155/camry_interceptor.glb","res://assets/level2/fleet155/camry_wagon.glb"]:
        var template=load(path).instantiate()
        template_names.append(String(template.name));template.free()
    var world_children: Array[String]=[]
    level.get_node("Car3DOverlay/Car3DViewport/Car3DWorld").child_entered_tree.connect(func(child: Node):world_children.append(String(child.name)))
    root.add_child(level);current_scene=level
    for i in range(60):
        await process_frame
        if level.car_3d_overlay.is_model_ready():break
    level.set_process(false);level.set_physics_process(false)
    for template_name in template_names:
        check(not world_children.has(template_name),"Unfitted source template entered the actual rendering world: "+template_name)
        cases.append({"case":"unfitted source never enters world","template":template_name,"present":world_children.has(template_name)})
    var player=level.controller.player
    put(player,90,0,0)
    for i in range(3):put(level.controller.ais[i].car,125+i*10,2.45 if i%2 else -2.45,0)
    level.camera_state.reset(player);level._process(1.0)
    var traffic=level.car_3d_overlay.traffic
    for i in range(3):check_car_materials(traffic.models[i],1.0,"clear approach%d"%i)
    put(level.controller.ais[2].car,-110,0,0);level._process(.016)
    put(level.controller.ais[2].car,87.8,0,0);level._process(0.0)
    check_car_materials(traffic.models[2],.10,"Newly visible intervening body was opaque on its first delta0 prime")
    cases.append({"case":"newly visible body first delta0 prime","visibility":traffic.models[2].get_meta("camera_visibility")})
    for dz: float in [-8.1,-4.45]:
        put(level.controller.ais[2].car,90+dz,0,0)
        level._process(1.0)
        check(traffic.models[2].visible,"Camera-intersecting complete body was rejected by its centre before clearance")
        check_car_materials(traffic.models[2],0.0,"eye inside full body atdz"+str(dz))
        check_car_materials(traffic.models[0],1.0,"Unrelated left car inherited another car's clipping")
        check_car_materials(traffic.models[1],1.0,"Unrelated right car inherited another car's clipping")
        cases.append({"case":"whole body intersects eye","relative_z":dz,"visibility":traffic.models[2].get_meta("camera_visibility")})
    for lane: float in [-2.45,2.45]:
        for dz: float in [-2,0,8]:
            put(level.controller.ais[2].car,90+dz,lane,0)
            level._process(1.0)
            check_car_materials(traffic.models[2],1.0,"Legitimate adjacent pass lane/dz"+str(Vector2(lane,dz)))
            cases.append({"case":"adjacent pass preserved","lane":lane,"relative_z":dz,"visibility":traffic.models[2].get_meta("camera_visibility")})
    for yaw: float in [-1.2,-.6,0,.6,1.2,PI]:
        put(player,90,0,yaw);level.camera_state.reset(player);level._process(1.0)
        var overlay=level.car_3d_overlay
        var eye: Vector3=overlay.camera.global_position
        var aim: Vector3=overlay.model_root.global_transform*overlay.model_visual_center
        var middle: Vector3=(eye+aim)*.5
        var rear_x: float=player.world_x+sin(yaw)*.45
        var rear_z: float=cos(yaw)*.45
        put(level.controller.ais[2].car,player.world_z+rear_z+middle.z,rear_x-middle.x,.45)
        level._process(1.0)
        var coverage: float=traffic.models[2].get_meta("camera_visibility")
        check(coverage<=.101,"Real sight corridor is blocked after camera yaw"+str(yaw))
        var pose:=Vector2(level.controller.ais[2].car.world_x,level.controller.ais[2].car.world_z)
        traffic._clear_chase_camera(traffic.models[2],eye,aim,1.0)
        check(pose==Vector2(level.controller.ais[2].car.world_x,level.controller.ais[2].car.world_z),"Camera clearance changed physical vehicle position")
        cases.append({"case":"rotated body/camera sight corridor","yaw":yaw,"visibility":coverage})
    put(player,90,0,0);level.camera_state.reset(player);level._process(1.0)
    var overlay=level.car_3d_overlay
    var eye: Vector3=overlay.camera.global_position
    var aim: Vector3=overlay.model_root.global_transform*overlay.model_visual_center
    var block: Node3D=traffic.block_models[0]
    block.show();block.position=Vector3(0,0,18);block.rotation.y=PI*.5
    traffic._clear_chase_camera(block,eye,aim,1.0)
    check_car_materials(block,1.0,"Crosswise roadblock ahead was incorrectly hidden")
    cases.append({"case":"crosswise roadblock ahead preserved","visibility":block.get_meta("camera_visibility")})
    # Clear local refs before the production scene teardown.
    block=null;overlay=null;traffic=null;player=null
    current_scene=null;level.queue_free();level=null
    for i in range(6):await process_frame
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"failures":failures,"scope":"production-model geometry/material invariants; not a phone reproduction"},"  "))
    if failures.is_empty():print("LEVEL2 CAMERA CLEARANCE154: PASS")
    quit(0 if failures.is_empty() else 1)
func check_car_materials(pivot: Node3D,wanted: float,message: String) -> void:
    check(is_equal_approx(float(pivot.get_meta("camera_visibility",1.0)),wanted),message+" meta")
    var visual: MeshInstance3D=pivot.get_child(0)
    for surface in range(visual.mesh.get_surface_count()):
        var material:=visual.get_active_material(surface) as ShaderMaterial
        check(material!=null and is_equal_approx(float(material.get_shader_parameter("camera_visibility")),wanted),message+" actual material"+str(surface))
func put(car,z: float,lane: float,yaw: float) -> void:
    var canonical: float=(z+car.grid_world_z_offset)/40.0
    car.segment_index=floori(canonical);car.segment_progress=canonical-floor(canonical)
    car.world_z=z;car.world_x=lane;car.lateral_offset=lane;car.heading_yaw=yaw
