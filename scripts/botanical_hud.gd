extends "res://scripts/woodland_hud.gd"
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
        for point in [["ВХОД",Vector2(0,65)],["ПРУД",Vector2(-25,22)],["ШЛЮЗЫ",Vector2(35,19)],["ОРАНЖЕРЕЯ",Vector2(0,-35)],["РОЩА",Vector2(-44,-82)],["ПАВИЛЬОН",Vector2(47,-79)]]:
            var p=loc(point[1]);draw_circle(p,3*s,Color("e8d5a9"));draw_string(font,p+Vector2(6,-6)*s,point[0],HORIZONTAL_ALIGNMENT_LEFT,-1,11*s,Color("eee8d8"))
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
    super._process(delta)
func _build() -> void:
    super._build();map_graph.hide();garden_map=GardenMap.new();garden_map.mouse_filter=Control.MOUSE_FILTER_IGNORE;map_panel.add_child(garden_map)
    diagnostics_button=_button("ДИАГНОСТИКА FPS",15,modal);diagnostics_button.pressed.connect(_run_diagnostics)
    map_footer.text="Все маршруты соединены лестницами и боковыми дорожками.\nЗолотые жёлуди ждут в сердце оранжереи."
func _layout() -> void:
    super._layout()
    if garden_map!=null:_rect(garden_map,Vector2(28,88)*scale_factor,Vector2(554,294)*scale_factor)
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
    map_label.text="БОТАНИЧЕСКИЙ САД\n"+director.area_progress();garden_map.director=director
    if map_open:garden_map.queue_redraw()
    map_panel.visible=map_open and PauseManager.is_paused
    if not PauseManager.is_paused:map_open=false
    prompt.text=director.context_text();prompt.visible=not prompt.text.is_empty() and not PauseManager.is_paused;interact_button.disabled=prompt.text.is_empty()
    supplies.text="%d  ЗДОРОВЬЕ     %d  ШИШКИ"%[player.get_hp(),player.get_ammo()]
    quiet_button.text="ТИХО ✓" if player.quiet_mode else "ТИХО";mute_button.text="♪×" if GameState.sfx_muted else "♪"
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
    modal_body.text="Дневник и найденные образцы сохранены. Новый подход начнётся у входа." if director.mission_failed else "Сад подождёт. Прогресс сохранён."
    if not director.mission_failed and not performance_text.is_empty():modal_body.text+="\n"+performance_text
    resume_button.visible=not director.mission_failed;crosshair.visible=not modal.visible and not map_open
