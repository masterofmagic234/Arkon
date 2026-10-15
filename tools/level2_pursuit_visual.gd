extends SceneTree
# Staged production views; behavior is checked by the real-input drive and
# pursuit mechanics gate. All models share the production camera/viewport.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
var output := "/tmp/pursuit-visuals"
var level
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    call_deferred("_run")
func _run() -> void:
    if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="forward_plus" or RenderingServer.get_current_rendering_driver_name()!="vulkan":
        push_error("PURSUIT VISUAL: real Forward+ framebuffer required");quit(1);return
    root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    RenderingServer.set_render_loop_enabled(false)
    DirAccess.make_dir_recursive_absolute(output)
    level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    for i in range(12): root.get_node("PauseManager").set_paused(false);await process_frame
    level.set_physics_process(false);level.set_process(false)
    level.state.race_started=true;level.state.countdown=0;level.state.race_time=20
    level.hud_panel.hide_countdown()
    var p=level.controller.player;var d=level.controller.pursuit
    var z := 0.0
    for at in range(900,2400,20):
        if d.safe_drop_zone(at,level.controller.track_x): z=at;break
    _put(p,z-220,0);p.speed=50
    d._begin(p,z,level.controller.track_x)
    level._process(1.0/60)
    if not d.flight_outside_view:
        push_error("PURSUIT VISUAL: new aircraft starts inside the camera");quit(1);return
    for i in range(312): d.prepare(1.0/60,level.state,p,[]);d.tick(1.0/60,level.state,p,[],level.controller.track_x)
    _rivals(p.world_z)
    await _capture("01-helicopter-warning")
    for i in range(120): d.prepare(1.0/60,level.state,p,[]);d.tick(1.0/60,level.state,p,[],level.controller.track_x)
    _put(p,z-42,-2.8);_rivals(p.world_z)
    await _capture("02-deployed-spikes")
    var with_heli: Image=await _image()
    level.car_3d_overlay.helicopter.root.visible=false
    var no_heli: Image=await _image()
    var changed := 0
    for y in range(20,480,2):
        for x in range(4,1276,2):
            var a:=with_heli.get_pixel(x,y);var b:=no_heli.get_pixel(x,y)
            if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.15: changed+=1
    if changed<100:
        push_error("PURSUIT VISUAL: helicopter not visible in actual scene (%d pixels)"%changed);quit(1);return
    _put(p,z-30,0)
    d.helicopter_x=Math.track_center_x(z/40,level.controller.track_x)-1.0
    d.helicopter_z=z;d.helicopter_height=5.0;d.helicopter_yaw=-.60
    await _capture("03-squirrel-airframe")
    d.radio.stop()
    d.radio.say("preview","ОРЕХ-1 · ПИЛОТ","Вижу беглеца. Захожу сзади, готовлю шипы!",2,2)
    d.radio.advance(.1)
    level.presentation._timer=0;level.presentation._process(.1)
    await _capture("04-pilot-radio")
    var rotor: Node3D=level.car_3d_overlay.helicopter.rotor
    var angle: float=rotor.rotation.y
    d.clock+=.1;level._process(1.0/60)
    if absf(rotor.rotation.y-angle)<.1:
        push_error("PURSUIT VISUAL: rotor is frozen");quit(1);return
    # Hold the player still: the old timed departure visibly vanished in this
    # case. The real camera must now release the entire rotor/tail first.
    for i in range(900):
        d.prepare(1.0/60,level.state,p,[]);d.tick(1.0/60,level.state,p,[],level.controller.track_x)
        level._process(1.0/60)
        if d.phase==&"idle":
            if not d.flight_outside_view:
                push_error("PURSUIT VISUAL: aircraft hidden before leaving frame");quit(1);return
            break
    if d.phase!=&"idle": push_error("PURSUIT VISUAL: departure never completes");quit(1);return
    await _capture("05-aircraft-departed")
    d.strips.clear()
    var lead=level.controller.ais[0]
    _put(lead.car,p.world_z+14,0);lead.car.speed=26;lead.car.set_inputs(0,0,.78)
    lead.attack_phase=&"brake";lead.brake_lane=0
    d.radio.stop();d.radio.say("brake-preview","БЕЛКА-1","Я впереди! Сейчас резко заторможу — пусть догоняет!",0,2);d.radio.advance(.1)
    await _capture("06-brake-check")
    d._begin(p,z,level.controller.track_x)
    _put(p,Data.TUNNEL_START+250,0);level._process(1.0/60)
    if level.car_3d_overlay.helicopter.root.visible:
        push_error("PURSUIT VISUAL: airframe renders through the tunnel roof");quit(1);return
    if not _moving_flight(): quit(1);return
    level.queue_free();current_scene=null
    for i in range(5): await process_frame
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    print("PURSUIT VISUAL: PASS — Forward+/Vulkan; offscreen ingress/complete departure; visible squirrel airframe/rotors/spikes; pilot subtitles and brake-check warning; tunnel occlusion; one viewport")
    quit(0)
func _put(car,z: float,lane: float) -> void:
    var c=level.controller
    var canonical: float=(z+car.grid_world_z_offset)/40
    car.lap=floori(canonical/c.track_pattern.size());car.segment_index=posmod(floori(canonical),c.track_pattern.size());car.segment_progress=canonical-floor(canonical)
    car.world_z=z;car.world_x=Math.track_center_x(z/40,c.track_x)+lane;car.lateral_offset=lane
    car.heading_yaw=atan2(Math.track_center_slope(z/40,c.track_x),40)
    level.camera_state.reset(level.controller.player)
    if car==level.controller.player:
        level.state.player_progress=car.physical_progress(c.track_pattern.size())
        level.controller._sync_hud()
        print("PURSUIT VISUAL: progress=",level.state.player_progress," HUD=",level.hud_background.get_node("Lap").text)
func _moving_flight() -> bool:
    var p=level.controller.player;var d=level.controller.pursuit
    d.stop();_put(p,1500,0);p.speed=Data.PLAYER_MAX_SPEED
    d._begin(p,p.world_z+p.speed*7.8+65,level.controller.track_x)
    level._process(1.0/60)
    if not d.flight_outside_view:
        push_error("PURSUIT VISUAL: high-speed ingress starts in view");return false
    var position := Vector3(d.helicopter_x,d.helicopter_height,d.helicopter_z)
    var deployed := false
    for frame in range(1100):
        var previous_phase: StringName=d.phase
        d.prepare(1.0/60,level.state,p,[])
        var tangent := atan2(Math.track_center_slope(p.track_phase()+.35,level.controller.track_x),40)
        var ratio: float=p.speed/Data.PLAYER_MAX_SPEED
        var steering := tangent+clampf(-p.lateral_offset*.08,-.15,.15)
        p.set_inputs(Data.steer_for_heading(steering,ratio),1,0)
        p.tick(1.0/60,true,level.controller.track_pattern,level.controller.track_x)
        d.tick(1.0/60,level.state,p,[],level.controller.track_x)
        level._process(1.0/60)
        var now := Vector3(d.helicopter_x,d.helicopter_height,d.helicopter_z)
        if now.distance_to(position)>6:
            push_error("PURSUIT VISUAL: active flight teleports");return false
        position=now
        if previous_phase==&"drop" and d.phase==&"depart":
            deployed=true
            if d.helicopter_z-p.world_z<25:
                push_error("PURSUIT VISUAL: high-speed drop leaves no reaction distance");return false
        if d.phase==&"idle":
            if not d.flight_outside_view or not deployed:
                push_error("PURSUIT VISUAL: high-speed departure hides in view or misses drop");return false
            return true
    push_error("PURSUIT VISUAL: high-speed flight never exits");return false
func _rivals(z: float) -> void:
    for i in range(3): _put(level.controller.ais[i].car,z-10-i*9,[-2.8,2.8,0.0][i])
func _capture(name_: String) -> void:
    level._process(1.0/60)
    level.presentation._timer=0;level.presentation._process(.1)
    var frame: Image=await _image()
    if frame.save_png(output+"/"+name_+".png")!=OK: push_error("PURSUIT VISUAL: cannot save "+name_);quit(1)
    print("PURSUIT VISUAL: captured ",name_)
func _image() -> Image:
    for i in range(3): await process_frame
    RenderingServer.force_draw(true)
    return root.get_texture().get_image()
