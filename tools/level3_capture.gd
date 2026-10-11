extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
    var output := "/tmp/level3-capture"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(1280,720)
    var game := load("res://scenes/level3_store.tscn").instantiate() as Level3Store
    root.add_child(game)
    current_scene=game
    for i in range(8): await physics_frame
    if game.player==null or not game.navigation.ready:
        push_error("LEVEL 3 CAPTURE: scene not ready")
        quit(1)
        return
    game.player.set_physics_process(false)
    game.set_physics_process(false)
    game.set_process(false)
    for enemy in game._enemies: enemy.set_physics_process(false)
    game.hint_label.text=""
    var camera: Camera2D=game.camera
    camera.position_smoothing_enabled=false
    var report := {"godot":Engine.get_version_info()["string"],"adapter":RenderingServer.get_video_adapter_name(),"props":Level3StoreData.get_furniture_layout().size(),"lights":game.environment.light_count,"navigation_samples":game.navigation.samples,"walkable_samples":game.navigation.walkable,"views":[]}
    var shots := [
        ["01-entry",Vector2(215,688),1.70],
        ["02-diner",Vector2(233,225),1.70],
        ["03-bar",Vector2(621,533),1.70],
        ["04-kitchen",Vector2(690,179),1.90],
        ["05-stock",Vector2(1025,199),2.1],
        ["06-overview",Vector2(570,450),0.74],
        ["07-diner-detail",Vector2(179,245),2.50],
        ["08-mobile",Vector2(621,533),1.70]
    ]
    for shot in shots:
        game.player.global_position=shot[1]+Vector2(22,40)
        camera.global_position=shot[1]
        camera.zoom=Vector2.ONE*float(shot[2])
        camera.reset_smoothing()
        if shot[0]=="06-overview": game.hud.visible=false
        else: game.hud.visible=true
        if shot[0]=="08-mobile":
            game.hud.mobile_active=true
            game.hud._layout()
        for i in range(14): await process_frame
        await RenderingServer.frame_post_draw
        var save_error := root.get_texture().get_image().save_png(output+"/"+shot[0]+".png")
        if save_error!=OK:
            push_error("LEVEL 3 CAPTURE: saving failed")
            quit(1)
            return
        var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
        var view := {"name":shot[0],"render_counters_available":draw_calls>0}
        if draw_calls>0:
            view["total_draw_calls"]=draw_calls
            view["total_primitives"]=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
        report["views"].append(view)
        print("LEVEL 3 CAPTURE: ",shot[0])
    var file := FileAccess.open(output+"/render-budget.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")+"\n")
    file.close()
    game.queue_free()
    for i in range(4): await process_frame
    root.get_node("AudioManager").shutdown()
    OS.delay_msec(80)
    quit(0)
