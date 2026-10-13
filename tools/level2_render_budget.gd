extends SceneTree
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
    var output := "/tmp/race-budget.json"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    root.size=Vector2i(1280,720)
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    var level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    for i in range(6): await process_frame
    level.set_process(false);level.set_physics_process(false)
    var results: Array=[]
    for z: float in [580,1500,2340,3210,3500,3800]:
        var car=level.controller.player
        var canonical := (z+float(car.grid_world_z_offset))/40.0
        car.segment_index=floori(canonical);car.segment_progress=canonical-floor(canonical)
        car.world_z=z;car.world_x=Math.track_center_x(z/40,level.controller.track_x);car.lateral_offset=0
        car.heading_yaw=atan2(Math.track_center_slope(z/40,level.controller.track_x),40)
        level.camera_state.reset(car)
        var values: Dictionary={"road_us":[],"scenery_us":[],"total_us":[]}
        for i in range(30):
            level._process(1.0/60.0);await process_frame
            if i<8: continue
            for key in values: values[key].append(level.renderer.render_profile.get(key,0))
        var entry := {"z":z,"sector":Data.sector_at(z)}
        for key in values:
            values[key].sort();entry[key]=values[key][values[key].size()/2]
        entry["draw_calls"]=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
        entry["scenery_triangles"]=level.renderer.scenery.triangles
        entry["world_vertices"]=level.renderer.scenery.transformed_vertices
        var surfaces: int=level.renderer.scenery.opaque.mesh.get_surface_count()
        for batch in level.renderer.scenery.textures.values()+level.renderer.scenery.foreground.values(): surfaces+=batch.mesh.get_surface_count()
        entry["scenery_surfaces"]=surfaces
        results.append(entry);print("RACE BUDGET: ",entry)
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
    level.queue_free();for i in range(3): await process_frame
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    quit(0)
