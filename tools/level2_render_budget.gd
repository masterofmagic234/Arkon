extends SceneTree
# CPU submission only; these values do not measure GPU or phone FPS.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
    var output := "/tmp/race-budget.json"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1536,694)
    RenderingServer.set_render_loop_enabled(false)
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    var level=load("res://scenes/level2.tscn").instantiate();root.add_child(level);current_scene=level
    for i in range(6): await process_frame
    level.set_process(false);level.set_physics_process(false)
    var results: Array=[]
    for z: float in [0,350,1300,2300,3340,4300,4910,5400,7100,8100]:
        var car=level.controller.player
        var canonical := (z+float(car.grid_world_z_offset))/40.0
        car.segment_index=floori(canonical);car.segment_progress=canonical-floor(canonical)
        car.world_z=z;car.world_x=Math.track_center_x(z/40,level.controller.track_x);car.lateral_offset=0
        car.heading_yaw=atan2(Math.track_center_slope(z/40,level.controller.track_x),40)
        level.camera_state.reset(car);level._process(0)
        var values: Array[int]=[]
        var renderer=level.renderer
        var dimensions := Vector2(1536,694)
        for i in range(30):
            var begin := Time.get_ticks_usec()
            renderer.scenery.begin(renderer,dimensions);renderer.scenery.draw(renderer,dimensions)
            if i>=8: values.append(Time.get_ticks_usec()-begin)
        values.sort()
        var entry := {"z":z,"sector":Data.sector_at(z),"scenery_cpu_us":values[values.size()/2],"triangles":renderer.scenery.triangles,"points":renderer.scenery.transformed_vertices}
        results.append(entry);print("RACE CPU BUDGET: ",entry)
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
    level.queue_free();for i in range(3): await process_frame
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    quit(0)
