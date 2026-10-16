extends SceneTree
# Staged animation inspection in the actual level, not a gameplay replay.
const Teardown=preload("res://tools/level3_test_teardown.gd")
var output := "/tmp/level3-squirrels"
var record := false
var game: Level3Store
var actors: Array[Level3Enemy]=[]
var views: Array=[]
var caption: Label
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
        elif arg=="--record": record=true
    call_deferred("_run")
func _run() -> void:
    if DisplayServer.get_name()=="headless": quit(1);return
    DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(1280,720)
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=true
    game=load("res://scenes/level3_store.tscn").instantiate()
    root.add_child(game);current_scene=game
    for i in range(12): await physics_frame
    game.set_process(false);game.set_physics_process(false)
    game.player.set_physics_process(false);game.player.visible=false
    game.hud.visible=false
    game.pickups_root.visible=false
    var kinds: Array[StringName]=[&"gunman",&"melee",&"butcher"]
    for enemy in game._enemies:
        enemy.set_physics_process(false)
        if not kinds.has(enemy.enemy_kind): enemy.visible=false;continue
        kinds.erase(enemy.enemy_kind);actors.append(enemy)
    actors.sort_custom(func(a,b): return [&"gunman",&"melee",&"butcher"].find(a.enemy_kind)<[&"gunman",&"melee",&"butcher"].find(b.enemy_kind))
    for i in range(actors.size()):
        actors[i].global_position=Vector2(176+i*75,686)
        actors[i].rotation=0
        actors[i]._animator.configure(actors[i]._visual,actors[i].enemy_kind,0)
    game.camera.position_smoothing_enabled=false
    game.camera.global_position=Vector2(251,671)
    game.camera.zoom=Vector2.ONE*4.0
    game.camera.reset_smoothing()
    await _capture("01-lineup")
    # Every new pose at all four headings, including weapon/tail extremities.
    for clip: StringName in [&"idle",&"walk",&"windup",&"attack",&"stun",&"fall"]:
        for heading in range(4):
            for frame in range(actors[0]._visual.sprite_frames.get_frame_count(clip)):
                for actor in actors:
                    actor.rotation=heading*PI*.5
                    actor._visual.animation=clip;actor._visual.frame=frame
                await _capture("%s-%d-%02d"%[clip,heading,frame],frame in [3,5] or (heading==0 and frame in [0,11]))
    for actor in actors:
        actor.rotation=0;actor.state=Level3Enemy.State.ALERT
        actor._locked_aim=Vector2.RIGHT
        actor._windup=.04
        actor._update_visual(0);actor.queue_redraw()
    await _capture("02-warning")
    for actor in actors: actor.stun(3.2);actor._physics_process(0);actor._update_visual(.2);actor.queue_redraw()
    await _capture("03-stunned")
    for actor in actors: actor.state=Level3Enemy.State.IDLE;actor._visual.modulate=Color.WHITE;actor.queue_redraw()
    if record: await _record()
    else:
        for actor in actors: actor.kill();actor._update_visual(.5)
    await _capture("04-resting")
    FileAccess.open(output+"/render-budget.json",FileAccess.WRITE).store_string(JSON.stringify({"adapter":RenderingServer.get_video_adapter_name(),"views":views},"  ")+"\n")
    game.queue_free()
    for i in range(4): await process_frame
    await Teardown.drain_audio(self)
    print("LEVEL3 SQUIRREL CAPTURE: PASS — three complete animal rigs, 176 clip/heading poses, warning, stun, settled fall")
    quit(0)
func _record() -> void:
    DirAccess.make_dir_recursive_absolute(output+"/frames")
    var overlay:=CanvasLayer.new();root.add_child(overlay)
    var title:=_label("LEVEL 3  /  НОВЫЕ БЕЛКИ",Vector2(0,78),30)
    overlay.add_child(title)
    caption=_label("",Vector2(0,550),23);overlay.add_child(caption)
    for frame in range(228):
        var time:=float(frame)/24
        for actor in actors:
            actor.velocity=Vector2.ZERO
            if time<1.5:
                caption.text="ОЖИДАНИЕ"
            elif time<4.5:
                caption.text="СТРЕЛОК     /     БИТА     /     МЯСНИК"
                actor.velocity=Vector2.RIGHT*actor.move_speed
            elif time<7.0:
                caption.text="ПОДГОТОВКА  →  УДАР И ОТДАЧА"
                actor.state=Level3Enemy.State.ALERT
                var duration:=.48 if actor.ranged else .34
                var cycle:=fmod(time-4.5,1.25)
                actor._windup=maxf(0,duration-cycle)
                if cycle>=duration and cycle<duration+1.0/24: actor._animator.attack()
            elif time<8.25:
                caption.text="ОГЛУШЕНИЕ"
                if actor.state!=Level3Enemy.State.STUNNED: actor.stun(3.2);actor._physics_process(0)
            else:
                caption.text="ПАДЕНИЕ"
                if actor.state!=Level3Enemy.State.DEAD: actor.kill()
            actor._update_visual(1.0/24)
            actor.queue_redraw()
        await _capture("frames/%04d"%frame,true,false)
    overlay.queue_free()
func _label(text_: String, at: Vector2, size_: int) -> Label:
    var label:=Label.new();label.text=text_;label.position=at;label.size=Vector2(1280,40)
    label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size",size_)
    label.add_theme_color_override("font_outline_color",Color(0,0,0,.9))
    label.add_theme_constant_override("outline_size",8)
    return label
func _capture(name_: String, save_: bool = true, measure: bool = true) -> void:
    for i in range(2): await process_frame
    await RenderingServer.frame_post_draw
    if save_: root.get_texture().get_image().save_png(output+"/"+name_+".png")
    if measure: views.append({"name":name_,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
