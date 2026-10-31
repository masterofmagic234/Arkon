extends SceneTree
## Self-contained focused acceptance; also runnable against an exported PCK.
var failures: Array[String]=[]
var cases: Array=[]
var visual:=false
var output:="user://media158-proof"
var settings
var audio
var pauses
var audio_resources: Array[WeakRef]=[]
var captures: Array=[]

func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument=="--visual":visual=true
        elif argument.begins_with("--output="):output=argument.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool,message: String) -> void:
    if not ok:
        failures.append(message)
        push_error("MEDIA158: "+message)

func frames(count:=3) -> void:
    for frame in range(count):await process_frame

func capture(label: String, require_credits_text:=false) -> void:
    if not visual:return
    await frames()
    RenderingServer.force_draw(true)
    await frames()
    var image:=root.get_texture().get_image()
    check(image!=null and not image.is_empty(),"Empty native capture "+label)
    if image!=null:
        var bright_text_pixels:=0
        var colours: Dictionary={}
        for y in range(int(image.get_height()*.15),int(image.get_height()*.95),4):
            for x in range(int(image.get_width()*.12),int(image.get_width()*.88),4):
                var colour:=image.get_pixel(x,y)
                if colour.get_luminance()>.2:bright_text_pixels+=1
                colours[colour.to_rgba32()]=true
        if require_credits_text:
            check(bright_text_pixels>100 and colours.size()>8,"Credits capture is blank or lacks visible text: "+label)
        captures.append({"name":label,"bright_central_text_samples":bright_text_pixels,"central_colour_count":colours.size()})
        check(image.save_png(output.path_join(label+".png"))==OK,"Cannot save "+label)

func release(scene: Node) -> void:
    current_scene=null
    scene.queue_free()
    await frames(5)

func test_intro() -> void:
    var scene=load("res://intro_cutscene.tscn").instantiate()
    root.add_child(scene);current_scene=scene
    scene.set_process(false)
    var music: AudioStreamPlayer=scene.get("_music")
    var voice=scene.get("_voice")
    audio_resources.append(weakref(music.stream))
    check(scene.get_node("VideoPlayer").material==null and scene.get_node("VideoHold").material==null,"Intro alters original pink source video with a garment material")
    check(music!=null and music.stream!=null and music.stream.resource_path=="res://assets/audio158/undertale.ogg","Intro soundtrack is not Undertale")
    check(music.stream is AudioStreamOggVorbis and (music.stream as AudioStreamOggVorbis).loop,"Intro music does not loop while the player reads")
    check(audio.get("_music_player")==music and music.playing and scene.is_ancestor_of(music),"Intro music is not registered and scene-owned")
    check(is_equal_approx(music.volume_db,settings.music_volume_db),"Intro ignores saved music volume")
    scene.call("_play_clip",1)
    scene.call("_show_dialogue",0)
    check(voice.current_voice_id=="intro_00" and voice.playing,"First actual intro page has no spoken line")
    check(music.volume_db<settings.music_volume_db-5.0,"Intro music is not quietened beneath speech")
    scene.call("_advance_dialogue")
    check(voice.current_voice_id=="intro_01" and voice.playing,"Manual dialogue advance does not replace the spoken line")
    pauses.set_paused(true)
    check(music.stream_paused and scene.get_node("VideoPlayer").paused and not voice.can_process(),"Intro music/video/voice does not pause together")
    pauses.resume()
    check(not music.stream_paused and not scene.get_node("VideoPlayer").paused,"Intro does not resume")
    scene.call("_hide_dialogue_for_transition")
    check(not voice.playing and voice.current_voice_id.is_empty(),"Silent video transition retains dialogue speech")
    check(is_equal_approx(music.volume_db,settings.music_volume_db),"Music volume does not recover after speech")
    scene.call("_transition_to_clip",2)
    check(scene.get_node("VideoHold").material==null,"Frozen frame handoff reintroduces recolouring")
    scene.set("clip_transitioning",false)
    scene.call("_play_clip",3)
    scene.call("_show_dialogue",16)
    scene.call("_on_video_finished")
    check(not scene.finished and voice.current_voice_id=="intro_16" and voice.playing,"Automatic intro finish cuts the final spoken line")
    if visual:
        await frames(20)
        await capture("intro-original-pink")
    voice.stop_voice()
    scene.call("_on_video_finished")
    check(scene.finished and not music.playing and not voice.playing,"Completed intro retains music or voice")
    await release(scene)
    check(not is_instance_valid(music) and not is_instance_valid(voice),"Intro audio survives scene exit")
    cases.append({"case":"intro","original_pink_materials":true,"music":"undertale","speech_ducking":true,"final_spoken_line_waited":true,"scene_exit_stops_audio":true})

func test_credits(skipped: bool) -> void:
    var scene=load("res://scenes/ending_cutscene.tscn").instantiate()
    root.add_child(scene);current_scene=scene
    scene.set_process(false)
    var music: AudioStreamPlayer=scene.get("_credits_music")
    audio_resources.append(weakref(music.stream))
    check(music!=null and music.stream!=null and music.stream.resource_path=="res://assets/audio158/wenn.ogg","Credits soundtrack is not Wenn")
    check(not music.playing and audio.get("_music_player")!=music,"Credits music starts during the bedroom ending")
    check(not bool(scene.get("_room").material.get_shader_parameter("recolour_sleeping_pajamas")),"Ending sleeping pose recolours the original pajamas")
    scene.set("elapsed",scene.CREDITS_AT-.01)
    scene.set("_audio_fired",{"gasp":true,"narration":true,"twist":true,"squirrel":true})
    scene.call("_update_frame");scene.call("_trigger_audio")
    check(not music.playing,"Credits music starts before the credits boundary")
    var previous:=AudioStreamPlayer.new()
    previous.stream=load("res://assets/audio158/undertale.ogg")
    audio_resources.append(weakref(previous.stream))
    root.add_child(previous);audio.register_music(previous)
    if skipped:scene.call("skip_to_credits")
    else:
        scene.set("elapsed",scene.CREDITS_AT)
        scene.call("_update_frame");scene.call("_trigger_audio")
    check(music.playing and audio.get("_music_player")==music and not previous.playing,"Credits fail to replace the previous soundtrack")
    check(scene.is_ancestor_of(music),"Credits music is not scene-owned")
    for cue in scene.get("_audio").values():check(not cue.playing,"Ending ambience/voice overlaps credits music")
    pauses.set_paused(true)
    check(music.stream_paused,"Credits music ignores pause")
    pauses.resume()
    check(not music.stream_paused,"Credits music fails to resume")
    settings.music_muted=true;audio.register_music(music)
    check(not music.playing,"Credits ignore music mute")
    settings.music_muted=false;audio.register_music(music)
    check(music.playing and is_equal_approx(music.volume_db,settings.music_volume_db),"Credits ignore unmute or saved music volume")
    if visual:
        # Audio boundary assertions above stay at exactly CREDITS_AT. This
        # frozen fixture must then advance past the production fade-in before
        # accepting an image of the actual visible credits.
        scene.set("elapsed",scene.CREDITS_AT+1.0)
        scene.call("_update_frame")
        check(scene.get("_credits").visible and scene.get("_fade").color.a<.05,"Credits are not visible after their fade-in")
        await capture("credits-skipped" if skipped else "credits-natural",true)
    previous.queue_free()
    await release(scene)
    check(not is_instance_valid(music),"Credits music survives ending scene exit")
    cases.append({"case":"credits_skipped" if skipped else "credits_natural","only_at_credits":true,"track":"wenn","replaces_previous_music":true,"mute_pause_and_exit":true})

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(1280,720)
    settings=root.get_node("GameState");audio=root.get_node("AudioManager");pauses=root.get_node("PauseManager")
    var original:=[settings.music_muted,settings.sfx_muted,settings.music_volume_db,settings.sfx_volume_db]
    settings.music_muted=false;settings.sfx_muted=false;settings.music_volume_db=-18.0;settings.sfx_volume_db=-6.0
    pauses.resume()
    await test_intro()
    await test_credits(false)
    await test_credits(true)
    settings.music_muted=original[0];settings.sfx_muted=original[1];settings.music_volume_db=original[2];settings.sfx_volume_db=original[3]
    audio.shutdown()
    await frames(4)
    # Fixed-fps logic outruns the independent audio callback. Wait only until
    # stopped playback relinquishes the actual streams, with a bounded deadline.
    var deadline:=Time.get_ticks_msec()+500
    var retained:=true
    while retained and Time.get_ticks_msec()<deadline:
        retained=false
        for resource in audio_resources:
            if resource.get_ref()!=null:retained=true
        if retained:
            OS.delay_msec(10)
            await process_frame
    check(not retained,"Stopped cinematic audio resources remain owned after teardown")
    var report:={"result":"PASS" if failures.is_empty() else "FAIL","failures":failures,"cases":cases,"captures":captures,"native":visual,"scope":"Focused real scene/audio ownership and timing; no gameplay overrides or phone performance claim","credits_capture_note":"Audio is verified at the exact credits boundary; images sample CREDITS_AT+1s after the fade-in. Earlier black boundary PNGs show the transition fade and are not credits visual acceptance."}
    FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    if failures.is_empty():print("MEDIA158: PASS")
    quit(0 if failures.is_empty() else 1)
