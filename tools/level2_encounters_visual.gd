extends SceneTree
const Math=preload("res://scripts/race_math.gd")
const Contacts=preload("res://scripts/race_vehicle_contacts.gd")
var level
var out: String="/tmp/level2-encounters"
var report: Dictionary={"note":"Staged production-vehicle/framebuffer QA, not a complete driving replay or phone FPS measurement."}
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):out=arg.trim_prefix("--output=")
    call_deferred("run")
func frames(n: int=5) -> void:
    for i in range(n):await process_frame
func put(car,z: float,x: float) -> void:
    var phase: float=(z+car.grid_world_z_offset)/40
    car.lap=floori(phase/level.controller.track_pattern.size());car.segment_index=posmod(floori(phase),level.controller.track_pattern.size());car.segment_progress=phase-floor(phase)
    car.world_z=z;car.world_x=Math.track_center_x(z/40,level.controller.track_x)+x;car.lateral_offset=x
func capture(name: String) -> void:
    level.state.player_progress=level.controller.player.physical_progress(level.controller.track_pattern.size())
    level.state.lap_time=level.state.race_time
    level.controller._sync_hud()
    level.camera_state.reset(level.controller.player)
    level._process(1)
    level.presentation._timer=0;level.presentation._process(.1)
    await frames(8);await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out.path_join(name+".png"))
func run() -> void:
    DirAccess.make_dir_recursive_absolute(out)
    root.size=Vector2i(1280,720)
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level;await frames(10)
    level.set_physics_process(false);level.state.race_started=true;level.state.race_time=30
    var player=level.controller.player;var pursuit=level.controller.pursuit;var director=pursuit.encounters
    pursuit.cooldown=10000
    put(player,900,1.5);player.speed=55
    for i in range(level.controller.ais.size()):put(level.controller.ais[i].car,player.world_z-20-i*10,[-2.5,2.5,0][i])
    for i in range(director.traffic.size()):director.traffic[i].place(930+i*90,-2.45,level.controller.track_x)
    await capture("oncoming-camry")
    report.oncoming_visible=level.car_3d_overlay.traffic.civilian_models[0].visible
    report.oncoming_yaw=director.traffic[0].heading_yaw
    report.shared_camera_count=level.car_3d_overlay.world_root.find_children("*","Camera3D",true,false).size()
    report.model_length=level.car_3d_overlay.traffic.fitted_size.z
    # Stage one high-relative-speed crossing, then let the production contact
    # authority resolve momentum, hit reporting and the actual render pose.
    put(player,920,-2.45);player.speed=65
    director.traffic[0].place(930,-2.45,level.controller.track_x)
    pursuit.prepare(1.0/60,level.state,player,level.controller.ais)
    put(player,936,-2.45)
    pursuit._contacts(player,level.controller.ais)
    report.oncoming_hits=director.traffic_hits
    report.oncoming_impact_speed=player.speed
    report.oncoming_separation=Contacts.contact(player,director.traffic[0],Vector2(player.world_x,player.world_z),Vector2(director.traffic[0].world_x,director.traffic[0].world_z),false).length()
    await capture("physical-oncoming-impact")
    var block: Dictionary=director.roadblocks[0];director._build_block(block)
    put(player,block.z-55,0);player.speed=45
    for i in range(level.controller.ais.size()):put(level.controller.ais[i].car,player.world_z-20-i*10,[-2.5,2.5,0][i])
    for car in director.traffic:car.place(player.world_z-600,-2.45,level.controller.track_x)
    director.clock=2
    await capture("squirrel-roadblock")
    report.roadblock_visible=level.car_3d_overlay.traffic.block_models[0].visible and level.car_3d_overlay.traffic.block_models[1].visible
    report.gap_center=block.gap_center;report.gap_width=block.gap_width
    report.actual_model_gap=block.cars[1].world_x-block.cars[0].world_x-level.car_3d_overlay.traffic.fitted_size.z
    # Same production swept solve as a fixed-step crossing into a blocker.
    var blocker=block.cars[0]
    put(player,block.z-8,blocker.lateral_offset);player.speed=60
    pursuit.prepare(1.0/60,level.state,player,level.controller.ais)
    put(player,block.z+8,blocker.lateral_offset)
    pursuit._contacts(player,level.controller.ais)
    report.hit_count=director.roadblock_hits;report.impact_serial=pursuit.impact_serial;report.post_contact_speed=player.speed
    report.contact_separation=Contacts.contact(player,blocker,Vector2(player.world_x,player.world_z),Vector2(blocker.world_x,blocker.world_z),false).length()
    await capture("physical-roadblock-impact")
    var ok: bool=report.shared_camera_count==1 and report.actual_model_gap>=3.15 and report.oncoming_hits==1 and report.oncoming_impact_speed<30 and report.oncoming_separation<.01 and report.oncoming_visible and report.roadblock_visible and report.hit_count==1 and report.impact_serial>0 and report.post_contact_speed<30 and report.contact_separation<.01
    report.result="PASS" if ok else "FAIL"
    var file:=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    level.queue_free();current_scene=null;await frames(6);await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    if not ok:push_error("LEVEL2 ENCOUNTER VISUAL: fixture failed")
    print("LEVEL2 ENCOUNTER VISUAL: "+report.result);quit(0 if ok else 1)
