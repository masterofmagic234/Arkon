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
        var tangent := atan2(Math.track_center_slope(at+.35,level.controller.track_x),40.0)
        var center := Math.track_center_x(at,level.controller.track_x)
        # React to the actual locked warning lane using normal steering. Never
        # teleport, suppress attacks or grant puncture immunity in a playthrough.
        var target_lane := 1.4
        for ai in level.controller.ais:
            if absf(ai.car.world_z-car.world_z)<18 and ai.attack_phase in [&"warn",&"ram"]:
                target_lane=-2.6 if ai.attack_side>0 else 3.3
        for strip in level.controller.pursuit.strips:
            var distance: float=float(strip.z)-car.world_z
            if distance> -6 and distance<maxf(210,car.speed*4):
                target_lane=-signf(float(strip.offset))*2.8
        # Read the visible lead car / brake warning and steer into the open
        # lane. This still uses ordinary steering, not position correction.
        for ai in level.controller.ais:
            var lead: float=ai.car.world_z-car.world_z
            if lead>0 and lead<70 and ai.attack_phase in [&"merge",&"brake_warn",&"brake"]:
                target_lane=3.5
        var encounters=level.controller.pursuit.encounters
        var block: Dictionary=encounters.next_block(car)
        if not block.is_empty() and float(block.z)-car.world_z<maxf(220,car.speed*4):
            target_lane=float(block.gap_center)
        # The opposing carriageway is occupied, so an evasive brake-check
        # maneuver cannot blindly steer into an approaching civilian Camry.
        for oncoming in encounters.traffic:
            var distance: float=oncoming.world_z-car.world_z
            if distance> -6 and distance<maxf(100,car.speed*1.7) and absf(target_lane-oncoming.lateral_offset)<2.1:
                target_lane=2.8
        var ratio := clampf(float(car.speed)/Data.PLAYER_MAX_SPEED,0,1)
        var target_yaw := tangent+clampf((center+target_lane-float(car.world_x))*.08,-.15,.15)
        var steer := Data.steer_for_heading(target_yaw,ratio)
        var safe_speed := Math.safe_corner_speed(at,level.controller.track_x,Data.PLAYER_MAX_SPEED,Data.NFS_MAX_HEADING_YAW,Data.CORNER_GRIP_ACCEL)
        # Keep the real chassis' modest cornering margin instead of braking at
        # the first conservative advisory threshold during a close pursuit.
        var braking := clampf((float(car.speed)-safe_speed-.8)/3.0,0,.85)
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
    var pursuit_stats := [level.controller.pursuit.drops,level.controller.pursuit.spike_hits,level.controller.pursuit.ram_hits]
    var brake_checks := 0
    for ai in level.controller.ais: brake_checks+=ai.brake_checks
    print("LEVEL2 IMPACT LOG: "+JSON.stringify(level.controller.pursuit.encounters.impact_log))
    print("LEVEL2 LIVE PRESSURE: seconds=%.2f traffic=%d roadblocks=%d passed=%d attacks=%s brakes=%d rams=%d"%[state.race_time,level.controller.pursuit.encounters.traffic_hits,level.controller.pursuit.encounters.roadblock_hits,level.controller.pursuit.encounters.roadblocks_passed,str(level.controller.ais.map(func(ai): return ai.maneuver_serial)),brake_checks,level.controller.pursuit.ram_hits])
    if brake_checks<1:
        push_error("LEVEL2 PLAYTHROUGH: no genuine overtake/brake check in the live pursuit");quit(1);return
    if pursuit_stats[0]<3:
        push_error("LEVEL2 PLAYTHROUGH: helicopter never completed enough live attacks");quit(1);return
    var elapsed: float=state.race_time
    print("LEVEL2 ENCOUNTER STATS: traffic=%d roadblock=%d passed=%d brake_checks=%d"%[level.controller.pursuit.encounters.traffic_hits,level.controller.pursuit.encounters.roadblock_hits,level.controller.pursuit.encounters.roadblocks_passed,brake_checks])
    if absf(elapsed-Data.TARGET_RACE_SECONDS)>6.0:
        push_error("LEVEL2 PLAYTHROUGH: nominal drive missed the 3:30 target: %.2fs; drops=%d spikes=%d rams=%d"%[elapsed,level.controller.pursuit.drops,level.controller.pursuit.spike_hits,level.controller.pursuit.ram_hits]);quit(1);return
    for i in range(60): level.controller.update(1.0/60.0)
    if state.race_time!=elapsed: push_error("LEVEL2 PLAYTHROUGH: results keep ticking");quit(1);return
    level.presentation.continue_button.pressed.emit()
    for i in range(12): await process_frame
    if current_scene==null or current_scene.scene_file_path!="res://scenes/level3_store.tscn":
        push_error("LEVEL2 PLAYTHROUGH: Continue failed to load diner");quit(1);return
    current_scene.queue_free()
    for i in range(3): await process_frame
    await Teardown.drain_audio(self)
    print("LEVEL2 PLAYTHROUGH: PASS — natural %.2fkm pursuit, all seven sectors; %.2fs; drops/hits/rams=%s; brake checks=%d; AI offroad %.3f%%; actual Continue"%[Data.route_length()/1000.0,elapsed,str(pursuit_stats),brake_checks,float(ai_offroad_samples)/total_samples*100.0])
    quit(0)
