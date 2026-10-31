extends SceneTree
## Loading illustrations captured from the actual production scenes. Only the
## camera and HUD visibility are staged; this is not a mission playthrough.
const Teardown = preload("res://tools/level3_test_teardown.gd")
var output := "res://assets/loading151"
var report_path := "/tmp/loading-art151-report.json"
var active_scene: Node
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var only := ""

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
        elif arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
        elif arg.begins_with("--only="): only = arg.trim_prefix("--only=")
    call_deferred("run")

func check(value: bool, message: String) -> void:
    if not value: failures.append(message); push_error(message)

func draw_frame() -> void:
    RenderingServer.force_draw(true)

func draw(count := 1) -> void:
    for frame in range(count):
        await process_frame
        call_deferred("draw_frame")
        await RenderingServer.frame_post_draw

func enter(path: String) -> Node:
    var game: Node = load(path).instantiate()
    root.add_child(game); current_scene = game; active_scene = game
    var deadline := Time.get_ticks_msec()+30000
    while not game.ready_for_play and Time.get_ticks_msec()<deadline:
        await physics_frame
        await draw()
    check(game.ready_for_play,"Loading artwork scene did not finish startup: "+path)
    return game

func leave() -> void:
    # The garden's Sky must have actually rendered before it is freed; the
    # empty frames release its GL resources with the manual render loop.
    await draw(2)
    active_scene.queue_free(); active_scene=null; current_scene=null
    for frame in range(5): await process_frame
    await draw(3)

func save(label: String, source: String, crop := Rect2i()) -> void:
    await draw(5)
    var image: Image = root.get_texture().get_image()
    if crop.has_area(): image=image.get_region(crop)
    check(image.get_size()==Vector2i(1280,720),label+" artwork dimensions are wrong")
    var path := output.path_join(label+".png")
    check(image.save_png(path)==OK,"Cannot write loading artwork "+path)
    captures.append({"name":label,"file":path,"source_scene":source,"dimensions":[image.get_width(),image.get_height()],"sha256":FileAccess.get_sha256(path),"staged_camera":true,"production_geometry":true,"hud_hidden":true})

func garden() -> void:
    root.size=Vector2i(1280,720)
    var game=await enter("res://game.tscn")
    game.set_physics_process(false)
    game.player.process_mode=Node.PROCESS_MODE_DISABLED
    for guard in game.guards: guard.process_mode=Node.PROCESS_MODE_DISABLED
    for animation in game.find_children("*","AnimationPlayer",true,false): animation.active=false
    game.hud.hide(); game.weapon.hide()
    for label in game.find_children("*","Label3D",true,false): label.hide()
    game.player.camera.global_position=Vector3(7,8.9,2)
    game.player.camera.look_at(Vector3(0,10,-40))
    await save("garden","res://game.tscn")
    game=null
    await leave()

func pursuit() -> void:
    # At this height the renderer's real 496/720 playfield is 720px high.
    # Cropping that playfield removes its dashboard without distorting art.
    root.size=Vector2i(1280,1046)
    var game=await enter("res://scenes/level2.tscn")
    game.set_physics_process(false); game.set_process(false)
    game.state.race_started=true; game.state.countdown=0
    Input.action_press("race_accel")
    for frame in range(375): game._physics_process(1.0/60.0)
    Input.action_release("race_accel")
    game._process(1.0/60.0)
    game.get_node("HUD").hide(); game.presentation.hide()
    check(game.car_3d_overlay.visible,"Loading pursuit illustration has no real 240")
    await save("pursuit","res://scenes/level2.tscn",Rect2i(0,0,1280,720))
    game=null
    await leave()

func diner() -> void:
    root.size=Vector2i(1280,720)
    var game=await enter("res://scenes/level3_store.tscn")
    game.set_physics_process(false); game.set_process(false)
    game.player.set_physics_process(false)
    game.hud.hide(); game.get_node("Reticle").hide()
    game.camera.position_smoothing_enabled=false
    game.camera.global_position=Vector2(225,680)
    game.camera.zoom=Vector2.ONE*1.8
    game.camera.reset_smoothing()
    check(not game.player.combat_enabled and not game.player._visual.weapon_sprite.visible,"Peaceful loading illustration is armed")
    await save("diner","res://scenes/level3_store.tscn")
    game=null
    await leave()

func run() -> void:
    if DisplayServer.get_name()=="headless":
        push_error("Loading artwork requires the native GL framebuffer"); quit(1); return
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("PauseManager").resume()
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=true
    DirAccess.make_dir_recursive_absolute(output)
    RenderingServer.set_render_loop_enabled(false)
    if only.is_empty() or only=="garden": await garden()
    if only.is_empty() or only=="pursuit": await pursuit()
    if only.is_empty() or only=="diner": await diner()
    await Teardown.drain_audio(self)
    await draw(3)
    RenderingServer.set_render_loop_enabled(true)
    FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"scope":"Actual production scenes; HUD hidden; staged camera compositions, not a playthrough.","failures":failures},"  "))
    if failures.is_empty(): print("LOADING ART151: PASS")
    quit(0 if failures.is_empty() else 1)
