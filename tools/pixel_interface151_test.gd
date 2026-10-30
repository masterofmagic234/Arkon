extends SceneTree
## Actual HUD reflow and pointer ownership at phone sizes; no mission shortcuts.
const Teardown = preload("res://tools/level3_test_teardown.gd")
var failures: Array[String]=[]
var output := "/tmp/pixel-interface151"
var visual := false
var report := {"garden":[],"race":[],"captures":[],"source_hashes":{}}

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg=="--visual":visual=true
        elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")

func check(condition: bool, message: String) -> void:
    if not condition:failures.append(message);push_error(message)

func settle(count: int) -> void:
    for i in range(count):await physics_frame

func draw_frame() -> void:RenderingServer.force_draw(true)

func capture(label: String) -> void:
    if not visual:return
    for i in range(3):
        await process_frame;call_deferred("draw_frame");await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join(label+".png"))
    report.captures.append(label+".png")

func touch(id: int,position_: Vector2,pressed: bool) -> void:
    var event:=InputEventScreenTouch.new()
    event.index=id;event.position=position_;event.pressed=pressed
    root.push_input(event,true)

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=true
    root.get_node("PauseManager").set_paused(false)
    if visual:
        check(DisplayServer.get_name()!="headless","Native HUD captures need a real display")
        RenderingServer.set_render_loop_enabled(false)
    await garden()
    await race()
    for path in ["scripts/pixel_interface_theme.gd","scripts/botanical_hud.gd","scripts/race_presentation.gd","scripts/race_minimap_static.gd","scripts/race_minimap_nes.gd"]:
        report.source_hashes[path]=FileAccess.get_sha256("res://"+path)
    report.failures=failures
    report.scope={"actual_level_widgets":true,"staged_dialogue_lines":true,"simultaneous_touch_input":true,"visual":visual}
    FileAccess.open(output.path_join("interface151-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    await Teardown.drain_audio(self)
    if visual:
        for i in range(3):await process_frame;call_deferred("draw_frame");await RenderingServer.frame_post_draw
        RenderingServer.set_render_loop_enabled(true)
    if failures.is_empty():print("PIXEL INTERFACE151: PASS — dialogue reflow, readable phone panels and independent driving fingers")
    quit(0 if failures.is_empty() else 1)

func garden() -> void:
    root.get_node("GameState").start_new_run()
    var game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    for i in range(120):
        if game.ready_for_play:break
        await physics_frame
    check(game.ready_for_play,"Garden did not finish startup")
    game.set_physics_process(false);game.player.set_physics_process(false)
    for guard in game.guards:guard.set_physics_process(false)
    var hud=game.hud
    hud.set_mobile_preview(true)
    for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(2582,1220),Vector2i(1080,2400)]:
        root.size=dimensions;await settle(2);hud._layout()
        hud.communicate("Дозор: «К запасу не подпускать! Держать западное крыло!»",5)
        hud._process(0)
        var panel: Rect2=hud.communication_panel.get_global_rect()
        check(root.get_visible_rect().encloses(panel),"Garden dialogue leaves the screen at"+str(dimensions))
        for control in [hud.joystick,hud.fire_button,hud.interact_button,hud.dash_button]:
            check(not panel.intersects(control.get_global_rect()),"Garden dialogue covers a touch control at"+str(dimensions))
        check(hud.communication_speaker.text=="ДОЗОР" and hud.communication.text.contains("Держать западное крыло"),"Garden loses the speaker or spoken text")
        check(hud.communication_panel.find_children("*","TextureRect",true,false).is_empty(),"Garden unexpectedly added a portrait")
        check(hud.communication_panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Garden dialogue consumes world touches")
        check(not hud.communication_footer.visible and not hud.communication_footer_rule.visible,"Garden dialogue repeats a redundant language/location footer")
        report.garden.append({"viewport":str(dimensions),"panel":str(panel),"speaker":hud.communication_speaker.text,"portraits":0,"touch_controls_clear":true})
        await capture("garden-dialogue-%dx%d"%[dimensions.x,dimensions.y])
    var before: float=hud.communication_remaining
    root.get_node("PauseManager").set_paused(true);hud._process(.5)
    check(not hud.communication_panel.visible and is_equal_approx(before,hud.communication_remaining),"Pause consumes or displays the garden dialogue")
    root.get_node("PauseManager").set_paused(false);hud._process(0)
    check(hud.communication_panel.visible,"Garden dialogue does not resume")
    # A native garden frame has been drawn before its sky is deleted.
    game.queue_free();current_scene=null;await settle(5)

func race() -> void:
    root.size=Vector2i(1280,720)
    var game=load("res://scenes/level2.tscn").instantiate();root.add_child(game);current_scene=game
    await settle(4);game.set_physics_process(false);game.state.race_started=true
    var radio=game.controller.pursuit.radio
    radio.say("ui151","ОРЕХ-1 · ПИЛОТ","Вижу беглеца. Захожу сзади!",8,2);radio.advance(.1)
    for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720),Vector2i(2582,1220)]:
        root.size=dimensions;await settle(2);game.presentation.layout()
        game.presentation._timer=0;game.presentation._process(.01)
        var screen: Rect2=root.get_visible_rect()
        for control in [game.joystick,game.gas_button,game.brake_button,game.presentation.pause_button,game.presentation.radio_panel]:
            check(screen.encloses(control.get_global_rect()),"Race UI leaves screen at"+str(dimensions))
        check(not game.minimap.visible and not game.minimap.is_processing() and not game.presentation.map_card.visible,"Removed race minimap remains visible or processing")
        for id in ["LapLabel","Lap","PosLabel","Pos","TimeLabel","Time"]:
            check(not game.hud_background.get_node(id).visible,"Removed race telemetry remains visible: "+id)
        for id in ["Speed","Gear","Best"]:
            check(game.hud_background.get_node(id).visible,"Retained speed/gear/distance binding hidden: "+id)
            check(screen.encloses(game.hud_background.get_node(id).get_global_rect()),"Retained race value leaves screen: "+id)
        check(not game.presentation.rpm_bar.visible and not game.presentation.rpm_label.visible and not game.message_label.visible and game.message_label.text.is_empty(),"Removed RPM or tactical text strip remains visible")
        var panel: Rect2=game.presentation.radio_panel.get_global_rect()
        for control in [game.joystick,game.gas_button,game.brake_button]:
            check(not panel.intersects(control.get_global_rect()),"Race radio covers a driving control or warning")
        check(game.presentation.radio_text.text==radio.current.text,"Race radio text was replaced by decoration")
        report.race.append({"viewport":str(dimensions),"radio":str(panel),"controls_clear":true,"bindings_retained":true})
        await capture("race-pixel-%dx%d"%[dimensions.x,dimensions.y])
    var stick: Vector2=game.joystick.get_global_rect().get_center()
    touch(31,stick+Vector2(50,0),true)
    touch(32,game.gas_button.get_global_rect().get_center(),true)
    touch(33,game.brake_button.get_global_rect().get_center(),true)
    check(game.race_input.steer>.15 and game.race_input.throttle==1 and game.race_input.brake==1,"Pixel frames stole simultaneous steering and pedals")
    touch(33,Vector2.ZERO,false)
    check(game.race_input.throttle==1 and game.race_input.steer>.15,"Releasing brake released another driving finger")
    root.get_node("PauseManager").set_paused(true)
    check(game.race_input.pointers.is_empty() and game.presentation.overlay.visible,"Pause leaves driving fingers held")
    await capture("race-pixel-pause")
    root.get_node("PauseManager").set_paused(false)
    check(game.race_input.throttle==0 and game.race_input.brake==0,"Resume leaves phantom pedals")
    game.queue_free();current_scene=null;await settle(5)
