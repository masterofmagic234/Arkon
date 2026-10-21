extends SceneTree
# Production mobile profile with native draws. Host timings are comparisons,
# not phone FPS. Submission/pixel limits catch the 1.27 regression in CI.
const Data=preload("res://scripts/level_data.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
var output := "/tmp/park-render-budget.json"
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    call_deferred("_run")
func draw() -> Image:
    for i in range(2):await process_frame
    RenderingServer.force_draw(true)
    return root.get_texture().get_image()
func _run() -> void:
    if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="forward_plus":
        push_error("PARK MOBILE BUDGET: native Forward+ required");quit(1);return
    RenderingServer.set_render_loop_enabled(false)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1280,720)
    var before:=root.scaling_3d_scale
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    var game: Node3D=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    for i in range(24):await process_frame
    game.player.set_physics_process(false);game.set_physics_process(false);game.heist.set_physics_process(false);game.encounters.set_physics_process(false)
    for enemy in get_nodes_in_group("level1_enemy"):enemy.set_physics_process(false)
    game.get_node("Level1Environment").apply_mobile_rendering()
    var report: Dictionary={"adapter":RenderingServer.get_video_adapter_name(),"resolution":[1280,720],"profile":"mobile","probes":[]}
    var failed:=false
    var probes := [["entry",Vector2i(10,54),Vector2i(24,46),2.6],["wall",Vector2i(8,44),Vector2i(5,44),1.2],["lake",Vector2i(38,43),Vector2i(46,32),1.8],["greenhouse",Vector2i(54,18),Vector2i(68,18),3.6],["oak",Vector2i(66,39),Vector2i(64,48),7.0]]
    for probe in probes:
        game.player.position=Data.cell_center_world(probe[1])+Vector3.UP*.9;game.player.rotation=Vector3.ZERO
        game.camera.look_at(Data.cell_center_world(probe[2])+Vector3.UP*float(probe[3]))
        for i in range(5):await draw()
        var times: Array[float]=[]
        for i in range(3):
            var start:=Time.get_ticks_usec();await draw();times.append((Time.get_ticks_usec()-start)/1000.0)
        times.sort()
        var calls:=RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
        var triangles:=RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
        if calls>260 or triangles>150000:
            failed=true;push_error("PARK MOBILE BUDGET: excessive production submissions at %s: %d calls / %d triangles"%[probe[0],calls,triangles])
        var result: Dictionary={"view":probe[0],"median_draw_readback_ms":times[1],"draw_calls":calls,"triangles":triangles}
        report.probes.append(result);print("PARK MOBILE PROBE: ",result)
        if probe[0] in ["wall","lake"]:
            var image_: Image=await draw();image_.save_png(output.get_base_dir()+"/mobile-"+probe[0]+".png")
    root.size=Vector2i(1920,1080)
    var image: Image=await draw()
    var scale_: float=root.scaling_3d_scale
    if root.size.x*root.size.y*scale_*scale_>1280.0*720.0+4 or image.get_size()!=root.size or game.get_node("WorldEnvironment").environment.glow_enabled:
        failed=true;push_error("PARK MOBILE BUDGET: 3D pixel cap, native UI size or glow profile regressed")
    report["full_hd_3d_scale"]=scale_;report["ui_size"]=image.get_size()
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    game.queue_free();current_scene=null
    for i in range(4):await process_frame
    if not is_equal_approx(root.scaling_3d_scale,before):
        failed=true;push_error("PARK MOBILE BUDGET: viewport scale leaked into the next scene")
    await Teardown.drain_audio(self)
    if failed:quit(1)
    else:print("PARK MOBILE BUDGET: PASS — bounded real submissions, 3D pixels, native UI and scene-local profile");quit(0)
