extends SceneTree
## Actual scene/profile integration and bounded rendering-work checks.
## Staged poses, not a driving replay or a physical Redmi FPS measurement.
const Data = preload("res://scripts/race_level_data.gd")
const RoadMath = preload("res://scripts/race_math.gd")
const Store = preload("res://scripts/graphics_store156.gd")
var level
var output := "/tmp/level2-quality156"
var failures: Array[String] = []
var cases: Array = []
var captures: Array = []
var observed_settings_changes := 0
var fixture_hardware := {"platform":"Android", "gpu_name":"Mali-G52 MC2", "gpu_vendor":"ARM", "model":"Redmi 10", "cpu_cores":8, "memory_bytes":4294967296, "headless":false, "software_renderer":false}

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error("LEVEL2 QUALITY156: "+message)

func frames(count: int=3) -> void:
    for i in range(count): await process_frame

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    if DisplayServer.get_name()=="headless" or not RenderingServer.is_render_loop_enabled():
        push_error("LEVEL2 QUALITY156 requires the normal native graphics loop")
        quit(1);return
    root.size=Vector2i(2400,1080)
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=true
    var settings=root.get_node("GraphicsSettings")
    settings.settings_changed.connect(_on_settings_changed)
    settings.initialize_for_device(fixture_hardware,output.path_join("fixture-graphics.cfg"))
    settings.set_mode("auto")
    level=load("res://scenes/level2.tscn").instantiate()
    root.add_child(level);current_scene=level
    for i in range(180):
        await process_frame
        if level.ready_for_play: break
    check(level.ready_for_play,"Real scene never reached vehicle presentation readiness")
    level.set_process(false);level.set_physics_process(false)
    var overlay=level.car_3d_overlay
    var world_rid: RID=overlay.world_root.get_world_3d().scenario
    var traffic=overlay.traffic
    check(traffic.models.size()==3 and traffic.civilian_models.size()==6 and traffic.block_models.size()==10,"Profile task changed pooled gameplay vehicle counts")
    check(overlay.initial_transforms_flushed,"Profile application skipped the initial transform flush")
    check(overlay.viewport.msaa_3d==Viewport.MSAA_DISABLED,"Car viewport unexpectedly gained multisampling")
    var baseline_counts: Dictionary={}
    for tier in ["high","balanced","low","low-step2"]:
        var before_signals: int=observed_settings_changes
        if tier=="low-step2":
            # Replay the real persisted per-level adaptation path. No fake
            # frame timing or physical-device calibration is injected here.
            var stored: Dictionary=Store.load_config(settings.config_path)
            stored.mode="auto";stored.adaptive_steps={"level2":2}
            check(Store.save_config(settings.config_path,stored)==OK,"Could not write isolated adaptive-state fixture")
            settings.initialize_for_device(fixture_hardware,settings.config_path)
        else:
            settings.set_mode(tier)
        var profile: Dictionary=settings.get_level_settings(&"level2")
        check(observed_settings_changes>before_signals,tier+" did not emit the central settings_changed signal")
        check(level.graphics_profile==profile and overlay.graphics_profile==profile,tier+" did not reach the actual scene through the central signal")
        for z: float in [900.0,2300.0,Data.BRIDGE_START+240.0,Data.TUNNEL_START-30.0,Data.TUNNEL_START+220.0,Data.CITY_START+240.0]:
            for yaw: float in [0.0,1.55,PI]:
                place(level.controller.player,z,0,yaw)
                for i in range(3):place(level.controller.ais[i].car,z+30+i*15,[-2.4,2.4,0][i],yaw)
                level.camera_state.reset(level.controller.player)
                level._process(0.0)
                var physical := physics_snapshot()
                var logical_size: Vector2i=overlay.viewport.size
                var anchor: Vector2=level.renderer.get_player_ground_anchor(level.get_viewport_rect().size)
                var fov: float=overlay.camera.fov
                await frames()
                check(physical==physics_snapshot(),tier+" changed physical poses while physics was disabled")
                check(logical_size==overlay.viewport.size and anchor.is_equal_approx(level.renderer.get_player_ground_anchor(level.get_viewport_rect().size)) and is_equal_approx(fov,overlay.camera.fov),tier+" changed the shared logical projection")
                check(overlay.viewport.msaa_3d==Viewport.MSAA_DISABLED,tier+" gained car MSAA")
                check(overlay.viewport.get_camera_3d()==overlay.camera and overlay.world_root.get_world_3d().scenario==world_rid,tier+" changed the shared camera or scenario")
                var pixels: float=logical_size.x*logical_size.y*pow(overlay.viewport.scaling_3d_scale,2)
                var budget: int=profile.car_pixel_budget
                check(is_equal_approx(overlay.viewport.scaling_3d_scale,1.0) if budget==0 else pixels<=budget+2.0,tier+" did not apply its real child viewport pixel budget")
                check(is_equal_approx(overlay.viewport.mesh_lod_threshold,float(profile.mesh_lod_threshold)),tier+" did not apply mesh LOD bias")
                for disc in overlay.helicopter.rotor_blurs:
                    check(disc.visible==bool(profile.rotor_blur),tier+" left cosmetic rotor alpha overdraw enabled")
                check(overlay.helicopter.rotor_blurs.size()==2,"Static batching consumed a quality-controlled rotor disc")
                var key: String=str(Vector2(z,yaw))
                var metrics := {"road_samples":level.renderer.road_mesh.last_sample_count,"scenery_vertices":level.renderer.scenery.transformed_vertices,"scenery_triangles":level.renderer.scenery.triangles,"scenery_groups":level.renderer.scenery.selected_groups}
                if tier=="high":baseline_counts[key]=metrics
                elif baseline_counts.has(key):
                    check(metrics.road_samples<baseline_counts[key].road_samples,tier+" did not reduce road construction work at "+key)
                    check(metrics.scenery_vertices<=baseline_counts[key].scenery_vertices,tier+" increased scenery transforms at "+key)
                check(not level.renderer.road_mesh._road_indices.is_empty() or not level.renderer.road_mesh._far_road_indices.is_empty(),tier+" lost the asphalt at "+key)
                cases.append({"tier":tier,"z":z,"yaw":yaw,"logical_size":str(logical_size),"render_scale":overlay.viewport.scaling_3d_scale,"effective_3d_pixels":pixels,"metrics":metrics})
                if tier in ["high","low","low-step2"] and is_zero_approx(yaw) and (is_equal_approx(z,900.0) or is_equal_approx(z,Data.TUNNEL_START+220.0)):
                    await capture(tier,z)
        # Surface repair used on Android focus/resume must retain the profile.
        var before_scale: float=overlay.viewport.scaling_3d_scale
        var before_size: Vector2i=overlay.viewport.size
        overlay._restore_render_target()
        await frames()
        check(before_size==overlay.viewport.size and is_equal_approx(before_scale,overlay.viewport.scaling_3d_scale),tier+" surface restore lost its resolution profile")
    await verify_hidden_pool_updates()
    var report := {"result":"PASS" if failures.is_empty() else "FAIL","failures":failures,"cases":cases,"captures":captures,"central_settings_signals":observed_settings_changes,"scope":{"actual_production_scene":true,"actual_native_render_loop":true,"staged_pose_fixture":true,"phone_fps_measured":false,"physical_android":false,"physics_and_ai_changed":false,"injected_hardware_only_for_configuration_selection":fixture_hardware,"persisted_adaptation_fixture_not_measured_adaptation":true},"renderer":RenderingServer.get_current_rendering_method(),"actual_gpu":RenderingServer.get_video_adapter_name(),"actual_platform":OS.get_name(),"engine":Engine.get_version_info()}
    FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    traffic=null;overlay=null;current_scene=null;level.queue_free();level=null
    await frames(6)
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    if failures.is_empty():print("LEVEL2 QUALITY156: PASS")
    quit(0 if failures.is_empty() else 1)

func _on_settings_changed() -> void:
    observed_settings_changes+=1

func capture(tier: String,z: float) -> void:
    await RenderingServer.frame_post_draw
    var filename: String=tier+("-tunnel.png" if z>Data.TUNNEL_START else "-near-fleet.png")
    root.get_texture().get_image().save_png(output.path_join(filename))
    captures.append({"file":filename,"tier":tier,"z":z,"yaw":0.0,"logical_viewport":str(level.car_3d_overlay.viewport.size),"car_3d_scale":level.car_3d_overlay.viewport.scaling_3d_scale})

func verify_hidden_pool_updates() -> void:
    var overlay=level.car_3d_overlay
    var traffic=overlay.traffic
    place(level.controller.player,Data.BRIDGE_START-300,0)
    for i in range(3):place(level.controller.ais[i].car,level.controller.player.world_z+30+i*12,[-2.4,2.4,0][i])
    place(level.controller.ais[2].car,level.controller.player.world_z+1000,0)
    level.camera_state.reset(level.controller.player);level._process(0.0)
    var hidden: Node3D=traffic.models[2]
    check(not hidden.visible,"Expected a genuinely hidden physical pool car")
    var material: ShaderMaterial=hidden.get_meta("instance_materials")[0]
    material.set_shader_parameter("road_grade",777.0)
    level._process(0.0)
    check(is_equal_approx(float(material.get_shader_parameter("road_grade")),777.0),"Hidden pool car still received per-frame road uniforms")
    check(traffic.last_material_updates<traffic.materials.size(),"Every pooled material still received updates")
    place(level.controller.ais[2].car,level.controller.player.world_z+45,0)
    level._process(0.0)
    check(hidden.visible,"Re-entering physical car did not become visible")
    check(not is_equal_approx(float(material.get_shader_parameter("road_grade")),777.0),"Newly visible car missed its first current-frame uniform prime")
    check(int(material.get_shader_parameter("occlusion_sample_count"))==35,"Elevated route lost the complete terrain/tunnel ray slices")
    level.controller.ais[1].car.brake_in=1.0;level._process(1.0)
    check(float(traffic.rear_materials[1].get_shader_parameter("lamp_energy"))>6.9 and float(traffic.rear_materials[0].get_shader_parameter("lamp_energy"))<1.3,"Visible-only updates broke independent braking lights")

func place(car,z: float,lane: float,yaw: float=0.0) -> void:
    var phase: float=(z+car.grid_world_z_offset)/Data.SEGMENT_HEIGHT
    var n: int=level.controller.track_pattern.size()
    car.lap=floori(phase/n);car.segment_index=posmod(floori(phase),n)
    car.segment_progress=phase-floor(phase);car.world_z=z
    car.world_x=RoadMath.track_center_x(z/Data.SEGMENT_HEIGHT,level.controller.track_x)+lane
    car.lateral_offset=lane;car.heading_yaw=yaw

func physics_snapshot() -> Array:
    var snapshot: Array=[]
    for car in [level.controller.player,level.controller.ais[0].car,level.controller.ais[1].car,level.controller.ais[2].car]:
        snapshot.append([car.world_x,car.world_z,car.heading_yaw,car.speed,car.throttle,car.brake_in])
    return snapshot
