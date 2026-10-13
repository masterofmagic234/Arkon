extends SceneTree
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
    var native := DisplayServer.get_name()!="headless"
    var output := "/tmp/sprint-driving"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    if native:
        DirAccess.make_dir_recursive_absolute(output)
        root.size=Vector2i(1280,720)
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    var level=load("res://scenes/level2.tscn").instantiate()
    root.add_child(level);current_scene=level
    for i in range(4): await process_frame
    level.set_physics_process(false);level.set_process(false)
    for i in range(181): level.controller.update(1.0/60.0)
    var car=level.controller.player
    var ai_offroad_samples := 0;var total_samples := 0
    var sectors: Dictionary={}
    var capture := 0
    var checkpoints := [400.0,2200.0,Data.BRIDGE_START-200,Data.BRIDGE_START+360,Data.BRIDGE_END+200,Data.TUNNEL_START-300,Data.TUNNEL_START-10,Data.TUNNEL_START+300,Data.TUNNEL_END-10,Data.route_length()-100]
    for step in range(24000):
        var at: float=car.track_phase()
        sectors[Data.sector_at(float(car.world_z))]=true
        var tangent := atan2(Math.track_center_slope(at+.25,level.controller.track_x),40.0)
        var center := Math.track_center_x(at,level.controller.track_x)
        var ratio := clampf(float(car.speed)/Data.PLAYER_MAX_SPEED,0,1)
        var target_yaw := tangent+clampf((center-float(car.world_x))*.08,-.15,.15)
        var steer := clampf(target_yaw/(Data.NFS_MAX_HEADING_YAW*lerpf(1,.48,ratio)),-1,1)
        var safe_speed := Math.safe_corner_speed(at,level.controller.track_x,Data.PLAYER_MAX_SPEED,Data.NFS_MAX_HEADING_YAW,Data.CORNER_GRIP_ACCEL)
        var braking := clampf((float(car.speed)-safe_speed)/3.0,0,.85)
        level.controller.handle_input(steer,1.0,braking)
        level.controller.update(1.0/60.0)
        for ai in level.controller.ais:
            if ai.car.offroad_amount>.1: ai_offroad_samples+=1
            total_samples+=1
        if level.state.race_finished: break
        if step%(60 if native else 120)==0:
            if native: level._process(1.0)
            await process_frame
            if native and capture<checkpoints.size() and float(car.world_z)>=checkpoints[capture]:
                await RenderingServer.frame_post_draw
                root.get_texture().get_image().save_png(output.path_join("drive-%02d.png"%capture))
                capture+=1
    if not level.state.mission_complete or car.physical_progress(level.controller.track_pattern.size())<level.controller.track_pattern.size() or sectors.size()!=Data.SECTOR_NAMES.size() or not level.presentation.finished:
        push_error("LEVEL2 PLAYTHROUGH: natural seven-sector sprint did not finish");quit(1);return
    if float(ai_offroad_samples)/total_samples>.03:
        push_error("LEVEL2 PLAYTHROUGH: rivals repeatedly leave asphalt");quit(1);return
    var state=level.state
    var elapsed: float=state.race_time
    if absf(elapsed-Data.TARGET_RACE_SECONDS)>6.0:
        push_error("LEVEL2 PLAYTHROUGH: nominal drive missed the 3:30 target: %.2fs"%elapsed);quit(1);return
    for i in range(60): level.controller.update(1.0/60.0)
    if state.race_time!=elapsed: push_error("LEVEL2 PLAYTHROUGH: results keep ticking");quit(1);return
    level.presentation.continue_button.pressed.emit()
    for i in range(12): await process_frame
    if current_scene==null or current_scene.scene_file_path!="res://scenes/level3_store.tscn":
        push_error("LEVEL2 PLAYTHROUGH: Continue failed to load diner");quit(1);return
    current_scene.queue_free()
    for i in range(3): await process_frame
    await Teardown.drain_audio(self)
    print("LEVEL2 PLAYTHROUGH: PASS — natural %.2fkm sprint, all seven sectors; live rivals; %.2fs; place %d/4; AI offroad %.3f%%; actual Continue"%[Data.route_length()/1000.0,elapsed,state.position,float(ai_offroad_samples)/total_samples*100.0])
    quit(0)
