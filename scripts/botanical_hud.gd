extends "res://scripts/woodland_hud.gd"
const DamageFeedback = preload("res://scripts/botanical_damage_feedback.gd")
const PixelTheme = preload("res://scripts/pixel_interface_theme.gd")
class GardenMap extends Control:
    const MapLayout=preload("res://scripts/botanical_layout.gd")
    var director: Node
    func loc(p: Vector2) -> Vector2:return Vector2((p.x+75)/150.0,(p.y+100)/202.0)*size
    func _draw() -> void:
        if not is_instance_valid(director):return
        var font=ThemeDB.fallback_font;var s=size.x/554
        draw_rect(Rect2(loc(Vector2(-64,-94)),loc(Vector2(64,99))-loc(Vector2(-64,-94))),Color("354334"))
        draw_line(loc(Vector2(-70,94)),loc(Vector2(70,94)),Color("7b8582"),4*s,true)
        draw_line(loc(Vector2(0,94)),loc(Vector2(0,67.2)),Color("b5aa84"),3*s,true)
        for path in MapLayout.all_paths():
            var route: Array=path.points
            for i in range(route.size()-1):draw_line(loc(route[i]),loc(route[i+1]),Color("b5aa84"),3*s,true)
        for i in range(MapLayout.CHANNEL_POINTS.size()-1):draw_line(loc(MapLayout.CHANNEL_POINTS[i]),loc(MapLayout.CHANNEL_POINTS[i+1]),Color("5b8e8a"),2*s,true)
        paint_ellipse(loc(Vector2(0,23)),Vector2(18.5/150*size.x,9.5/202*size.y),Color("5b8e8a"))
        draw_circle(loc(Vector2(0,-35)),12/150*size.x,Color("91ae9b"))
        var complete=Color("9cb990");var waiting=Color("b5ad96")
        var bridge_color=complete if director.progress.installed else Color("78877a")
        draw_dashed_line(loc(Vector2(0,10)),loc(Vector2(0,45)),bridge_color,3*s,5*s)
        for point in [["ВХОД / МАШИНА",Vector2(MapLayout.ENTRY_CAR_POSITION.x,MapLayout.ENTRY_CAR_POSITION.z),"entry",Vector2(6,-6)],["НАСОС",Vector2(23,19),"pump",Vector2(6,4)],["ЗАПАДНАЯ ГАЛЕРЕЯ",Vector2(-27,-33),"gallery",Vector2(-52,-12)],["ЗАПАС / СТРАЖ",Vector2(0,-35),"guardian",Vector2(9,-6)]]:
            var p=loc(point[1]);var color=complete if director.encounter_done(point[2]) else waiting
            draw_circle(p,4*s,color);draw_string(font,p+point[3]*s,point[0],HORIZONTAL_ALIGNMENT_LEFT,-1,11*s,color)
        for point in [["РОЩА · НЕОБЯЗАТЕЛЬНО",Vector2(-44,-82)],["ПАВИЛЬОН",Vector2(47,-79)]]:
            draw_string(font,loc(point[1])+Vector2(-25,-4)*s,point[0],HORIZONTAL_ALIGNMENT_LEFT,-1,9*s,Color("98a18e"))
        var goal: Vector3=director.goal_position();draw_arc(loc(Vector2(goal.x,goal.z)),9*s,0,TAU,24,Color("f0bf74"),2*s,true)
        var p=loc(Vector2(director.player.position.x,director.player.position.z));draw_circle(p,6*s,Color("e8b461"));draw_line(p,p+Vector2(-sin(director.player.rotation.y),-cos(director.player.rotation.y))*15*s,Color("fff2d6"),2*s,true)
    func paint_ellipse(p: Vector2,r: Vector2,color: Color) -> void:
        var points=PackedVector2Array()
        for i in range(48):points.append(p+Vector2(cos(i*TAU/48),sin(i*TAU/48))*r)
        draw_colored_polygon(points,color)
var garden_map: GardenMap
var diagnostics_button: Button
var frame_times: Array[float]=[]
var sample_seconds:=0.0
var last_tick:=0
var sampled_playing:=false
var performance_text:=""
var communication: Label
var communication_panel: Panel
var communication_speaker: Label
var communication_footer: Label
var communication_rule: ColorRect
var communication_footer_rule: ColorRect
var communication_remaining:=0.0
var damage_feedback: DamageFeedback
var status_panel: Panel
var health_strip: Control
var notice_history: Array[String]=[]
func setup(owner_: Node) -> void:
    super.setup(owner_)
    if damage_feedback!=null:damage_feedback.bind(player,director,supplies,health_strip)
func _notification(what: int) -> void:
    if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_IN]:sampled_playing=false;last_tick=0
func _process(delta: float) -> void:
    var now=Time.get_ticks_usec()
    var loading: bool = get_node("/root/SceneFlow").is_loading_gameplay()
    var playing=is_instance_valid(director) and not loading and not PauseManager.is_paused and not director.mission_failed and not director.mission_complete
    if playing and sampled_playing and last_tick>0:
        var seconds_=(now-last_tick)/1000000.0
        frame_times.append(seconds_);sample_seconds+=seconds_
        while frame_times.size()>1 and sample_seconds-frame_times[0]>=5.0:sample_seconds-=frame_times.pop_front()
    if not playing and sampled_playing and sample_seconds>=1.0:
        performance_text="Последние %.1f с: %.0f FPS"%[sample_seconds,frame_times.size()/sample_seconds]
    sampled_playing=playing;last_tick=now
    if not PauseManager.is_paused and not loading:communication_remaining=maxf(0,communication_remaining-delta)
    if communication_panel!=null:
        communication_panel.visible=communication_remaining>0 and playing
    super._process(delta)
    if toast!=null:toast.visible=message_remaining>0 and playing and communication_remaining<=0 and not map_open
func _build() -> void:
    super._build();map_graph.hide();garden_map=GardenMap.new();garden_map.mouse_filter=Control.MOUSE_FILTER_IGNORE;garden_map.clip_contents=true;map_panel.add_child(garden_map)
    desktop_hint.text="WASD  идти    Мышь  обзор    ЛКМ  шишкомёт    E  действие    Shift  рывок"
    diagnostics_button=_button("ДИАГНОСТИКА FPS",15,modal);diagnostics_button.pressed.connect(_run_diagnostics)
    _build_communication()
    _build_compact_status()
    retry_button.text="С КОНТРОЛЬНОЙ ТОЧКИ"
    quiet_button.hide()
    damage_feedback=DamageFeedback.new();damage_feedback.name="DamageFeedback";root.add_child(damage_feedback);root.move_child(damage_feedback,1)
    if is_instance_valid(player):damage_feedback.bind(player,director,supplies,health_strip)
func _layout() -> void:
    super._layout()
    _layout_compact_status()
    if garden_map!=null:
        var view=get_viewport().get_visible_rect().size
        var map_scale=clampf(minf(view.x/760.0,view.y/700.0),.7,1.55)
        _rect(map_panel,view*.5-Vector2(305,240)*map_scale,Vector2(610,480)*map_scale)
        _rect(garden_map,Vector2(28,106)*map_scale,Vector2(554,226)*map_scale)
        _rect(map_label,Vector2(28,18)*map_scale,Vector2(554,78)*map_scale)
        _rect(map_footer,Vector2(28,346)*map_scale,Vector2(554,116)*map_scale)
        map_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        map_footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        map_label.add_theme_font_size_override("font_size",maxi(12,roundi(15*map_scale)))
        map_footer.add_theme_font_size_override("font_size",maxi(11,roundi(14*map_scale)))
    if communication_panel!=null:
        var viewport_size=get_viewport().get_visible_rect().size
        var s=scale_factor
        var width=minf(viewport_size.x*.55,810*s)
        _rect(communication_panel,Vector2((viewport_size.x-width)*.5,minf(viewport_size.y*.76,viewport_size.y-200*s)),Vector2(width,100*s))
        _rect(communication_speaker,Vector2(14,9)*s,Vector2(width-28*s,20*s))
        _rect(communication_rule,Vector2(14,32)*s,Vector2(width-28*s,s))
        _rect(communication,Vector2(14,41)*s,Vector2(width-28*s,49*s))
        communication_speaker.add_theme_font_size_override("font_size",maxi(11,roundi(13*s)))
        communication.add_theme_font_size_override("font_size",maxi(12,roundi(17*s)))
        # The speaker and subtitle carry the dialogue. Repeating its language
        # and location below every spoken line adds no decision information.
        communication_footer.hide();communication_footer_rule.hide()
    if quiet_button!=null:quiet_button.hide();_rect(quiet_button,Vector2(-10000,-10000),Vector2.ONE)
    if diagnostics_button!=null:
        var s=scale_factor;var size_=get_viewport().get_visible_rect().size
        _rect(modal,size_*.5-Vector2(230,194)*s,Vector2(460,388)*s)
        _rect(diagnostics_button,Vector2(45,286)*s,Vector2(370,48)*s)
func _run_diagnostics() -> void:
    if not is_instance_valid(director) or not PauseManager.is_paused:return
    var probe=preload("res://scripts/botanical_performance_probe.gd").new();get_tree().root.add_child(probe);probe.start(director)
func _refresh() -> void:
    if mission==null or not is_instance_valid(director):return
    var objective: String=director.objective_text()
    mission.text=director.hud_objective_text() if director.has_method("hud_objective_text") else objective.split("\n")[0]
    chapter.hide();mission_hint.hide();lanterns.hide();trail.hide();desktop_hint.hide()
    mission.visible=communication_remaining<=0
    map_label.text=objective+"\n"+director.area_progress();garden_map.director=director
    map_footer.text=director.map_footer_text()
    if not notice_history.is_empty():map_footer.text+="\n"+_brief_notice(notice_history.back())
    if map_open:garden_map.queue_redraw()
    map_panel.visible=map_open and PauseManager.is_paused
    if not PauseManager.is_paused:map_open=false
    var context: String=director.context_text()
    prompt.text=_brief_context(context);prompt.visible=not context.is_empty() and not PauseManager.is_paused and communication_remaining<=0;interact_button.disabled=context.is_empty()
    supplies.text="ЗДОРОВЬЕ  %d       ШИШКИ  %d"%[player.get_hp(),player.get_ammo()]
    quiet_button.hide();mute_button.text="♪×" if GameState.sfx_muted else "♪"
    var tank=director.tank;boss_panel.visible=is_instance_valid(tank) and director.stage=="cache" and not director.mission_failed
    if boss_panel.visible:boss_health.max_value=tank.max_hp;boss_health.value=tank.hp;boss_name.text="СТРАЖ ОРАНЖЕРЕИ"
    if boss_panel.visible:mission.hide()
    var modal_state="failed" if director.mission_failed else ("pause" if PauseManager.is_paused and not map_open else "")
    modal.visible=not modal_state.is_empty()
    diagnostics_button.visible=not director.mission_failed
    if modal_state!=_last_modal:
        _last_modal=modal_state
        if not modal_state.is_empty():release_controls();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
        elif not mobile and not map_open:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
    modal_title.text="ПОПРОБУЕМ ЕЩЁ?" if director.mission_failed else "ПАУЗА"
    modal_body.text=("Повтор: "+director.checkpoint_text()+".\nЗапасы и пройденные бои восстановятся на контрольной точке.") if director.mission_failed else "Сад подождёт. Текущий прогресс сохранён."
    if not director.mission_failed and not performance_text.is_empty():modal_body.text+="\n"+performance_text
    resume_button.visible=not director.mission_failed;crosshair.visible=not modal.visible and not map_open
    var status_visible=not modal.visible and not map_open and not director.mission_complete
    if status_panel!=null:status_panel.visible=status_visible
    supplies.visible=status_visible
    if health_strip!=null:health_strip.visible=status_visible
    mission.visible=status_visible and communication_remaining<=0 and not boss_panel.visible
    boss_panel.visible=boss_panel.visible and status_visible

func _build_compact_status() -> void:
    status_panel=Panel.new();status_panel.name="GardenCompactStatus"
    status_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    status_panel.add_theme_stylebox_override("panel",PixelTheme.frame(Color(.025,.045,.034,.43),Color(.68,.63,.43,.24),1,8))
    root.add_child(status_panel);root.move_child(status_panel,0)
    # One layout anchor; DamageFeedback draws the actual health/trailing-damage
    # strip here. A second ProgressBar would duplicate that presentation.
    health_strip=Control.new();health_strip.name="GardenHealthStrip"
    health_strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
    root.add_child(health_strip)
    mission.autowrap_mode=TextServer.AUTOWRAP_OFF;mission.clip_text=true
    mission.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    prompt.autowrap_mode=TextServer.AUTOWRAP_OFF;prompt.clip_text=true
    prompt.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    _layout_compact_status()

func _layout_compact_status() -> void:
    if status_panel==null:return
    var viewport_size=get_viewport().get_visible_rect().size;var s=scale_factor
    var margin=24*s;var width=minf(450*s,viewport_size.x-280*s)
    var height=maxf(78*s,62)
    _rect(status_panel,Vector2(margin,18*s),Vector2(width,height))
    _rect(mission,Vector2(margin+14*s,26*s),Vector2(width-28*s,maxf(24*s,18)))
    _rect(supplies,Vector2(margin+14*s,maxf(53*s,47)),Vector2(width-28*s,maxf(20*s,16)))
    _rect(health_strip,Vector2(margin+14*s,maxf(76*s,66)),Vector2(112*s,maxf(3*s,3)))
    mission.add_theme_font_size_override("font_size",maxi(12,roundi(17*s)))
    supplies.add_theme_font_size_override("font_size",maxi(11,roundi(14*s)))
    _rect(toast,Vector2(margin+14*s,18*s+height+10*s),Vector2(width-28*s,42*s))
    toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;toast.add_theme_font_size_override("font_size",maxi(11,roundi(14*s)))
    _rect(prompt,Vector2(viewport_size.x*.26,viewport_size.y*.64),Vector2(viewport_size.x*.48,30*s))
    prompt.add_theme_font_size_override("font_size",maxi(12,roundi(16*s)))
    _rect(boss_panel,Vector2(viewport_size.x*.5-150*s,26*s),Vector2(300,48)*s)
    _rect(boss_name,Vector2(10,6)*s,Vector2(280,20)*s)
    _rect(boss_health,Vector2(16,33)*s,Vector2(268,5)*s)
    chapter.hide();mission_hint.hide();lanterns.hide();trail.hide();desktop_hint.hide()

func _brief_context(text: String) -> String:
    if text.begins_with("Дарине нужны"):return "Запас находится в оранжерее"
    return text.split("\n")[0]

func notify(text_: String,duration:=3.0) -> void:
    if toast==null:return
    if notice_history.is_empty() or notice_history.back()!=text_:
        notice_history.append(text_)
        if notice_history.size()>12:notice_history.pop_front()
    # Full explanations stay in the paused map. Playing shows one brief event,
    # instead of objective + route + checklist + duplicate paragraph at once.
    toast.text=_brief_notice(text_)
    message_remaining=minf(duration,3.0)
    toast.visible=communication_remaining<=0 and not PauseManager.is_paused

func _brief_notice(text_: String) -> String:
    var brief=text_.split("\n")[0]
    var sentence=brief.find(". ")
    if sentence>=0:brief=brief.left(sentence+1)
    return "Для Дарины: 6 жёлудей" if brief.begins_with("Дарине нужны") else brief

func _quiet() -> void:
    pass # Stealth is intentionally unavailable in the current garden.

func communicate(text: String,duration:=4.5) -> void:
    if communication==null:return
    var split=text.find(":")
    communication_speaker.text=text.left(split).strip_edges().to_upper() if split>=0 else "БЕЛИЧЬЯ СВЯЗЬ"
    communication.text=text.substr(split+1).strip_edges() if split>=0 else text
    communication_footer.text="САД · ДИАЛОГ" if communication_speaker.text=="ТАЯ" else "БЕЛИЧИЙ ЯЗЫК · СУБТИТРЫ"
    communication_remaining=duration
    communication_panel.visible=not PauseManager.is_paused

func _build_communication() -> void:
    # The same pixel frame, mono type and title/footer rules as the diner
    # dialogue. Speakers remain visible in the world, so no portrait is added.
    var palette=PixelTheme.GARDEN
    communication_panel=Panel.new()
    communication_panel.name="GardenPixelDialogue"
    communication_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    communication_panel.add_theme_stylebox_override("panel",PixelTheme.frame(palette.background,palette.accent,2,8))
    root.add_child(communication_panel)
    communication_speaker=_label("",15,palette.accent,communication_panel)
    communication=_label("",18,palette.text,communication_panel)
    communication.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    communication_footer=_label("БЕЛИЧИЙ ЯЗЫК · СУБТИТРЫ",10,palette.muted,communication_panel)
    communication_footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    for label in [communication_speaker,communication,communication_footer]:PixelTheme.label(label,label.get_theme_color("font_color"))
    communication_rule=ColorRect.new()
    communication_rule.color=palette.accent
    communication_rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
    communication_panel.add_child(communication_rule)
    communication_footer_rule=ColorRect.new()
    communication_footer_rule.color=palette.rule
    communication_footer_rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
    communication_panel.add_child(communication_footer_rule)
    communication_panel.hide()
