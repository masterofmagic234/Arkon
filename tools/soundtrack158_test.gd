extends SceneTree
## Focused real-player check: non-overlapping score changes, one-shot completion,
## pause/mute behavior, and the shipped Level 2 music resource.
var failures: Array[String] = []
var checks := 0

class NavigationFixture:
    var ready := true

class DinerFixture extends Node2D:
    var player: Node2D
    var navigation = NavigationFixture.new()
    func has_line_of_sight(_source: Vector2, _target: Vector2) -> bool:
        return true

func _init() -> void:
    call_deferred("run")

func check(condition: bool, message: String) -> void:
    checks+=1
    if not condition:
        failures.append(message)
        push_error("SOUNDTRACK158: "+message)

func wait_until_score(audio: Node, state: StringName) -> void:
    var deadline := Time.get_ticks_msec()+2500
    while Time.get_ticks_msec()<deadline and audio._pending_music!=&"":
        await process_frame
        OS.delay_msec(2)
    check(audio._pending_music==&"" and audio.radio.stream==audio._music_streams[state],"One-shot scratch did not finish into "+String(state))

func make_diner() -> DinerFixture:
    var diner := DinerFixture.new()
    diner.player=Node2D.new()
    diner.add_child(diner.player)
    root.add_child(diner)
    return diner

func run() -> void:
    # Load after autoload construction, matching the real store's audio setup.
    var audio_script := load("res://scripts/level3_audio.gd") as GDScript
    var game: Node=root.get_node("GameState")
    var manager: Node=root.get_node("AudioManager")
    var old_music_muted: bool=game.music_muted
    var old_sfx_muted: bool=game.sfx_muted
    var old_music_volume: float=game.music_volume_db
    game.music_muted=false
    game.sfx_muted=true
    game.music_volume_db=-11.0
    var diner := make_diner()
    var audio = audio_script.new()
    diner.add_child(audio)
    check(audio.music_state==&"daisuke" and audio.radio.playing,"Daisuke must start with the level")
    check(audio.radio.stream==audio._music_streams[&"daisuke"],"Initial stream differs from Daisuke")
    check(manager._music_player==audio.radio,"Diner music must retain central preference ownership")
    check(audio.radio.stream.loop,"Opening music must loop")
    check(is_equal_approx(audio.radio.volume_db,-11.0),"Saved music volume was ignored")
    audio.set_story_phase(&"conversation")
    check(audio.music_state==&"daisuke" and audio._pending_music==&"","Chef dialogue must keep Daisuke")
    audio.set_story_phase(&"arrival")
    check(audio.radio.stream==audio._record_scratch and not audio.radio.stream.loop,"Van cut must immediately replace Daisuke with one scratch")
    audio.set_story_phase(&"deployment")
    check(audio._pending_music==&"rain","Deployment must preserve the pending rain score")
    await wait_until_score(audio,&"rain")
    check(audio.radio.playing and audio.radio.stream.loop,"Raid score must loop after the scratch")
    audio.set_story_phase(&"assault")
    check(audio._pending_music==&"","Combat phase must not restart the scratch")
    audio.set_story_phase(&"cleared")
    check(audio.radio.stream==audio._record_scratch and audio._pending_music==&"radio","Last hostile must cut Rain with one scratch")
    await process_frame
    var before_pause: float=audio.radio.get_playback_position()
    paused=true
    OS.delay_msec(120)
    await process_frame
    check(absf(audio.radio.get_playback_position()-before_pause)<.07,"Music transition advanced while the game was paused")
    paused=false
    await wait_until_score(audio,&"radio")
    check(audio.radio.playing and audio.radio.stream.loop,"Peaceful diner radio must resume after all hostiles")
    check(is_equal_approx(audio.radio.volume_db,-25.0),"Peaceful radio must retain its existing quiet gain")
    var peaceful_stream: AudioStream=audio.radio.stream
    audio.set_story_phase(&"aftermath")
    audio.set_story_phase(&"boarding")
    check(audio.radio.stream==peaceful_stream and audio._pending_music==&"","Aftermath/exit must not repeat music transitions")
    var soundtrack_players := 0
    for child in audio.get_children():
        if child is AudioStreamPlayer: soundtrack_players+=1
    check(soundtrack_players==1,"Multiple simultaneous soundtrack owners exist")
    diner.queue_free()
    await process_frame
    check(manager._music_player==null,"Scene exit retained a stale soundtrack owner")

    game.music_muted=true
    var muted_diner := make_diner()
    var muted_audio = audio_script.new()
    muted_diner.add_child(muted_audio)
    check(not muted_audio.radio.playing,"Muted music started on level load")
    muted_audio.set_story_phase(&"arrival")
    check(muted_audio._pending_music==&"" and muted_audio.radio.stream==muted_audio._music_streams[&"rain"],"Muted transition must select Rain without playing an obsolete scratch")
    check(not muted_audio.radio.playing,"Muted transition produced sound")
    manager.toggle_music()
    check(muted_audio.radio.playing and muted_audio.radio.stream==muted_audio._music_streams[&"rain"],"Unmute did not start the current story score")
    muted_audio.set_story_phase(&"cleared")
    manager.toggle_music()
    muted_audio._apply_volumes()
    check(muted_audio._pending_music==&"" and muted_audio.radio.stream==muted_audio._music_streams[&"radio"] and not muted_audio.radio.playing,"Mute during a scratch did not commit the current story score silently")
    muted_diner.queue_free()
    await process_frame

    var race_scene := load("res://scenes/level2_pseudo3d.tscn") as PackedScene
    check(race_scene!=null,"Level 2 scene cannot load with the new soundtrack")
    if race_scene!=null:
        var state := race_scene.get_state()
        var track_found := false
        for index in state.get_node_count():
            if state.get_node_name(index)!=&"RaceMusic": continue
            var autoplay := false
            for property in state.get_node_property_count(index):
                var key: StringName=state.get_node_property_name(index,property)
                var value: Variant=state.get_node_property_value(index,property)
                if key==&"stream":
                    track_found=value is AudioStreamOggVorbis and value.resource_path=="res://assets/audio158/videoplayback.ogg"
                elif key==&"autoplay": autoplay=bool(value)
            check(not autoplay,"Level 2 music must wait for saved preferences before starting")
        check(track_found,"Level 2 must reference the uploaded Videoplayback Ogg")
    game.music_muted=old_music_muted
    game.sfx_muted=old_sfx_muted
    game.music_volume_db=old_music_volume
    game.save_settings()
    if failures.is_empty(): print("SOUNDTRACK158: PASS (",checks," checks)")
    quit(0 if failures.is_empty() else 1)
