extends SceneTree
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    var level=load("res://scenes/level2.tscn").instantiate()
    root.add_child(level);current_scene=level
    for i in range(4): await process_frame
    level.set_physics_process(false);level.set_process(false)
    for i in range(181): level.controller.update(1.0/60.0)
    var car=level.controller.player
    var ai_offroad_samples := 0;var total_samples := 0
    for step in range(24000):
        var at: float=car.track_phase()
        var tangent := atan2(Math.track_center_slope(at+.25,level.controller.track_x),40.0)
        var center := Math.track_center_x(at,level.controller.track_x)
        var ratio := clampf(float(car.speed)/Data.PLAYER_MAX_SPEED,0,1)
        var target_yaw := tangent+clampf((center-float(car.world_x))*.08,-.15,.15)
        var steer := clampf(target_yaw/(Data.NFS_MAX_HEADING_YAW*lerpf(1,.48,ratio)),-1,1)
        var upcoming := absf(atan2(Math.track_center_slope(at+.8,level.controller.track_x),40.0))
        var safe := clampf((1.0-upcoming/(Data.NFS_MAX_HEADING_YAW*.85))/.52,.5,1)
        var braking := clampf((float(car.speed)-Data.PLAYER_MAX_SPEED*safe)/6.0,0,.75)
        level.controller.handle_input(steer,1.0,braking)
        level.controller.update(1.0/60.0)
        for ai in level.controller.ais:
            if ai.car.offroad_amount>.1: ai_offroad_samples+=1
            total_samples+=1
        if level.state.race_finished: break
        if step%120==0: await process_frame
    if not level.state.mission_complete or car.lap!=3 or level.state.best_lap<=0 or not level.presentation.finished:
        push_error("LEVEL2 PLAYTHROUGH: natural three-lap race did not finish");quit(1);return
    if float(ai_offroad_samples)/total_samples>.03:
        push_error("LEVEL2 PLAYTHROUGH: rivals repeatedly leave asphalt");quit(1);return
    var state=level.state
    var elapsed: float=state.race_time
    for i in range(60): level.controller.update(1.0/60.0)
    if state.race_time!=elapsed: push_error("LEVEL2 PLAYTHROUGH: results keep ticking");quit(1);return
    level.presentation.continue_button.pressed.emit()
    for i in range(12): await process_frame
    if current_scene==null or current_scene.scene_file_path!="res://scenes/level3_store.tscn":
        push_error("LEVEL2 PLAYTHROUGH: Continue failed to load diner");quit(1);return
    current_scene.queue_free()
    for i in range(3): await process_frame
    await Teardown.drain_audio(self)
    print("LEVEL2 PLAYTHROUGH: PASS — natural 3 laps; live rivals; %.2fs; place %d/4; AI offroad %.3f%%; actual Continue"%[elapsed,state.position,float(ai_offroad_samples)/total_samples*100.0])
    quit(0)
