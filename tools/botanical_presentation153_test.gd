extends SceneTree
## Explicit earned-key fixture for the actual modal and static lighting budget.
## The full mission separately earns its objectives through ordinary input.
const Gesture=preload("res://tools/botanical_guide153_input.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
const SIZES=[Vector2i(1280,720),Vector2i(960,540),Vector2i(800,450),Vector2i(720,1280),Vector2i(2582,1220)]
var game: Node
var visual:=false
var output:="user://presentation153"
var failures: Array[String]=[]
var report:={"sizes":[],"captures":[],"lighting":{},"failures":[]}

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg=="--visual":visual=true
        elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL PRESENTATION153: "+why)

func frames(count: int) -> void:
    for i in range(count):await process_frame

func inside(inner: Rect2,outer: Rect2) -> bool:
    return inner.position.x>=outer.position.x-1.5 and inner.position.y>=outer.position.y-1.5 and inner.end.x<=outer.end.x+1.5 and inner.end.y<=outer.end.y+1.5

func inspect(guide: CanvasLayer) -> Dictionary:
    var frame:=Rect2(Vector2.ZERO,Vector2(root.size))
    var panel: Rect2=guide.panel.get_global_rect()
    check(inside(panel,frame),"guide panel overflows actual framebuffer "+str(root.size))
    var labels:=0;var glyphs:=0
    for node in guide.panel.find_children("*","Label",true,false):
        labels+=1
        var bounds: Rect2=node.get_global_rect()
        check(inside(bounds,panel),"label bounds overflow guide: "+node.text)
        check(node.get_line_count()<=node.get_visible_line_count(),"guide hides shaped lines: "+node.text)
        for index in range(node.text.length()):
            if node.text[index] in [" ","\n","\t"]:continue
            var rect: Rect2=node.get_character_bounds(index)
            check(rect.size.x>0 and rect.size.y>0,"guide lost a nonblank glyph")
            check(inside(node.get_global_transform_with_canvas()*rect,panel),"guide glyph overflows panel: "+node.text[index])
            glyphs+=1
    var art=guide.panel.find_child("GuardianSketch",true,false)
    check(art!=null and art.texture!=null,"guide lacks the actual reviewed illustration")
    if art!=null:
        check(inside(art.get_global_rect(),panel) and art.size.y>=75,"illustration is clipped or illegible")
        check(art.get_global_rect().size.x>=panel.size.x*.88,"phone illustration failed to scale with its containing panel")
    check(inside(guide.continue_button.get_global_rect(),panel),"actual continue button overflows panel")
    check(guide.continue_button.get_global_rect().size.x>=panel.size.x*.88,"phone button failed to scale with its containing panel")
    check(guide.continue_button.size.y>=42,"continue touch target became too small")
    return {"framebuffer":[root.size.x,root.size.y],"panel":[panel.position.x,panel.position.y,panel.size.x,panel.size.y],"labels":labels,"nonblank_glyphs":glyphs,"art_size":[art.size.x,art.size.y] if art!=null else [],"button_height":guide.continue_button.size.y}

func key(code: Key,pressed: bool) -> void:
    var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
    root.push_input(event,true)

func hidden_map_tap() -> void:
    var point: Vector2=game.hud.map_button.get_global_rect().get_center()
    var event:=InputEventScreenTouch.new();event.index=24;event.position=point;event.pressed=true
    root.push_input(event,true);await process_frame
    event.pressed=false;root.push_input(event,true);await process_frame

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.size=SIZES[0];root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    if visual:RenderingServer.set_render_loop_enabled(false)
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    for i in range(900):
        await physics_frame
        if game.ready_for_play and game.guard_navigation.is_ready:break
    check(game.ready_for_play,"actual garden startup did not finish")
    for guard in game.guards:guard.set_physics_process(false)
    var lights=game.world.find_children("*","OmniLight3D",true,false)
    check(lights.size()==6,"neon styling added realtime OmniLights")
    for light in lights:check(not light.shadow_enabled and is_equal_approx(light.light_energy,1.15) and is_equal_approx(light.omni_range,11),"existing light budget/energy/range/shadows changed")
    var wayfinding=game.world.get_node_or_null("StaticNeonWayfinding153")
    check(wayfinding!=null,"static objective wayfinding is missing")
    if wayfinding!=null:
        check(wayfinding.get_child_count()==2 and wayfinding.get_meta("realtime_lights")==0 and wayfinding.get_meta("shadow_maps")==0,"wayfinding added lights, shadow maps or more than two batches")
        check(wayfinding.get_meta("task_beacons")==4 and wayfinding.get_meta("lamp_cores")==14,"actual four important objects/fourteen poles lack their authored neon cores")
        for mesh in wayfinding.get_children():check(mesh is MeshInstance3D and mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"static wayfinding casts realtime shadows")
    report.lighting={"realtime_omni_count":lights.size(),"wayfinding_batches":wayfinding.get_child_count() if wayfinding!=null else 0,"extra_realtime_lights":0,"extra_shadow_maps":0,"scope":"Actual node/material/geometry budget; not a device FPS measurement or claim of zero GPU cost."}
    game.player.position=game.GATE_LEVER+Vector3(-1.4,.65,1)
    game.interact();await frames(3)
    check(not is_instance_valid(game.guardian_guide) and not paused,"unearned gate displayed a boss guide or paused gameplay")
    # Isolated setup: earned pump/gallery outcomes. The action below remains
    # the real keyed lever interaction, never a direct call to open the gate.
    game.progress.parts[0]=true;game.progress.installed=true;game.progress.service_key=true
    game.progress.encounters_completed.assign(["entry","pump_repair","pump","gallery"])
    var hud_mode: int=game.hud.process_mode
    var player_input: bool=game.player.input_enabled
    game.interact();await frames(5)
    check(game.progress.gate_unlatched and is_instance_valid(game.guardian_guide) and paused,"actual successful gate interaction omitted its paused illustrated guide")
    check(not game.hud.root.visible,"gameplay HUD overlaps the illustrated guide")
    check(game.hud.process_mode==Node.PROCESS_MODE_DISABLED,"hidden HUD still receives input behind the modal")
    key(KEY_M,true);await frames(2);key(KEY_M,false);await frames(2)
    await hidden_map_tap();await hidden_map_tap()
    check(paused and not game.hud.map_open,"hidden map key/touches resumed physics or opened an underlying modal")
    var before: Vector3=game.player.position
    Input.action_press("l1_move_forward");await frames(35);Input.action_release("l1_move_forward")
    check(game.player.position.distance_to(before)<.001,"actual player moved behind the paused guide")
    for index in range(SIZES.size()):
        root.size=SIZES[index];await frames(5)
        if not is_instance_valid(game.guardian_guide):game._show_guardian_guide();await frames(5)
        report.sizes.append(inspect(game.guardian_guide))
        if visual:
            check(DisplayServer.get_name()!="headless","native illustration mode requires framebuffer")
            for i in range(3):await process_frame;RenderingServer.force_draw(true)
            var name_:="guide-%dx%d.png"%[root.size.x,root.size.y]
            root.get_texture().get_image().save_png(output.path_join(name_));report.captures.append(name_)
        check(await Gesture.acknowledge(self,game),"actual continue-button gesture did not resume gameplay")
        check(game.hud.root.visible,"guide close did not restore normal HUD")
        check(game.hud.process_mode==hud_mode,"guide changed the preexisting HUD process mode")
        check(game.player.input_enabled==player_input,"guide failed to restore the actual player's input-enabled state")
    game._show_guardian_guide();await frames(35)
    key(KEY_ESCAPE,true);await frames(2);key(KEY_ESCAPE,false);await frames(2)
    check(not is_instance_valid(game.guardian_guide) and not paused,"Escape close toggled the underlying pause menu or left physics paused")
    for logical_only: bool in [true,false]:
        game._show_guardian_guide();await frames(35)
        var cancel: InputEvent
        if logical_only:
            var logical:=InputEventKey.new();logical.keycode=KEY_ESCAPE;logical.pressed=true;cancel=logical
        else:
            var action:=InputEventAction.new();action.action="ui_cancel";action.pressed=true;cancel=action
        root.push_input(cancel,true);await frames(3)
        check(not is_instance_valid(game.guardian_guide) and not paused,"Logical Escape/Android cancel action resumed physics underneath a surviving guide")
        if cancel is InputEventKey:cancel.pressed=false
        elif cancel is InputEventAction:cancel.pressed=false
        root.push_input(cancel,true);await frames(2)
        # Cleanup only after the assertion: a failed diagnostic must not leave
        # the next independent event case in an already-unpaused modal.
        if is_instance_valid(game.guardian_guide):game.guardian_guide.dismiss();await frames(3)
    game.interact();await frames(5)
    check(not is_instance_valid(game.guardian_guide) and not paused,"already-open lever repeated the one-shot tutorial")
    game._show_guardian_guide();await frames(3)
    game.guardian_guide.queue_free();await frames(3)
    check(not paused and game.hud.process_mode==hud_mode and game.hud.root.visible and game.player.input_enabled==player_input,"interrupted modal exit did not restore its owned pause/HUD/player-input state")
    report.failures=failures;report.source_hashes={}
    for path in ["scripts/botanical_guardian_guide153.gd","scripts/botanical_task_lights153.gd","scripts/botanical_evening.gd","scripts/botanical_garden.gd","shaders/woodland/task_light153.gdshader","assets/level1/guardian153/combat-guide.png","tools/botanical_presentation153_test.gd"]:report.source_hashes[path]=FileAccess.get_sha256("res://"+path)
    FileAccess.open(output.path_join("presentation153-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    game.queue_free();current_scene=null;await frames(5);await Teardown.drain_audio(self);RenderingServer.set_render_loop_enabled(true)
    print("BOTANICAL PRESENTATION153: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
    quit(0 if failures.is_empty() else 1)
