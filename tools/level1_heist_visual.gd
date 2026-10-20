extends SceneTree
# Staged native frames verify the shipped geometry, readable actions and HUD.
# Gameplay and progression are verified by the input-driven playthrough.
const Data=preload("res://scripts/level_data.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
var output := "/tmp/heist-visual"
var game: Node3D
var failed := false
var report: Array=[]
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    call_deferred("_run")
func _run() -> void:
    if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="forward_plus":
        push_error("HEIST VISUAL: actual Forward+ framebuffer required"); quit(1); return
    DirAccess.make_dir_recursive_absolute(output)
    RenderingServer.set_render_loop_enabled(false)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.size=Vector2i(1280,720)
    root.get_node("GameState").sfx_muted=true; root.get_node("GameState").music_muted=true
    game=load("res://game.tscn").instantiate(); root.add_child(game); current_scene=game
    for i in range(24): await process_frame
    game.player.set_physics_process(false); game.set_physics_process(false); game.heist.set_physics_process(false)
    game.encounters.set_physics_process(false)
    for enemy in get_nodes_in_group("level1_enemy"): enemy.set_physics_process(false)
    game.zone_banner.visible=false; game.get_node("HUD/Message").visible=false
    var shots := [
        ["01-entry",Vector2i(5,30),Vector2i(9,28),2.4],
        ["02-lunar-mechanism",Vector2i(16,6),Vector2i(16,3),1.5],
        ["03-gallery",Vector2i(41,7),Vector2i(41,6),1.5],
        ["04-oak-seal",Vector2i(38,26),Vector2i(38,24),1.7],
    ]
    for shot in shots:
        game.player.position=Data.cell_center_world(shot[1])+Vector3.UP*.9; game.player.rotation=Vector3.ZERO
        game.camera.look_at(Data.cell_center_world(shot[2])+Vector3.UP*float(shot[3]))
        game.episode=Data.episode_at(game.player.position)
        game.heist.focus=game.heist.find_focus()
        if shot[0]=="03-gallery":
            for scanner in game.heist.scanners: scanner.visible=true; scanner.rotation.y=PI
        game.heist.ui._refresh()
        await capture(shot[0])
    var relay: Node3D=game.heist.get_node("GalleryRelay")
    game.player.position=relay.position+Vector3(0,.9,1.8); game.camera.look_at(game.heist.interaction_point(relay))
    game.heist.focus=relay; game.heist.request_interact(); game.heist.action_progress=1.0; game.heist.ui._refresh()
    await capture("05-sabotage-progress")
    game.heist.action=null
    for door in get_nodes_in_group("level1_door"): door.open()
    for i in range(40): await physics_frame
    game.heist.begin_escape(); game.exit_ready=true
    game.player.position=Data.cell_center_world(Vector2i(12,20))+Vector3.UP*.9
    game.camera.look_at(Data.cell_center_world(Vector2i(12,18))+Vector3.UP*1.3)
    game.heist.focus=game.heist.find_focus()
    game.heist.ui._refresh(); await capture("06-escape")
    for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1600,720)]:
        root.size=dimensions
        for i in range(4): await process_frame
        var hud: Node=game.get_node("HUD")
        hud.joystick.visible=true; hud.fire_button.visible=true; hud.knob.visible=true
        hud.look_area.visible=true; game.heist.ui._refresh(); game.heist.ui.set_process(false)
        var scale_: float=hud.ui_scale
        var margin := clampf(minf(dimensions.x,dimensions.y)*.026,16.0,32.0)
        hud.carolina.position=Vector2(dimensions.x-margin-235*scale_,margin+186*scale_)
        hud.hp_ammo_label.position=hud.carolina.position+Vector2(50,0)*scale_
        hud.hp_ammo_label.size.x=185*scale_
        game.heist.ui.dash.visible=true; game.heist.ui.quiet.visible=true; game.heist.ui.tips.visible=false
        var fire_rect: Rect2=hud.fire_button.get_global_rect()
        for button: Button in [game.heist.ui.dash,game.heist.ui.quiet]:
            if button.get_global_rect().intersects(fire_rect): failed=true; push_error("HEIST VISUAL: mobile action overlaps fire")
            if not Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(button.get_global_rect()): failed=true; push_error("HEIST VISUAL: mobile action outside viewport")
        await capture("07-mobile-%dx%d"%[dimensions.x,dimensions.y])
    FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    game.queue_free()
    for i in range(4): await process_frame
    await Teardown.drain_audio(self)
    if failed: quit(1)
    else: print("HEIST VISUAL: PASS"); quit(0)
func capture(name_: String) -> void:
    for i in range(5): await process_frame
    RenderingServer.force_draw(true)
    var image := root.get_texture().get_image()
    if image==null or image.is_empty(): failed=true; push_error("HEIST VISUAL: empty "+name_); return
    image.save_png(output+"/"+name_+".png")
    report.append({"view":name_,"draw_calls":RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)})
    print("HEIST VISUAL: ",name_)
