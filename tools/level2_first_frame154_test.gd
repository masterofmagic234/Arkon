extends "res://tools/level2_normal_render154_test.gd"
## Inspect first actual target draw and first post-draw after SceneFlow unlocks,
## before any gas. Baseline swaps cached PackedScene resources only, never files.
var baseline_dir := ""
var baseline_flow_only := false
var _original_scene: PackedScene
var _baseline_scene: PackedScene
var _first_target: Image
var _first_final: Image
var _first_car_target: Image
var _captured := false
var _target_captured := false
var _was_processing := true
var _was_physics := true
var _startup := {}
func _init() -> void:
    super()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--baseline-source-dir="):baseline_dir=arg.trim_prefix("--baseline-source-dir=")
        if arg=="--baseline-flow-only":baseline_flow_only=true
func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    if DisplayServer.get_name()=="headless" or not RenderingServer.is_render_loop_enabled() or root.content_scale_mode!=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
        push_error("FIRST FRAME154 needs ordinary native rendering/stretch");quit(1);return
    if not baseline_dir.is_empty():
        if baseline_flow_only:
            var old_flow:=load(baseline_dir.path_join("scripts/scene_flow.gd")) as Script
            if old_flow==null:push_error("Cannot load retained baseline SceneFlow");quit(1);return
            var flow=root.get_node("SceneFlow")
            flow.set_script(old_flow)
            flow._ready()
        elif not install_baseline():quit(1);return
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    root.size=Vector2i(2582,1220)
    RenderingServer.frame_post_draw.connect(observe_startup)
    await garden_to_film()
    for i in range(600):
        await process_frame
        if _captured:break
    if not _captured:
        push_error("FIRST FRAME154 did not observe first unlocked gameplay draw");quit(1);return
    RenderingServer.frame_post_draw.disconnect(observe_startup)
    level=current_scene
    # The first shown images above are already retained. Stop only subsequent
    # gameplay updates to compare the same pose with the240 hidden.
    level.car_3d_overlay.model_root.hide()
    await frames(3);await RenderingServer.frame_post_draw
    var bare_target: Image=level.car_3d_overlay.viewport.get_texture().get_image()
    var bare_final: Image=root.get_texture().get_image()
    var target_pixels:=difference_samples(_first_car_target,bare_target)
    var final_pixels:=difference_samples(_first_final,bare_final)
    level.car_3d_overlay.model_root.show()
    level.set_process(_was_processing);level.set_physics_process(_was_physics)
    _startup["player_target_difference_samples"]=target_pixels
    _startup["player_composite_difference_samples"]=final_pixels
    _startup["first_target_alpha_samples"]=alpha_samples(_first_target)
    _startup["first_unlocked_target_alpha_samples"]=alpha_samples(_first_car_target)
    _startup["first_target_vs_unlocked_difference_samples"]=difference_samples(_first_target,_first_car_target)
    _startup["first_target_alpha_mask_difference_samples"]=alpha_difference_samples(_first_target,_first_car_target)
    var colors:=player_color_samples(_first_target,_first_car_target)
    _startup["first_target_matching_player_color_samples"]=colors.matching
    _startup["unlocked_reference_nonblack_player_color_samples"]=colors.reference
    _startup["raw_target_size_matches_unlocked"]=_first_target.get_size()==_first_car_target.get_size()
    _startup["baseline_source_dir"]=baseline_dir
    _startup["baseline_overrides"]=["SceneFlow"] if baseline_flow_only else (["vehicle overlay","traffic","traffic shader"] if not baseline_dir.is_empty() else [])
    _startup["source_sha256"]={}
    for path in ["scripts/scene_flow.gd","scripts/race_240sx_overlay.gd","scripts/race_traffic_3d.gd","shaders/race_traffic.gdshader","tools/level2_first_frame154_test.gd"]:
        _startup.source_sha256[path]=FileAccess.get_sha256("res://"+path)
    if not baseline_dir.is_empty():
        _startup["executed_baseline_sha256"]={}
        for path in (["scripts/scene_flow.gd"] if baseline_flow_only else ["scripts/race_240sx_overlay.gd","scripts/race_traffic_3d.gd","shaders/race_traffic.gdshader"]):
            _startup.executed_baseline_sha256[path]=FileAccess.get_sha256(baseline_dir.path_join(path))
    _startup["physical_android"]=false
    _startup["trigger"]="first frame_post_draw with current Level2 and SceneFlow transitioning=false; no driving input"
    _startup["failures"]=[]
    _startup["raw_target_pose_pass"]=bool(_startup.raw_target_size_matches_unlocked) and int(_startup.first_target_alpha_mask_difference_samples)<=10
    _startup["raw_target_player_color_pass"]=int(colors.reference)>=100 and float(colors.matching)>=float(colors.reference)*.75
    if baseline_flow_only:
        _startup["expected_old_raw_pose_error"]=true
        if bool(_startup.raw_target_pose_pass):_startup.failures.append("Retained old SceneFlow did not reproduce the first-target pose error")
    if not baseline_flow_only and baseline_dir.is_empty():
        if not bool(_startup.raw_target_pose_pass):_startup.failures.append("First actual vehicle target has a different model silhouette/position than its unlocked picture")
        if not bool(_startup.raw_target_player_color_pass):_startup.failures.append("First actual vehicle target is missing the controlled car's nonblack colors")
    if target_pixels<100:_startup.failures.append("240 absent from first unlocked target")
    if final_pixels<100:_startup.failures.append("240 absent from first unlocked composite")
    _first_target.save_png(output.path_join("first-actual-target-draw.png"))
    _first_car_target.save_png(output.path_join("first-unlocked-target.png"))
    _first_final.save_png(output.path_join("first-unlocked-composite.png"))
    FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(_startup,"  "))
    print("FIRST FRAME154 CASE ",JSON.stringify(_startup))
    _first_target=null;_first_final=null;_first_car_target=null
    current_scene=null;level.queue_free();level=null;await frames(6)
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    if _original_scene!=null:_original_scene.take_over_path("res://scenes/level2.tscn")
    _baseline_scene=null;_original_scene=null
    if _startup.failures.is_empty():print("LEVEL2 FIRST FRAME154: PASS")
    else:push_error("LEVEL2 FIRST FRAME154: "+str(_startup.failures))
    quit(0 if _startup.failures.is_empty() else 1)
func observe_startup() -> void:
    if _captured:return
    var scene=current_scene
    if scene==null or scene.scene_file_path!="res://scenes/level2.tscn":return
    var overlay=scene.car_3d_overlay
    if overlay==null or not overlay.is_model_ready():return
    var calls:=RenderingServer.viewport_get_render_info(overlay.viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
    if not _target_captured and calls>0:
        _target_captured=true
        _first_target=overlay.viewport.get_texture().get_image()
        var visible_meshes:=[]
        for mesh: MeshInstance3D in overlay.world_root.find_children("*","MeshInstance3D",true,false):
            if mesh.is_visible_in_tree():visible_meshes.append(str(overlay.world_root.get_path_to(mesh)))
        var flow=root.get_node("SceneFlow")
        var flow_script:=flow.get_script() as GDScript
        _startup["first_target_state"]={"camera":str(overlay.camera.global_transform),"fov":overlay.camera.fov,"target_size":str(overlay.viewport.size),"model_scale":str(overlay.model_instance.scale),"model_transform":str(overlay.model_instance.global_transform),"ready_3d":overlay.ready_3d,"draws":calls,"visible_meshes":visible_meshes,"image_size":str(_first_target.get_size()),"image_format":_first_target.get_format(),"automatic_render_loop":RenderingServer.is_render_loop_enabled(),"flow_script_path":flow_script.resource_path,"flow_loaded_source_sha256":flow_script.source_code.sha256_text(),"initial_transforms_flushed":overlay.get("initial_transforms_flushed")}
    if root.get_node("SceneFlow")._transitioning:return
    _captured=true
    _first_final=root.get_texture().get_image()
    _first_car_target=overlay.viewport.get_texture().get_image()
    _was_processing=scene.is_processing();_was_physics=scene.is_physics_processing()
    scene.set_process(false);scene.set_physics_process(false)
    var rivals:=[]
    var fitted_center: Vector3=overlay.model_instance.global_transform*overlay._calculate_bounds().get_center()
    for i in range(scene.controller.ais.size()):
        var car=scene.controller.ais[i].car
        var pivot: Node3D=overlay.traffic.models[i]
        var mesh: MeshInstance3D=pivot.get_child(0)
        rivals.append({"index":i,"world":str(Vector2(car.world_x,car.world_z)),"relative_z":car.world_z-scene.controller.player.world_z,"visible_flag":pivot.visible,"camera_visibility":pivot.get_meta("camera_visibility",1.0),"eye_inside_padded_model":mesh.get_aabb().grow(.18/overlay.traffic._scale).has_point(mesh.global_transform.affine_inverse()*overlay.camera.global_position)})
    _startup.merge({"countdown":scene.state.countdown,"race_time":scene.state.race_time,"player_speed":scene.controller.player.speed,"player_world":str(Vector2(scene.controller.player.world_x,scene.controller.player.world_z)),"camera":str(overlay.camera.global_transform),"controlled_visual_center":str(fitted_center),"rivals":rivals,"draw_calls":calls,"target_size":str(overlay.viewport.size),"window":str(root.size),"viewport_rect":str(scene.get_viewport_rect()),"camera_current":overlay.viewport.get_camera_3d()==overlay.camera,"target_updates":overlay.viewport.render_target_update_mode,"container_rect":str(overlay.get_global_rect()),"physics_hz":Engine.physics_ticks_per_second})
func alpha_samples(picture: Image) -> int:
    if picture==null:return -1
    var n:=0
    for y in range(0,picture.get_height(),3):
        for x in range(0,picture.get_width(),3):
            if picture.get_pixel(x,y).a>.1:n+=1
    return n
func alpha_difference_samples(a: Image,b: Image) -> int:
    if a.get_size()!=b.get_size():return -1
    var n:=0
    for y in range(0,a.get_height(),3):
        for x in range(0,a.get_width(),3):
            if absf(a.get_pixel(x,y).a-b.get_pixel(x,y).a)>.04:n+=1
    return n
func player_color_samples(a: Image,b: Image) -> Dictionary:
    var counts:={"reference":0,"matching":0}
    if a.get_size()!=b.get_size():return counts
    for y in range(0,a.get_height(),3):
        for x in range(0,a.get_width(),3):
            var reference:=b.get_pixel(x,y)
            if reference.a<.9 or maxf(reference.r,maxf(reference.g,reference.b))<.05:continue
            counts.reference+=1
            var actual:=a.get_pixel(x,y)
            if actual.a>.9 and maxf(absf(actual.r-reference.r),maxf(absf(actual.g-reference.g),absf(actual.b-reference.b)))<.18:counts.matching+=1
    return counts
func install_baseline() -> bool:
    var runtime:=output.path_join("baseline-runtime")
    DirAccess.make_dir_recursive_absolute(runtime)
    var traffic_path:=runtime.path_join("traffic.gd")
    var overlay_path:=runtime.path_join("overlay.gd")
    var traffic_source:=FileAccess.get_file_as_string(baseline_dir.path_join("scripts/race_traffic_3d.gd"))
    traffic_source=traffic_source.replace("res://shaders/race_traffic.gdshader",baseline_dir.path_join("shaders/race_traffic.gdshader"))
    var overlay_source:=FileAccess.get_file_as_string(baseline_dir.path_join("scripts/race_240sx_overlay.gd")).replace("class_name Race240SXOverlay","")
    overlay_source=overlay_source.replace("res://scripts/race_traffic_3d.gd",traffic_path)
    FileAccess.open(traffic_path,FileAccess.WRITE).store_string(traffic_source)
    FileAccess.open(overlay_path,FileAccess.WRITE).store_string(overlay_source)
    var old_script:=load(overlay_path) as Script
    if old_script==null:push_error("Cannot load exact retained baseline overlay");return false
    _original_scene=load("res://scenes/level2.tscn") as PackedScene
    var instance:=_original_scene.instantiate()
    instance.get_node("Car3DOverlay").set_script(old_script)
    _baseline_scene=PackedScene.new()
    var error:=_baseline_scene.pack(instance)
    instance.free()
    if error!=OK:push_error("Cannot pack baseline-only cached scene");return false
    _baseline_scene.take_over_path("res://scenes/level2.tscn")
    return true
