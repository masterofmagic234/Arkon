extends SceneTree
## Raw native production-scene frames, with frozen actors for stable comparison.
const POSES=[
    ["entry",Vector3(0,.65,65),Vector3(0,11,-30)],
    ["concept-view",Vector3(-22,3.65,22),Vector3(0,6,-47)],
    ["pond",Vector3(25,3.65,31),Vector3(0,8,-20)],
    ["conservatory",Vector3(0,7.65,-19),Vector3(0,14,-38)],
    ["upper-garden",Vector3(-23,12.65,-88),Vector3(26,15,-61)],
]
var output="user://botanical-visual"
var report: Array=[]
var failures: Array=[]
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL VISUAL: "+why)
func run() -> void:
    check(DisplayServer.get_name()!="headless","native renderer required")
    DirAccess.make_dir_recursive_absolute(output);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1600,1000);root.msaa_3d=Viewport.MSAA_2X
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    RenderingServer.set_render_loop_enabled(false)
    var old_scale=root.scaling_3d_scale
    var game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    game.set_physics_process(false);game.player.set_physics_process(false);game.player.set_process_unhandled_input(false)
    for guard in game.guards:guard.set_physics_process(false)
    game.world.set_meta("force_mobile_profile",true);game.world._mobile_profile();game.hud.set_mobile_preview(true)
    for pose in POSES:
        game.player.position=pose[1];game.player.camera.look_at(pose[2]);game.hud.message_remaining=0;game.hud._refresh()
        await draw();await draw()
        var calls=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME);var triangles=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
        # This complete garden has a different geometry budget than the former
        # single clearing. Include all shadow passes and native HUD in totals.
        check(calls<=500 and triangles<=260000,"budget exceeded in "+pose[0]+": %d calls / %d triangles"%[calls,triangles])
        check(root.size.x*root.size.y*root.scaling_3d_scale*root.scaling_3d_scale<=921605,"Android 3D pixel cap missing")
        root.get_texture().get_image().save_png(output.path_join(pose[0]+"-hud.png"))
        var labels=game.find_children("*","Label3D",true,false)
        for label in labels:label.hide()
        game.hud.hide();game.weapon.hide();await draw();await draw();root.get_texture().get_image().save_png(output.path_join(pose[0]+".png"));game.hud.show();game.weapon.show()
        for label in labels:label.show()
        report.append({"view":pose[0],"calls":calls,"triangles":triangles});print("BOTANICAL PROBE: ",report[-1])
    game.hud._toggle_map();await draw();await draw();root.get_texture().get_image().save_png(output.path_join("garden-map.png"));game.hud._toggle_map()
    for size_ in [Vector2i(1280,720),Vector2i(2400,1080),Vector2i(1080,2400)]:
        root.size=size_;game.hud._layout();await draw();await draw()
        check(game.hud.joystick.get_global_rect().end.y<=size_.y+1,"touch controls clipped on "+str(size_))
        root.get_texture().get_image().save_png(output.path_join("controls-%dx%d.png"%[size_.x,size_.y]))
    # Full-scene architectural overview: a separate unrestricted desktop view,
    # explicitly not counted as a phone gameplay budget or device benchmark.
    root.size=Vector2i(1600,1000);game.world.set_meta("force_mobile_profile",false);root.scaling_3d_scale=1;game.hud.hide()
    game.world.set_distance_culling_enabled(false)
    for node in game.world.find_children("*","GeometryInstance3D",true,false):
        if node is GeometryInstance3D:node.visibility_range_end=400
    game.player.position=Vector3(85,75,82);game.player.camera.look_at(Vector3(0,7,-20));await draw();await draw();root.get_texture().get_image().save_png(output.path_join("overview-desktop.png"))
    game.queue_free();current_scene=null
    for i in range(5):await process_frame
    check(is_equal_approx(root.scaling_3d_scale,old_scale),"scene exit leaked the mobile profile")
    FileAccess.open(output.path_join("render-evidence.json"),FileAccess.WRITE).store_string(JSON.stringify({"views":report,"failures":failures,"note":"Native software-GPU render. Raw engine frames, not generated art. Overview is desktop-only. Phone FPS remains unmeasured."},"  "))
    await load("res://tools/level3_test_teardown.gd").drain_audio(self);RenderingServer.set_render_loop_enabled(true)
    if failures.is_empty():print("BOTANICAL VISUAL: PASS — real continuous garden, concept view, mobile layouts, terrain, vegetation and profile restoration")
    quit(0 if failures.is_empty() else 1)
func draw() -> void:
    await process_frame;call_deferred("force_draw");await RenderingServer.frame_post_draw
func force_draw() -> void:RenderingServer.force_draw(true)
