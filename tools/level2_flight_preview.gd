extends "res://tools/level2_pursuit_visual.gd"
# Staged production-camera movie frames, not a phone capture or a live chase.
func _run() -> void:
    if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="forward_plus":
        push_error("FLIGHT PREVIEW: native Forward+ required");quit(1);return
    root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    RenderingServer.set_render_loop_enabled(false)
    level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    for i in range(12): root.get_node("PauseManager").set_paused(false);await process_frame
    level.set_physics_process(false);level.set_process(false)
    level.state.race_started=true;level.state.countdown=0;level.state.race_time=20
    level.hud_panel.hide_countdown()
    var p=level.controller.player;var d=level.controller.pursuit
    p.speed=32
    var target:=0.0
    for at in range(600,2400,20):
        _put(p,at,0);target=d.planned_drop_z(p,level.controller.track_x)
        if d.safe_drop_zone(target,level.controller.track_x) and d.flight.duration<13: break
    d._begin(p,target,level.controller.track_x)
    DirAccess.make_dir_recursive_absolute(output)
    var frames:=ceili(minf(20,d.flight.duration+d.FALL_SECONDS+6.5)*30)
    var samples: Array=[]
    for frame in range(frames):
        for step in range(2):
            var dt:=1.0/60
            d.prepare(dt,level.state,p,[])
            var tangent:=atan2(Math.track_center_slope(p.track_phase()+.35,level.controller.track_x),40)
            var steering:=tangent+clampf(-p.lateral_offset*.08,-.15,.15)
            p.set_inputs(Data.steer_for_heading(steering,p.speed/Data.PLAYER_MAX_SPEED),clampf((32-p.speed)*.4,0,1),clampf((p.speed-32)*.15,0,1))
            p.tick(dt,true,level.controller.track_pattern,level.controller.track_x)
            d.tick(dt,level.state,p,[],level.controller.track_x);level.state.race_time+=dt
        level._process(1.0/30);level.controller._sync_hud()
        for model in level.car_3d_overlay.traffic.models: model.hide()
        level.presentation._timer=0;level.presentation._process(1.0/30)
        var picture: Image=await _image()
        picture.resize(960,540,Image.INTERPOLATE_LANCZOS)
        picture.save_png(output.path_join("frame-%04d.png"%frame))
        samples.append({"frame":frame,"phase":d.phase,"pitch":d.helicopter_pitch,"bank":d.helicopter_bank,"velocity":str(d.flight.velocity),"collective":d.flight.collective})
    var report:=FileAccess.open(output.path_join("preview.json"),FileAccess.WRITE)
    report.store_string(JSON.stringify({"renderer":"forward_plus","fps":30,"frames":frames,"staged":true,"samples":samples}));report.close()
    level.queue_free();current_scene=null
    for i in range(5): await process_frame
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    print("FLIGHT PREVIEW: PASS — staged production-camera frames ",frames)
    quit(0)
