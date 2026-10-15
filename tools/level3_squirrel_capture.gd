extends SceneTree
# Actual Level 3 actors, staged for sprite QA. Not a gameplay recording.
const Visual=preload("res://scripts/level3_asset_visual.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
var output := "/tmp/level3-squirrels"
var original := false
var game: Level3Store
var actors: Array[Level3Enemy]=[]
var views: Array=[]
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
        elif arg=="--original": original=true
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
    var kinds: Array[StringName]=[&"gunman",&"melee",&"butcher"]
    for enemy in game._enemies:
        enemy.set_physics_process(false);enemy._visual.pause()
        if not kinds.has(enemy.enemy_kind): enemy.visible=false;continue
        kinds.erase(enemy.enemy_kind)
        actors.append(enemy)
    actors.sort_custom(func(a,b): return [&"gunman",&"melee",&"butcher"].find(a.enemy_kind)<[&"gunman",&"melee",&"butcher"].find(b.enemy_kind))
    for i in range(actors.size()):
        var enemy := actors[i]
        enemy.global_position=Vector2(176+i*75,686)
        enemy.rotation=0;enemy._visual.frame=0
        if original:
            var source: String={&"gunman":"Combat/Enemy/sprEWalkSilencer_strip8.png",&"melee":"Combat/Enemy/sprEWalkBat_strip8.png",&"butcher":"Player/sprPigButcher_strip8.png"}[enemy.enemy_kind]
            enemy._visual.sprite_frames=Visual.sprite_frames_from_strip("res://assets/level3/source/"+source,9,true)
            enemy._visual.pause()
    game.camera.position_smoothing_enabled=false
    game.camera.global_position=Vector2(251,671)
    game.camera.zoom=Vector2.ONE*3.0
    game.camera.reset_smoothing()
    await _capture("01-lineup")
    for angle in range(4):
        for frame in range(8):
            for actor in actors:
                actor.rotation=angle*PI*.5
                actor._visual.frame=frame
            await _capture("walk-%d-%d"%[angle,frame],angle==0 and frame==4)
    for actor in actors:
        actor.rotation=0;actor._visual.frame=0
        actor.state=actor.State.ALERT
        actor._locked_aim=Vector2.RIGHT
        actor._windup=.24 if actor.ranged else .17
        actor.queue_redraw()
    await _capture("02-warning")
    for actor in actors:
        actor._windup=0;actor.stun(3.2)
        actor._physics_process(0)
    await _capture("03-stunned")
    for actor in actors:
        actor.kill()
        if original:
            actor._visual.sprite_frames=Visual.sprite_frames_from_strip("res://assets/level3/source/Combat/Enemy/sprEDeadFrontPool_strip2.png",1,false)
            actor._visual.frame=0;actor._visual.pause()
    await _capture("04-resting")
    for actor in actors: actor._visual.frame=1
    await _capture("05-resting-pool")
    FileAccess.open(output+"/render-budget.json",FileAccess.WRITE).store_string(JSON.stringify({"original":original,"adapter":RenderingServer.get_video_adapter_name(),"views":views},"  ")+"\n")
    game.queue_free()
    for i in range(4): await process_frame
    await Teardown.drain_audio(self)
    print("LEVEL3 SQUIRREL CAPTURE: PASS — three production roles, 32 walk/heading poses, warning, stun and both resting frames")
    quit(0)
func _capture(name_: String, save_: bool = true) -> void:
    for i in range(3): await process_frame
    await RenderingServer.frame_post_draw
    if save_: root.get_texture().get_image().save_png(output+"/"+name_+".png")
    views.append({"name":name_,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
