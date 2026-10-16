extends SceneTree
# Native timings compare this host; they cannot establish phone frame rates.
const Data=preload("res://scripts/level_data.gd")
var output := "/tmp/park-render-budget.json"
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    call_deferred("_run")
func _run() -> void:
    if DisplayServer.get_name()=="headless": quit(1);return
    root.size=Vector2i(1280,720)
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    var game: Node3D=load("res://game.tscn").instantiate()
    root.add_child(game);current_scene=game
    var player: Node3D=game.get_node("Player");player.set_physics_process(false)
    for i in range(24): await process_frame
    for enemy in get_nodes_in_group("level1_enemy"): enemy.set_physics_process(false)
    var camera: Camera3D=player.get_node("Camera3D")
    var report := {"adapter":RenderingServer.get_video_adapter_name(),"resolution":[1280,720],"probes":[]}
    var probes := [["entry",Vector2i(5,30),Vector2i(9,28),3.0],["pond",Vector2i(14,15),Vector2i(11,9),2.1],["ruins",Vector2i(37,14),Vector2i(34,5),2.0],["golden-oak",Vector2i(36,21),Vector2i(38,27),5.5]]
    for probe in probes:
        player.position=Data.cell_center_world(probe[1])+Vector3.UP*.9;player.rotation=Vector3.ZERO
        camera.look_at(Data.cell_center_world(probe[2])+Vector3.UP*float(probe[3]))
        for i in range(20): await RenderingServer.frame_post_draw
        var times: Array[float]=[];var calls: Array[int]=[];var triangles: Array[int]=[]
        for i in range(48):
            var start := Time.get_ticks_usec()
            await RenderingServer.frame_post_draw
            times.append(float(Time.get_ticks_usec()-start)/1000.0)
            calls.append(RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
            triangles.append(RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
        times.sort();calls.sort();triangles.sort()
        var result := {"view":probe[0],"median_ms":times[24],"p95_ms":times[45],"draw_calls":calls[24],"primitives":triangles[24]}
        report.probes.append(result);print("PARK RENDER PROBE: ",result)
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    game.queue_free()
    for i in range(3): await process_frame
    root.get_node("AudioManager").shutdown();quit(0)
