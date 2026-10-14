extends SceneTree
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
    if DisplayServer.get_name()=="headless": quit(1);return
    var output := "/tmp/sprint-capture"
    var subset := PackedStringArray()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
        if arg.begins_with("--views="): subset=arg.trim_prefix("--views=").split(",")
    DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(1280,720)
    for arg in OS.get_cmdline_user_args():
        if arg=="--phone": root.size=Vector2i(1536,694)
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    var level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    for i in range(5): await process_frame
    level.set_physics_process(false);level.set_process(false)
    level.state.race_started=true;level.state.countdown=0
    level.hud_panel.hide_countdown()
    var car=level.controller.player
    var views := [["01-forest-start",0.0],["02-forest-bend",350.0],["03-fields",2300.0],["04-bridge-approach",4020.0],["05-bridge",Data.BRIDGE_START+360.0],["06-tunnel-approach",Data.TUNNEL_START-70.0],["07-tunnel",Data.TUNNEL_START+220.0],["08-tunnel-exit",7320.0],["09-city",Data.OUTSKIRTS_START+650.0],["10-finish",Data.route_length()-40.0],["11-camry",90.0],["12-braking",90.0],["13-bridge-uphill",3890.0],["14-after-bridge",5120.0],["15-tunnel-downhill",Data.TUNNEL_START-210.0],["16-tunnel-left-wall",6300.0,-4.4,-.58],["17-tunnel-right-wall",6300.0,4.4,.58],["18-portal-near",Data.TUNNEL_START-12.0],["19-portal-passing",6090.0],["20-turn-entry",230.0],["21-turn-apex",350.0],["22-turn-exit",490.0],["23-fields-hairpin",2300.0],["24-tunnel-bend",6450.0],["25-distant-mountain",4240.0],["26-city-before-exit",7260.0],["27-city-mouth",7358.0],["28-city-just-outside",7362.0],["29-city-after-100m",7460.0],["30-city-after-140m",7500.0],["31-sign-approach",1900.0],["32-sign-passing",1940.0],["33-sign-passed",1966.0],["34-traffic-side-angle",90.0,0.0,-.40],["35-forest-descent",Data.BRIDGE_END+90],["36-forest-low",Data.TUNNEL_START-360],["37-outskirts-home",Data.OUTSKIRTS_START+460],["38-outskirts-shops",Data.OUTSKIRTS_START+770],["39-city-halo",Data.CITY_START+480],["40-city-halo-yaw",Data.CITY_START+480,0.0,.28],["41-ranger",160.0],["42-camp",890.0],["43-farm",1710.0],["44-grain",2360.0],["45-lookout",4260.0],["46-forest-stop",4590.0],["47-fuel",7660.0],["48-diner",8380.0]]
    var report: Array=[]
    for view in views:
        if not subset.is_empty() and not subset.has(view[0]): continue
        _place(car,view[1],level)
        car.speed=45
        car.heading_yaw=atan2(Math.track_center_slope(float(view[1])/40.0,level.controller.track_x),40.0)
        if view.size()>2:
            car.lateral_offset=view[2];car.world_x+=view[2];car.heading_yaw=view[3]
        car.steer_applied=clampf(car.heading_yaw/(Data.NFS_MAX_HEADING_YAW*.67),-1.0,1.0)
        level.camera_state.reset(car)
        level.state.player_progress=car.physical_progress(level.controller.track_pattern.size())
        car.brake_in=1 if view[0]=="12-braking" else 0
        for i in range(3):
            var rival=level.controller.ais[i].car
            _place(rival,float(view[1])+[18.0,33.0,48.0][i],level)
            rival.lateral_offset=[-1.9,1.8,0.0][i];rival.world_x+=rival.lateral_offset
            rival.brake_in=car.brake_in
            rival.heading_yaw=atan2(Math.track_center_slope(rival.world_z/40,level.controller.track_x),40.0)
            if view[0]=="34-traffic-side-angle": rival.heading_yaw=.35
        for i in range(18):
            level._process(1.0/60.0)
            level.controller._sync_hud()
            await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(output.path_join(view[0]+".png"))
        report.append({"view":view[0],"z":view[1],"sector":Data.sector_at(view[1]),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
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
