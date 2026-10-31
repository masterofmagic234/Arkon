extends "res://tools/level2_normal_render154_test.gd"
## The supplied phone screenshot shows33km/h with nearby pursuers. Drive that
## state through ordinary input/physics after the real preceding garden/film.
## No vehicle placement, visibility fault, render-loop replacement or teleport.
const Data = preload("res://scripts/race_level_data.gd")
func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    report["os"]=OS.get_name();report["engine"]=Engine.get_version_info()
    report["renderer"]=RenderingServer.get_current_rendering_method()
    report["scope"]["slow_throttle_near_rivals"]=true
    report["scope"]["preceding_actual_garden_and_film"]=true
    report["scope"]["physical_android"]=false
    report["physics_hz"]=Engine.physics_ticks_per_second
    var arguments:=OS.get_cmdline_args()
    var fixed_index:=arguments.find("--fixed-fps")
    report["fixed_render_clock_hz"]=int(arguments[fixed_index+1]) if fixed_index>=0 else 0
    report["hardware_fps_measured"]=false
    if DisplayServer.get_name()=="headless" or not RenderingServer.is_render_loop_enabled() or root.content_scale_mode!=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
        push_error("SLOW RIVALS154 requires the ordinary native loop/stretch");quit(1);return
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    root.size=Vector2i(2582,1220)
    await garden_to_film()
    for i in range(600):
        await process_frame
        if not root.get_node("SceneFlow")._transitioning:break
    level=current_scene
    if level==null or level.scene_file_path!="res://scenes/level2.tscn":
        push_error("SLOW RIVALS154 failed actual preceding route");quit(1);return
    await frames(8)
    # An input-only cruise controller holds the screenshot's low speed. The
    # actual drivetrain, enemies and contact solver continue uninterrupted.
    await drive_until(6.5,true)
    Input.action_release("race_accel")
    await capture("phone-33kmh-near-rivals")
    await capture_rival_pixels("phone-33kmh-near-rivals",true)
    if level.state.race_time<6.0:report.failures.append("Slow ordinary race did not reach6sec")
    var kmh: float=level.controller.player.speed/Data.SPEED_UNITS_PER_KMH
    if kmh<28 or kmh>40:report.failures.append("Slow screenshot speed not reached: "+str(kmh))
    Input.action_press("race_brake")
    await drive_until(level.state.race_time+1.3,false)
    await capture("phone-braking-near-rivals")
    await capture_rival_pixels("phone-braking-near-rivals",false)
    await drive_until(level.state.race_time+2.2,false)
    Input.action_release("race_brake")
    await capture("phone-reverse-near-rivals")
    await capture_rival_pixels("phone-reverse-near-rivals",false)
    current_scene=null;level.queue_free();level=null;await frames(6)
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    var hashes:={}
    for path in ["scripts/race_240sx_overlay.gd","scripts/race_traffic_3d.gd","scripts/race_camera_state.gd","scripts/race_scenery_depth.gd","scripts/race_squirrel_helicopter.gd","shaders/race_traffic.gdshader","scripts/scene_flow.gd","scripts/game_level2_pseudo3d.gd","scenes/level2.tscn","tools/level2_normal_render154_test.gd","tools/level2_slow_rivals154_test.gd"]:
        hashes[path]=FileAccess.get_sha256("res://"+path)
    report["source_sha256"]=hashes
    FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    if report.failures.is_empty():print("LEVEL2 SLOW RIVALS154: PASS")
    else:push_error("LEVEL2 SLOW RIVALS154: "+str(report.failures))
    quit(0 if report.failures.is_empty() else 1)
func drive_until(goal_time: float,cruise: bool) -> void:
    var goal_speed: float=33.0*Data.SPEED_UNITS_PER_KMH
    var reached:=false
    for i in range(600):
        if level.state.race_time>=goal_time:reached=true;break
        if cruise:
            Input.action_press("race_accel",clampf(.16+(goal_speed-float(level.controller.player.speed))*.25,0.0,1.0))
        if i%30==0:print("SLOW RIVALS154 PROGRESS frame=",i," race=",level.state.race_time," countdown=",level.state.countdown," paused=",paused," kmh=",level.controller.player.speed/Data.SPEED_UNITS_PER_KMH)
        await process_frame
    if not reached:report.failures.append("Ordinary simulation did not reach target race time "+str(goal_time))
func capture_rival_pixels(label: String,require_close: bool) -> void:
    var processing: bool=level.is_processing();var physics: bool=level.is_physics_processing()
    level.set_process(false);level.set_physics_process(false)
    await frames(3);await RenderingServer.frame_post_draw
    var target=level.car_3d_overlay
    var shown: Image=root.get_texture().get_image()
    var target_image: Image=target.viewport.get_texture().get_image()
    var rivals:=[];var close_count:=0;var pixel_count:=0
    for i in range(level.controller.ais.size()):
        var car=level.controller.ais[i].car
        var model: Node3D=target.traffic.models[i]
        var visible_before: bool=model.visible
        var dz: float=car.world_z-level.controller.player.world_z
        if absf(dz)<20:close_count+=1
        model.hide();await frames(3);await RenderingServer.frame_post_draw
        var without_final: Image=root.get_texture().get_image()
        var without_target: Image=target.viewport.get_texture().get_image()
        model.visible=visible_before;await frames(3)
        var in_target:=difference_samples(target_image,without_target)
        var in_final:=difference_samples(shown,without_final)
        if in_target>20 and in_final>20:pixel_count+=1
        var coverage: float=model.get_meta("camera_visibility",1.0)
        var lateral: float=car.world_x-level.controller.player.world_x
        if require_close and absf(lateral)>=2.1 and dz>0:
            if not is_equal_approx(coverage,1.0):report.failures.append(label+": legitimate adjacent rival was ghosted")
        rivals.append({"index":i,"relative_z":dz,"relative_x":lateral,"speed_kmh":car.speed/Data.SPEED_UNITS_PER_KMH,"model_visible_flag":visible_before,"camera_visibility":coverage,"target_difference_samples":in_target,"composite_difference_samples":in_final,"phase":String(level.controller.ais[i].attack_phase)})
    var row:={"name":label,"race_time":level.state.race_time,"player_speed_kmh":level.controller.player.speed/Data.SPEED_UNITS_PER_KMH,"gear":level.controller.player.gear,"close_rivals":close_count,"rivals_with_pixels":pixel_count,"rivals":rivals,"occlusion_samples":target.traffic.materials[0].get_shader_parameter("occlusion_sample_count"),"camera_transform":str(target.camera.global_transform),"container_transform":str(target.get_global_transform())}
    print("SLOW RIVALS154 CASE ",JSON.stringify(row))
    if not report.has("nearby_rivals"):report["nearby_rivals"]=[]
    report.nearby_rivals.append(row)
    if require_close and close_count<2:report.failures.append(label+": actual AI did not catch up within20m")
    if require_close and pixel_count<2:report.failures.append(label+": two nearby rivals are absent from target/final pixels")
    level.set_process(processing);level.set_physics_process(physics)
