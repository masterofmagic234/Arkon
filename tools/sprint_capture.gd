extends SceneTree
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
    if DisplayServer.get_name()=="headless": quit(1);return
    var output := "/tmp/sprint-capture"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(1280,720)
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    var level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    for i in range(5): await process_frame
    level.set_physics_process(false);level.set_process(false)
    level.state.race_started=true;level.state.countdown=0
    level.hud_panel.hide_countdown()
    var car=level.controller.player
    var views := [["01-forest-start",0.0],["02-forest-bend",580.0],["03-fields",1500.0],["04-bridge-approach",2020.0],["05-bridge",2340.0],["06-tunnel-approach",2680.0],["07-tunnel",3020.0],["08-tunnel-exit",3470.0],["09-city",4180.0],["10-finish",4760.0],["11-camry",90.0],["12-braking",90.0]]
    var report: Array=[]
    for view in views:
        _place(car,view[1],level)
        car.speed=45;car.heading_yaw=0;car.steer_applied=0
        level.state.player_progress=car.physical_progress(level.controller.track_pattern.size())
        car.brake_in=1 if view[0]=="12-braking" else 0
        for i in range(3):
            var rival=level.controller.ais[i].car
            _place(rival,float(view[1])+[18.0,33.0,48.0][i],level)
            rival.lateral_offset=[-1.9,1.8,0.0][i];rival.world_x+=rival.lateral_offset
            rival.brake_in=car.brake_in
        for i in range(18):
            level._process(1.0/60.0)
            level.controller._sync_hud()
            await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(output.path_join(view[0]+".png"))
        report.append({"view":view[0],"z":view[1],"sector":Data.sector_at(view[1]),"draw_calls":RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)})
        print("SPRINT CAPTURE: ",view[0])
    FileAccess.open(output.path_join("render-budget.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    level.queue_free();for i in range(4): await process_frame
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    print("SPRINT CAPTURE: PASS");quit(0)
func _place(car,z: float,level) -> void:
    var canonical := (z+float(car.grid_world_z_offset))/40.0
    var n: int=level.controller.track_pattern.size()
    car.lap=floori(canonical/n);car.segment_index=posmod(floori(canonical),n);car.segment_progress=canonical-floor(canonical)
    car.world_z=z;car.world_x=Math.track_center_x(z/40.0,level.controller.track_x);car.lateral_offset=0
