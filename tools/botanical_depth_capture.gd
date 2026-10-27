extends SceneTree
## Compare the production leaf depth path with 1.40 at identical frozen poses.
const POSES=[
    ["entry",Vector3(0,1.6,65),Vector3(-5,0,0)],
    ["concept",Vector3(-22,4.6,22),Vector3(0,6,-47)],
    ["pond",Vector3(25,4.6,31),Vector3(0,8,-20)],
    ["conservatory",Vector3(0,8.6,-19),Vector3(0,14,-38)],
    ["upper",Vector3(-23,13.6,-88),Vector3(26,15,-61)],
    ["p60-entry",Vector3(0,1.6,65),Vector3(-2.7,28.4,0)],
    ["p60-140",Vector3(-16,3,35.3),Vector3(-1.2,51.3,0)],
    ["scout",Vector3(-5,1.6,58),Vector3(-3,.75,56)],
]
var output="user://botanical-depth"
var only_view=""
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
        if arg.begins_with("--view="):only_view=arg.trim_prefix("--view=")
    call_deferred("run")
func draw() -> void:
    await process_frame;call_deferred("force_draw");await RenderingServer.frame_post_draw
func force_draw() -> void:RenderingServer.force_draw(true)
func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    RenderingServer.set_render_loop_enabled(false)
    var game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    assert(game.world.baked_lighting.enabled)
    game.set_physics_process(false);game.player.set_physics_process(false);game.player.set_process_unhandled_input(false)
    for guard in game.guards:guard.set_physics_process(false)
    for animation in game.find_children("*","AnimationPlayer",true,false):animation.active=false
    # Shader TIME keeps advancing under pause. Freeze water for a lighting /
    # ordering comparison rather than counting animated ripples as regressions.
    var water=Shader.new();water.code=game.world.mats.water.shader.code.replace("TIME","0.0");game.world.mats.water.shader=water
    game.hud.hide();game.weapon.hide()
    for label in game.find_children("*","Label3D",true,false):label.hide()
    game.world.set_meta("force_mobile_profile",true)
    var camera=game.player.camera;var results=[]
    for pose in POSES:
        if not only_view.is_empty() and pose[0]!=only_view:continue
        root.size=Vector2i(2582,1220) if pose[0].begins_with("p60-") else Vector2i(1600,1000)
        game.world._mobile_profile();camera.global_position=pose[1]
        if pose[0].begins_with("p60-") or pose[0]=="entry":camera.global_rotation_degrees=pose[2]
        else:camera.look_at(pose[2])
        for enabled in [false,true]:
            game.world.rendering_optimizer.set_foliage_depth_enabled(enabled)
            for i in range(4):await draw()
            var mode="depth" if enabled else "1.40"
            root.get_texture().get_image().save_png(output.path_join(pose[0]+"-"+mode+".png"))
            var row={"view":pose[0],"depth_enabled":enabled,"calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
            results.append(row);print("BOTANICAL DEPTH FRAME: ",row)
            if row.calls>650 or row.triangles>260000:
                push_error("Leaf depth workload exceeded 650 calls / 260k triangles");quit(1);return
    FileAccess.open(output.path_join("depth.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
    game.queue_free();current_scene=null
    for i in range(5):await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    RenderingServer.set_render_loop_enabled(true);print("BOTANICAL DEPTH CAPTURE: PASS");quit()
