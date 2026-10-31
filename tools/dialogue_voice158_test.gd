extends SceneTree
## Actual generated streams + modal dialogue lifecycle, without loading a level.
const Voice = preload("res://scripts/dialogue_voice158.gd")
const Lines = preload("res://scripts/level3_dialogue_lines.gd")
const Dialogue = preload("res://scripts/level3_dialogue.gd")
var errors: Array[String] = []

func _init() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    if not ok:
        errors.append(message)
        push_error("VOICE158: " + message)

func frames(count := 2) -> void:
    for index in count: await process_frame

func guard() -> void:
    await frames(12)

func run() -> void:
    root.size = Vector2i(1280,720)
    var ids: Array[String] = []
    for index in 17: ids.append("intro_%02d" % index)
    for section in [["reception",Lines.RECEPTION],["kitchen",Lines.KITCHEN],["aftermath",Lines.AFTERMATH]]:
        var entries: Array = section[1]
        for index in entries.size():
            var id := Voice.id_for_dialogue(entries[index])
            if entries[index].speaker == "ТАЯ":
                check(id == "l3_%s_%02d" % [section[0],index],"exact Taya text resolves to stable generated ID")
                ids.append(id)
            else: check(id.is_empty(),"chef speech is not assigned Taya's voice")
    check(ids.size() == 24,"all24 actual Taya/Darina dialogue lines are covered")
    for id in ids:
        var path := Voice.ROOT + id + ".ogg"
        check(ResourceLoader.exists(path,"AudioStream"),"generated speech resource exists: " + id)
        if not ResourceLoader.exists(path,"AudioStream"): continue
        var stream := load(path) as AudioStream
        check(stream != null and stream.get_length() > .15,"generated speech is a playable stream: " + id)
        if stream is AudioStreamOggVorbis: check(not stream.loop,"spoken line finishes instead of looping: " + id)

    var settings := root.get_node("GameState")
    var old_muted: bool = settings.sfx_muted
    var old_volume: float = settings.sfx_volume_db
    settings.sfx_muted = false
    settings.sfx_volume_db = -7.0
    var hud := Control.new()
    # A cinematic ALWAYS parent must not make its spoken audio ignore pause.
    hud.process_mode = Node.PROCESS_MODE_ALWAYS
    var dialogue = Dialogue.new()
    var panel := Panel.new()
    panel.name = "Panel"
    dialogue.add_child(panel)
    for name in ["Speaker","Text","Prompt"]:
        var label := Label.new()
        label.name = name
        panel.add_child(label)
    hud.add_child(dialogue)
    root.add_child(hud)
    await frames()
    dialogue.start_dialogue(Lines.RECEPTION)
    var voice = dialogue.voice
    check(voice.playing and voice.current_voice_id == "l3_reception_00","actual first spoken line starts with its page")
    check(is_equal_approx(voice.volume_db,-7.0),"speech reads the SFX volume preference")
    var first_stream: AudioStream = voice.stream
    await guard()
    dialogue.advance()
    check(dialogue._fully_revealed and voice.playing and voice.stream == first_stream,"revealing text does not cut off its spoken line")
    await guard()
    dialogue.advance()
    check(dialogue._index == 1 and voice.current_voice_id == "l3_reception_01" and voice.stream != first_stream,"manual page advance replaces previous speech exactly once")
    settings.sfx_muted = true
    await frames()
    check(voice.volume_db <= -80 and voice.playing,"SFX mute silences speech while preserving its timing")
    paused = true
    await frames()
    check(voice.process_mode == Node.PROCESS_MODE_PAUSABLE and voice.stream_paused,"tree pause pauses actual speech under an ALWAYS parent")
    paused = false
    settings.sfx_muted = false
    await frames()
    check(not voice.stream_paused and is_equal_approx(voice.volume_db,-7.0),"resume restores the same spoken line and audio preference")
    dialogue.cancel_dialogue()
    check(not voice.playing and voice.stream == null,"cancel or skip releases current spoken stream")
    var one: Array[Dictionary] = [Lines.AFTERMATH[3]]
    dialogue.start_dialogue(one)
    await guard()
    dialogue.advance()
    await guard()
    dialogue.advance()
    check(not dialogue.is_active() and not voice.playing and voice.stream == null,"finishing the conversation stops speech before gameplay resumes")
    check(not voice.play_line("nonexistent158") and voice.stream == null,"unvoiced text remains readable without missing-resource errors")
    var reference: WeakRef = weakref(voice)
    hud.queue_free()
    await frames(4)
    check(reference.get_ref() == null,"scene exit frees its speech player")
    settings.sfx_muted = old_muted
    settings.sfx_volume_db = old_volume
    preload("res://scripts/level3_dialogue_portraits.gd").release_scene_cache()
    root.get_node("AudioManager").shutdown()
    var drain_until := Time.get_ticks_msec() + 350
    while Time.get_ticks_msec() < drain_until: await process_frame
    print("VOICE158: PASS" if errors.is_empty() else "VOICE158: FAIL " + str(errors))
    quit(0 if errors.is_empty() else 1)
