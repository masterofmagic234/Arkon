extends "res://scripts/woodland_hud.gd"
const DamageFeedback = preload("res://scripts/botanical_damage_feedback.gd")
class GardenMap extends Control:
    var director: Node
    func loc(p: Vector2) -> Vector2:return Vector2((p.x+75)/150.0,(p.y+100)/180.0)*size
    func _draw() -> void:
        if not is_instance_valid(director):return
        var font=ThemeDB.fallback_font;var s=size.x/554
        draw_rect(Rect2(loc(Vector2(-64,-94)),Vector2(.86,.91)*size),Color("354334"))
        for route in [[Vector2(0,65),Vector2(0,38),Vector2(-30,32),Vector2(-45,8),Vector2(-56,-20),Vector2(-53,-60),Vector2(-44,-82),Vector2(0,-86),Vector2(47,-79),Vector2(56,-24),Vector2(46,19),Vector2(0,38)],[Vector2(-25,8),Vector2(0,8),Vector2(0,-35),Vector2(0,-86)]]:
            for i in range(route.size()-1):draw_line(loc(route[i]),loc(route[i+1]),Color("b5aa84"),3*s,true)
        paint_ellipse(loc(Vector2(0,23)),Vector2(18.5/150*size.x,9.5/180*size.y),Color("5b8e8a"))
        draw_circle(loc(Vector2(0,-35)),12/150*size.x,Color("91ae9b"))
        var complete=Color("9cb990");var waiting=Color("b5ad96")
        var route=[Vector2(0,65),Vector2(24,35),Vector2(23,19),Vector2(26,8),Vector2(0,8),Vector2(0,-18),Vector2(-28,-20),Vector2(-35,-26),Vector2(-35,-34),Vector2(-27,-33),Vector2(-35,-26),Vector2(-10,-20),Vector2(0,-20),Vector2(0,-35)]
        for i in range(route.size()-1):
            var earned=director.encounter_done("entry") if i<2 else (director.encounter_done("pump") if i<5 else (director.encounter_done("gallery") if i<12 else director.progress.guardian))
            draw_line(loc(route[i]),loc(route[i+1]),complete if earned else waiting,4*s,true)
        var bridge_color=complete if director.progress.installed else Color("78877a")
        draw_dashed_line(loc(Vector2(0,10)),loc(Vector2(0,45)),bridge_color,3*s,5*s)
        for point in [["ВХОД / МАШИНА",Vector2(0,65),"entry",Vector2(6,-6)],["НАСОС",Vector2(23,19),"pump",Vector2(6,4)],["ЗАПАДНАЯ ГАЛЕРЕЯ",Vector2(-27,-33),"gallery",Vector2(-52,-12)],["ЗАПАС / СТРАЖ",Vector2(0,-35),"guardian",Vector2(9,-6)]]:
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
var communication_remaining:=0.0
var damage_feedback: DamageFeedback
func setup(owner_: Node) -> void:
    super.setup(owner_)
    if damage_feedback!=null:damage_feedback.bind(player,director,supplies)
func _notification(what: int) -> void:
    if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_IN]:sampled_playing=false;last_tick=0
func _process(delta: float) -> void:
    var now=Time.get_ticks_usec()
    var playing=is_instance_valid(director) and not PauseManager.is_paused and not director.mission_failed and not director.mission_complete
    if playing and sampled_playing and last_tick>0:
        var seconds_=(now-last_tick)/1000000.0
        frame_times.append(seconds_);sample_seconds+=seconds_
        while frame_times.size()>1 and sample_seconds-frame_times[0]>=5.0:sample_seconds-=frame_times.pop_front()
    if not playing and sampled_playing and sample_seconds>=1.0:
        performance_text="Последние %.1f с: %.0f FPS"%[sample_seconds,frame_times.size()/sample_seconds]
    sampled_playing=playing;last_tick=now
    if not PauseManager.is_paused:communication_remaining=maxf(0,communication_remaining-delta)
    if communication!=null:communication.visible=communication_remaining>0 and not PauseManager.is_paused
    super._process(delta)
func _build() -> void:
    super._build();map_graph.hide();garden_map=GardenMap.new();garden_map.mouse_filter=Control.MOUSE_FILTER_IGNORE;map_panel.add_child(garden_map)
    desktop_hint.text="WASD  идти    Мышь  обзор    ЛКМ  шишкомёт    E  действие    Shift  рывок"
    diagnostics_button=_button("ДИАГНОСТИКА FPS",15,modal);diagnostics_button.pressed.connect(_run_diagnostics)
    communication=_label("",17,Color("f1dfae"));communication.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;communication.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    communication.hide();retry_button.text="С КОНТРОЛЬНОЙ ТОЧКИ"
    quiet_button.hide()
    damage_feedback=DamageFeedback.new();damage_feedback.name="DamageFeedback";root.add_child(damage_feedback);root.move_child(damage_feedback,0)
    if is_instance_valid(player):damage_feedback.bind(player,director,supplies)
func _layout() -> void:
    super._layout()
    if garden_map!=null:_rect(garden_map,Vector2(28,88)*scale_factor,Vector2(554,294)*scale_factor)
    if communication!=null:
        var viewport_size=get_viewport().get_visible_rect().size
        _rect(communication,Vector2(viewport_size.x*.22,viewport_size.y*.73),Vector2(viewport_size.x*.56,55*scale_factor))
        communication.add_theme_font_size_override("font_size",maxi(12,roundi(17*scale_factor)))
    if lanterns!=null:lanterns.size.x=430*scale_factor
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
    var objective: String=director.objective_text();var first_break=objective.find("\n")
    mission.text=objective.left(first_break) if first_break>=0 else objective;mission_hint.text=objective.substr(first_break+1) if first_break>=0 else ""
    chapter.text="ЗАБЫТЫЙ БОТАНИЧЕСКИЙ САД";lanterns.text=director.area_progress();trail.text=director.trail_hint();trail.visible=true
    map_label.text="САД · МАРШРУТ К ЗАПАСУ\n"+director.area_progress();garden_map.director=director
    map_footer.text=director.map_footer_text()
    if map_open:garden_map.queue_redraw()
    map_panel.visible=map_open and PauseManager.is_paused
    if not PauseManager.is_paused:map_open=false
    prompt.text=director.context_text();prompt.visible=not prompt.text.is_empty() and not PauseManager.is_paused;interact_button.disabled=prompt.text.is_empty()
    supplies.text="%d  ЗДОРОВЬЕ     %d  ШИШКИ"%[player.get_hp(),player.get_ammo()]
    quiet_button.hide();mute_button.text="♪×" if GameState.sfx_muted else "♪"
    var tank=director.tank;boss_panel.visible=is_instance_valid(tank) and director.stage=="cache" and not director.mission_failed
    if boss_panel.visible:boss_health.max_value=tank.max_hp;boss_health.value=tank.hp;boss_name.text="СТРАЖ ОРАНЖЕРЕИ"
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

func _quiet() -> void:
    pass # Stealth is intentionally unavailable in the current garden.

func communicate(text: String,duration:=4.5) -> void:
    if communication==null:return
    communication.text=text;communication_remaining=duration;communication.visible=true
