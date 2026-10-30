extends SceneTree
## Staged production HUD inspection. This is not a normal campaign playthrough.
## Only the HUD presentation data is staged; separate input routes prove missions.
const Teardown = preload("res://tools/level3_test_teardown.gd")
const SIZES := [Vector2i(1280,720),Vector2i(2582,1220),Vector2i(3088,1440),Vector2i(960,540),Vector2i(720,1280)]
const PHASES := ["fresh","pump","gallery","guardian","reward","escape"]
const EXPECTED_GOALS := {"fresh":"Сними входной дозор","pump":"Защити насосную","gallery":"Найди ключ в западной галерее","guardian":"","reward":"Забери шесть жёлудей","escape":"Отбей дозор у выхода"}
const NOTICE := "Ключ дозора получен. Поверни рычаг справа перед воротами оранжереи.\nЗапас пополнен: 38 шишек, здоровье не ниже 80. Контрольная точка."
const SPEECH := "Галерея: «Держать западное крыло! К воротам никого не подпускать!»"
var output := "user://botanical-hud152"
var visual := false
var failures: Array[String] = []
var game
var hud
var report := {"cases":[],"captures":[],"source_hashes":{},"native":false}

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg=="--visual":visual=true
        elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    if ok:return
    failures.append(message)
    push_error("BOTANICAL HUD152: "+message)

func advance() -> void:
    await process_frame

func settle() -> void:
    for i in range(4):await advance()

func pixel_transform(control: Control) -> Transform2D:
    return root.get_stretch_transform()*control.get_global_transform_with_canvas()

func actual_rect(control: Control) -> Rect2:
    return pixel_transform(control)*Rect2(Vector2.ZERO,control.size)

func rect_values(rect: Rect2) -> Array:
    return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func inside(inner: Rect2, outer: Rect2, tolerance := 1.25) -> bool:
    return inner.position.x>=outer.position.x-tolerance and inner.position.y>=outer.position.y-tolerance and inner.end.x<=outer.end.x+tolerance and inner.end.y<=outer.end.y+tolerance

func inspect_label(label: Label, parent: Control, context: String) -> Dictionary:
    var bounds:=actual_rect(label)
    var parent_bounds:=actual_rect(parent)
    check(label.is_visible_in_tree(),context+": actual label is visible")
    check(not label.text.is_empty(),context+": actual label retains its complete text")
    check(inside(bounds,parent_bounds),context+": label rect fits its actual containing panel")
    check(inside(bounds,Rect2(Vector2.ZERO,Vector2(root.size))),context+": label stays in framebuffer")
    check(label.get_line_count()<=label.get_visible_line_count(),context+": every shaped line remains visible")
    var expected_glyphs:=0
    var glyphs: Array=[]
    var combined:=Rect2()
    for index in range(label.text.length()):
        if label.text[index] in [" ","\n","\t"]:continue
        expected_glyphs+=1
        var local: Rect2=label.get_character_bounds(index)
        check(local.size.x>0 and local.size.y>0,context+": nonblank character "+str(index)+" has shaped bounds")
        if local.size.x<=0 or local.size.y<=0:continue
        var glyph: Rect2=pixel_transform(label)*local
        check(inside(local,Rect2(Vector2.ZERO,label.size)),context+": character "+str(index)+" is not clipped or replaced by ellipsis")
        check(inside(glyph,parent_bounds),context+": character "+str(index)+" fits the actual panel")
        combined=glyph if glyphs.is_empty() else combined.merge(glyph)
        glyphs.append({"index":index,"character":label.text[index],"rect":rect_values(glyph)})
    check(glyphs.size()==expected_glyphs and expected_glyphs>0,context+": all exact nonblank characters rendered")
    var pixels: float=label.get_theme_font_size("font_size")*pixel_transform(label).x.length()
    check(pixels>=10.0,context+": text is not shrunk to invisibility")
    var transform:=pixel_transform(label)
    return {"text":label.text,"rect":rect_values(bounds),"container_rect":rect_values(parent_bounds),"glyph_union_rect":rect_values(combined),"glyph_bounds":glyphs,"expected_glyphs":expected_glyphs,"glyphs_checked":glyphs.size(),"visible_lines":label.get_visible_line_count(),"lines":label.get_line_count(),"font_size":label.get_theme_font_size("font_size"),"effective_font_pixels":pixels,"font_family":label.get_theme_font("font").get_font_name(),"canvas_to_pixel":[transform.x.x,transform.x.y,transform.y.x,transform.y.y,transform.origin.x,transform.origin.y],"visible":label.is_visible_in_tree()}

func touch(id: int, point: Vector2, pressed: bool) -> void:
    var event:=InputEventScreenTouch.new()
    event.index=id;event.position=point;event.pressed=pressed
    root.push_input(event,true)

func stage(phase: String) -> void:
    root.get_node("PauseManager").resume()
    hud.map_open=false;hud.communication_remaining=0;hud.message_remaining=0
    hud.notice_history.clear()
    game.stage="garden";game.mission_failed=false;game.mission_complete=false
    var progress=game.progress
    progress.parts.fill(false);progress.installed=false;progress.water=false
    progress.gate_unlatched=false;progress.service_key=false
    progress.guardian_started=false;progress.guardian=false;progress.reward=false
    progress.encounters_completed.clear()
    if phase!="fresh":
        progress.parts[0]=true;progress.installed=true;progress.water=true
        progress.encounters_completed.append("entry")
        progress.encounters_completed.append("pump_repair")
    if phase in ["gallery","guardian","reward","escape"]:progress.encounters_completed.append("pump")
    if phase in ["guardian","reward","escape"]:
        progress.encounters_completed.append("gallery")
        progress.service_key=true;progress.gate_unlatched=true;progress.guardian_started=true
    if phase=="guardian":game.stage="cache"
    if phase in ["reward","escape"]:
        progress.guardian=true;progress.encounters_completed.append("guardian");game.stage="reward"
    if phase=="escape":progress.reward=true
    # The pose and resources are explicit UI staging, never campaign proof.
    game.player.position=Vector3(-5,.7,56)
    game.player.health.current_health=80;game.player.ammo=37
    hud._process(0)
    check(game.hud_objective_text()==EXPECTED_GOALS[phase],phase+": staged phase has the known intended concise goal")

func snapshot(kind: String, dimensions: Vector2i) -> Dictionary:
    var context: String="%dx%d/%s"%[dimensions.x,dimensions.y,kind]
    var frame:=Rect2(Vector2.ZERO,Vector2(root.size))
    check(root.size==dimensions,context+": requested actual framebuffer size is not clamped")
    var item: Dictionary={"case_id":context,"kind":kind,"screen":[root.size.x,root.size.y],"requested_screen":[dimensions.x,dimensions.y],"labels":[],"legacy_hidden":{},"persistent_goal_count":int(hud.mission.is_visible_in_tree())+int(hud.boss_panel.is_visible_in_tree()),"status_visible":hud.status_panel.is_visible_in_tree(),"boss_visible":hud.boss_panel.is_visible_in_tree(),"dialogue_visible":hud.communication_panel.is_visible_in_tree(),"map_visible":hud.map_panel.is_visible_in_tree(),"modal_visible":hud.modal.is_visible_in_tree(),"context_source":game.context_text(),"notice_history":hud.notice_history.duplicate(),"control_rects":{}}
    if kind in PHASES:
        item.expected_goal=EXPECTED_GOALS[kind]
        check(item.persistent_goal_count==1,context+": phase retains exactly one goal or guardian bar")
    for pair in [["chapter",hud.chapter],["mission_hint",hud.mission_hint],["checklist",hud.lanterns],["trail",hud.trail],["desktop_hint",hud.desktop_hint],["dialogue_footer",hud.communication_footer],["dialogue_footer_rule",hud.communication_footer_rule]]:
        item.legacy_hidden[pair[0]]=not pair[1].visible
        check(not pair[1].visible,context+": redundant "+pair[0]+" remains hidden")
    check(item.persistent_goal_count<=1,context+": one persistent goal/boss label at most")
    for pair in [["move",hud.joystick],["fire",hud.fire_button],["action",hud.interact_button],["dash",hud.dash_button],["map",hud.map_button],["pause",hud.pause_button]]:
        var control: Control=pair[1]
        item.control_rects[pair[0]]=rect_values(actual_rect(control))
        check(inside(actual_rect(control),frame),context+": actual "+pair[0]+" control stays in framebuffer")
    var draw_bar: Rect2=hud.damage_feedback.get_health_bar_rect()
    item.damage_bar_rect=rect_values(pixel_transform(hud.damage_feedback)*draw_bar) if draw_bar.has_area() else []
    item.damage_bar_hp=hud.damage_feedback._hp
    if hud.health_strip.is_visible_in_tree():
        var drawn: Rect2=pixel_transform(hud.damage_feedback)*draw_bar
        var anchor:=actual_rect(hud.health_strip)
        check(draw_bar.has_area() and drawn.position.distance_to(anchor.position)<=1.25 and drawn.size.distance_to(anchor.size)<=1.25,context+": the single damage-feedback bar uses the actual compact health anchor")
    else:
        check(not draw_bar.has_area(),context+": hidden compact status does not leave a second damage-feedback health bar")
    if hud.status_panel.is_visible_in_tree():
        item.status_rect=rect_values(actual_rect(hud.status_panel))
        check(inside(actual_rect(hud.status_panel),frame),context+": compact status fits screen")
        item.labels.append(inspect_label(hud.supplies,hud.status_panel,context+"/health-ammo"))
        check(hud.supplies.text.contains(str(game.player.get_hp())) and hud.supplies.text.contains(str(game.player.get_ammo())),context+": actual health/ammo retained")
        check(hud.damage_feedback._hp==game.player.get_hp(),context+": the rendered damage-feedback health binding matches actual health")
        check(inside(actual_rect(hud.health_strip),actual_rect(hud.status_panel)),context+": health strip stays in compact status")
        if hud.mission.is_visible_in_tree():
            check(hud.mission.text==game.hud_objective_text(),context+": exact current compact objective retained")
            item.labels.append(inspect_label(hud.mission,hud.status_panel,context+"/goal"))
    if hud.boss_panel.is_visible_in_tree():
        item.boss_rect=rect_values(actual_rect(hud.boss_panel))
        check(not hud.mission.visible,context+": guardian name is not duplicated by another objective")
        check(not actual_rect(hud.status_panel).intersects(actual_rect(hud.boss_panel)),context+": boss bar does not cover compact status")
        item.labels.append(inspect_label(hud.boss_name,hud.boss_panel,context+"/guardian"))
        check(is_equal_approx(float(hud.boss_health.value),float(game.tank.hp)) and is_equal_approx(float(hud.boss_health.max_value),float(game.tank.max_hp)),context+": real boss health binding retained")
    if hud.toast.is_visible_in_tree():
        check(hud.toast.text.length()<=80 and not hud.toast.text.contains("\n"),context+": one brief notification instead of a paragraph")
        check(not hud.mission.visible or hud.toast.text!=hud.mission.text,context+": notification does not duplicate the same goal")
        item.labels.append(inspect_label(hud.toast,hud.root,context+"/notification"))
    if hud.prompt.is_visible_in_tree():
        check(not game.context_text().is_empty(),context+": contextual hint has a nearby actual interaction")
        check(hud.prompt.text.length()<=80 and not hud.prompt.text.contains("\n"),context+": contextual hint is brief")
        item.labels.append(inspect_label(hud.prompt,hud.root,context+"/context"))
    if hud.communication_panel.is_visible_in_tree():
        item.dialogue_rect=rect_values(actual_rect(hud.communication_panel))
        check(not hud.mission.visible and not hud.toast.visible and not hud.prompt.visible,context+": dialogue hides competing goal/notice/context text")
        check(hud.communication_panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,context+": dialogue does not block gameplay touches")
        check(hud.communication_panel.find_children("*","TextureRect",true,false).is_empty(),context+": visible actors do not gain redundant portraits")
        item.labels.append(inspect_label(hud.communication_speaker,hud.communication_panel,context+"/speaker"))
        item.labels.append(inspect_label(hud.communication,hud.communication_panel,context+"/speech"))
        for control in [hud.joystick,hud.fire_button,hud.interact_button,hud.dash_button]:check(not actual_rect(hud.communication_panel).intersects(actual_rect(control)),context+": dialogue avoids touch controls")
    if hud.map_panel.is_visible_in_tree():
        item.map_rect=rect_values(actual_rect(hud.map_panel));item.map_diagram_rect=rect_values(actual_rect(hud.garden_map))
        check(not hud.status_panel.visible and not hud.mission.visible and not hud.toast.visible and not hud.prompt.visible,context+": map replaces live HUD rather than adding to it")
        check(hud.map_label.text.contains(game.objective_text()) and hud.map_label.text.contains(game.area_progress()),context+": detailed objective/progress retained in paused map")
        check(hud.map_footer.text.contains(game.map_footer_text()),context+": paused map retains route explanation")
        check(hud.map_footer.text.ends_with("Ключ дозора получен.") and hud.notice_history.has(NOTICE),context+": paused map keeps the concise latest event and its full unmodified history entry")
        check(inside(actual_rect(hud.map_panel),frame),context+": complete map panel fits framebuffer")
        item.labels.append(inspect_label(hud.map_label,hud.map_panel,context+"/map-goal"))
        item.labels.append(inspect_label(hud.map_footer,hud.map_panel,context+"/map-route"))
        check(not actual_rect(hud.map_label).intersects(actual_rect(hud.garden_map)),context+": map goal text does not cover diagram")
        check(not actual_rect(hud.map_footer).intersects(actual_rect(hud.garden_map)),context+": map route text does not cover diagram")
    if hud.modal.is_visible_in_tree():
        check(not hud.status_panel.visible and not hud.mission.visible and not hud.communication_panel.visible,context+": modal replaces live status/dialogue")
        item.labels.append(inspect_label(hud.modal_title,hud.modal,context+"/modal-title"))
        item.labels.append(inspect_label(hud.modal_body,hud.modal,context+"/modal-body"))
        check(hud.diagnostics_button.visible,context+": paused FPS diagnostics entry retained")
    return item

func capture(kind: String, dimensions: Vector2i) -> void:
    if not visual or dimensions.x not in [1280,2582,3088] or kind not in ["fresh","gallery","guardian","notification","dialogue","map"]:return
    # Shaped-label/control layout is already inspected after idle passes.
    # Only the actual image matrix needs expensive full-world native draws.
    for i in range(2):
        await process_frame
        RenderingServer.call_deferred("force_draw",true)
        await RenderingServer.frame_post_draw
    var name: String="hud-%dx%d-%s.png"%[dimensions.x,dimensions.y,kind]
    check(root.get_texture().get_image().save_png(output.path_join(name))==OK,"actual native capture "+name)
    report.captures.append(name)

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.size=Vector2i(1280,720)
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    root.get_node("PauseManager").resume()
    if visual:
        report.native=DisplayServer.get_name()!="headless"
        check(report.native,"native HUD captures require actual display")
        RenderingServer.set_render_loop_enabled(false)
    game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    var deadline:=Time.get_ticks_msec()+60000
    while Time.get_ticks_msec()<deadline:
        if game.ready_for_play and is_instance_valid(game.guard_navigation) and game.guard_navigation.is_ready:break
        await physics_frame
    check(game.ready_for_play and game.guard_navigation.is_ready,"actual garden finished navigation/startup before UI staging")
    game.set_physics_process(false);game.player.set_physics_process(false)
    for guard in game.guards:guard.set_physics_process(false)
    hud=game.hud;hud.set_mobile_preview(true)
    for dimensions in SIZES:
        root.size=dimensions;await settle();hud._layout();await settle()
        for phase in PHASES:
            stage(phase);await settle();hud._process(0)
            report.cases.append(snapshot(phase,dimensions));await capture(phase,dimensions)
        stage("gallery");hud.notify(NOTICE,8);hud.notify(NOTICE,8);await settle();hud._process(0)
        check(hud.notice_history.size()==1 and hud.notice_history[0]==NOTICE,"notification history keeps full explanation once")
        check(hud.message_remaining<=3.0 and hud.toast.text=="Ключ дозора получен.","brief event shows first sentence for at most three seconds")
        report.cases.append(snapshot("notification",dimensions));await capture("notification",dimensions)
        hud._process(3.01)
        check(not hud.toast.visible and hud.message_remaining<=0,"brief notification expires rather than becoming persistent HUD text")
        hud.communicate(SPEECH,5);hud._process(0);await settle();hud._process(0)
        check(hud.communication_speaker.text=="ГАЛЕРЕЯ" and hud.communication.text=="«Держать западное крыло! К воротам никого не подпускать!»","exact speaker and dialogue text retained")
        report.cases.append(snapshot("dialogue",dimensions));await capture("dialogue",dimensions)
        stage("gallery");game.progress.service_key=true
        game.player.position=game.GATE_LEVER+Vector3(0,.6,1)
        hud._process(0);await settle();hud._process(0)
        check(hud.prompt.visible and not hud.interact_button.disabled,"nearby actual lever retains action and concise contextual prompt")
        report.cases.append(snapshot("context",dimensions))
        game.player.position=Vector3(-5,.7,56);hud._process(0)
        check(not hud.prompt.visible and hud.interact_button.disabled,"far away does not retain contextual text/action")
        hud.notify(NOTICE,8);hud._process(0)
        touch(91,hud.joystick.get_global_rect().get_center()+Vector2(35,0),true)
        touch(92,hud.fire_button.get_global_rect().get_center(),true)
        check(hud.joystick_touch_id==91 and hud.fire_touch_id==92,"actual independent movement/fire touch ownership established")
        touch(93,hud.map_button.get_global_rect().get_center(),true)
        touch(93,hud.map_button.get_global_rect().get_center(),false)
        await settle();hud._process(0)
        check(root.get_node("PauseManager").is_paused and hud.map_open,"actual map button opens paused map")
        check(hud.joystick_touch_id==-1 and hud.fire_touch_id==-1 and not hud.fire_held and not hud.movement_owned,"map releases actual held controls")
        report.cases.append(snapshot("map",dimensions));await capture("map",dimensions)
        hud._toggle_map();hud._open_pause();await settle();hud._process(0)
        report.cases.append(snapshot("pause",dimensions))
        root.get_node("PauseManager").resume();hud._process(0)
    game.queue_free();current_scene=null
    for i in range(5):await advance()
    await Teardown.drain_audio(self)
    if visual:RenderingServer.set_render_loop_enabled(true)
    for path in ["scripts/botanical_hud.gd","scripts/botanical_garden.gd","scripts/botanical_damage_feedback.gd","tools/botanical_hud152_test.gd"]:report.source_hashes[path]=FileAccess.get_sha256("res://"+path)
    var case_ids: Dictionary={}
    for item in report.cases:
        check(not case_ids.has(item.case_id),"staged viewport/phase case is unique: "+item.case_id)
        case_ids[item.case_id]=true
    check(report.cases.size()==55,"all 55 explicit phase, notification, dialogue, context, map and pause cases completed")
    check(report.source_hashes.size()==4,"all four actual HUD, director, damage overlay and test source pins recorded")
    check(report.captures.size()==(18 if visual else 0),"exact actual native capture matrix completed")
    report.scope={"actual_production_hud":true,"staged_phase_data_and_resources":true,"phases":PHASES,"expected_goals":EXPECTED_GOALS,"expected_case_count":55,"expected_native_capture_count":18,"normal_campaign_proof":false,"glyph_geometry_in_actual_framebuffer_pixels":true,"independent_touch_ownership":true,"real_pause_save_callbacks_retained":true,"fixture_user_data_directory":OS.get_user_data_dir()}
    report.failures=failures;report.result="PASS" if failures.is_empty() else "FAIL"
    FileAccess.open(output.path_join("hud152-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    if failures.is_empty():print("BOTANICAL HUD152: PASS — six staged production phases, one goal and actual health/ammo, complete shaped text, concise notices/context, paused detailed map and released touch controls at five actual viewports")
    quit(0 if failures.is_empty() else 1)
