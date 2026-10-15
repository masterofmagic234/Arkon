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
    for i in range(72): d.prepare(1.0/60,level.state,p,[]);d.tick(1.0/60,level.state,p,[],level.controller.track_x)
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
    var rotor: Node3D=level.car_3d_overlay.helicopter.rotor
    var angle: float=rotor.rotation.y
    d.clock+=.1;level._process(1.0/60)
    if absf(rotor.rotation.y-angle)<.1:
        push_error("PURSUIT VISUAL: rotor is frozen");quit(1);return
    _put(p,Data.TUNNEL_START+250,0);level._process(1.0/60)
    if level.car_3d_overlay.helicopter.root.visible:
        push_error("PURSUIT VISUAL: airframe renders through the tunnel roof");quit(1);return
    level.queue_free();current_scene=null
    for i in range(5): await process_frame
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    print("PURSUIT VISUAL: PASS — actual Forward+/Vulkan; visible original squirrel airframe, rotating rotors, locked warning lane and grounded deployed spikes; tunnel hides aircraft; no extra viewport")
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
