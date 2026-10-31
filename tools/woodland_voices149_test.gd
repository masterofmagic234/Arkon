extends SceneTree
## Actual imported voice selection, priorities and burst suppression.
const Bank = preload("res://scripts/woodland_audio_bank.gd")
var failures: Array[String] = []
var output := ""

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool, why: String) -> void:
    if not ok:
        failures.append(why)
        push_error("WOODLAND VOICES149: " + why)

func clean(mix) -> void:
    for voice in mix.pool: voice.stop()
    for voice in mix.local_pool: voice.stop()
    mix._clock += 10.0
    mix._cooldowns.clear()
    mix._vocal_starts.clear()
    mix._pending_phase_event.clear()
    mix.event_log.clear()

func vocal_count(mix) -> int:
    var count := 0
    for voice in mix.pool:
        if voice.playing and voice.get_meta("vocal", false): count += 1
    return count

func run() -> void:
    var Audio = load("res://scripts/woodland_audio.gd")
    var state = root.get_node("GameState")
    var pause = root.get_node("PauseManager")
    var original_mute: bool = state.sfx_muted
    state.sfx_muted = false
    pause.set_paused(false)
    var scene := Node3D.new()
    root.add_child(scene)
    current_scene = scene
    var listener := AudioListener3D.new()
    scene.add_child(listener)
    listener.make_current()
    var mix = Audio.new()
    scene.add_child(mix)
    await process_frame
    mix.set_variation_seed(149)
    var sequences := {}
    for actor in ["squirrel", "guardian"]:
        for action in ["warn", "attack", "hit", "defeat", "rally"]:
            var kind := StringName(actor + "_" + action)
            var takes: Array = Bank.SETS[kind]
            check(takes.size() >= 3, String(kind) + " lacks independent variations")
            check(Bank.settings(kind).vocal and not Bank.settings(kind).local, "animal call is not spatial vocal")
            check(Bank.settings(kind).voice_class == actor, "guardian/ordinary vocal metadata is wrong")
            var sequence: Array[String] = []
            for index in range(takes.size() * 3):
                clean(mix)
                mix._on_audio_event(kind, Vector3(-3, 1, -4))
                check(not mix.event_log.is_empty(), String(kind) + " did not reach the audio pool")
                if mix.event_log.is_empty(): continue
                var event: Dictionary = mix.event_log[-1]
                sequence.append(event.take)
                check(event.vocal and event.voice_class == actor and not event.local, "actual vocal lost class/spatial metadata")
                check(event.take.begins_with("voice_" + actor + "_" + action), "old mechanical cue is still used for an animal")
                var stream = mix.streams.get(event.take)
                check(stream is AudioStreamWAV and stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == 44100 and not stream.stereo, "voice imported with incorrect PCM layout")
            for index in range(1, sequence.size()):
                check(sequence[index] != sequence[index - 1], "vocal repeated at shuffle-bag boundary")
            var first_bag := {}
            for index in range(mini(takes.size(), sequence.size())): first_bag[sequence[index]] = true
            check(first_bag.size() == takes.size(), "shuffle bag omitted an actual vocal take")
            sequences[String(kind)] = sequence
    var previous := ""
    for index in range(18):
        var id: String = mix._next_take(&"squirrel_chatter" if index % 2 else &"squirrel_rally")
        check(id != previous, "switching chatter/rally repeats the same actual recording")
        previous = id
    clean(mix)
    for index in range(40):
        mix._on_audio_event(&"squirrel_attack", Vector3(index * 10, 1, -5))
    check(mix.event_log.size() == Audio.VOCAL_WINDOW_LIMIT - Audio.VOCAL_RESERVED_PHASE_STARTS, "large group vocal burst consumed the reserved phase start")
    check(vocal_count(mix) <= Audio.VOCAL_VOICE_LIMIT, "vocal emitters exceeded concurrent cap")
    check(mix.dropped_vocal_budget >= 36, "vocal burst was not explicitly suppressed")
    mix._on_audio_event(&"encounter_entry", Vector3.ZERO)
    check(mix.event_log.size() == Audio.VOCAL_WINDOW_LIMIT and mix.event_log[-1].requested == "encounter_entry", "startup chorus suppressed its phase leader")
    check(vocal_count(mix) <= Audio.VOCAL_VOICE_LIMIT, "critical phase call exceeded concurrent vocal cap")
    var burst_events: int = mix.event_log.size()
    mix._clock += Audio.VOCAL_WINDOW_SECONDS + .01
    mix._on_audio_event(&"guardian_attack", Vector3(50, 1, -5))
    check(mix.event_log.size() == burst_events + 1, "vocal start budget failed to recover")
    clean(mix)
    mix._on_audio_event(&"squirrel_warn", Vector3(1, 1, 1))
    mix._clock += .2
    mix._on_audio_event(&"squirrel_warn", Vector3(2, 1, 1))
    check(mix.event_log.size() == 1, "moving within6m cell bypassed warning cooldown")
    mix._clock += 1.6
    mix._on_audio_event(&"squirrel_warn", Vector3(2, 1, 1))
    check(mix.event_log.size() == 2, "warning did not recover after cooldown")
    mix._on_audio_event(&"encounter_pump", Vector3(2, 1, 1))
    check(mix.event_log.size() == 3 and mix.event_log[-1].requested == "encounter_pump", "matching ordinary warning cooldown suppressed phase leader")
    clean(mix)
    mix._on_audio_event(&"guardian_hit", Vector3(1, 1, 1))
    mix._on_audio_event(&"guardian_defeat", Vector3(1, 1, 1))
    check(mix.event_log.size() == 2 and mix.event_log[-1].kind == "guardian_defeat", "lethal reaction suppressed by preceding hit")
    check(vocal_count(mix) == 1, "defeat call stacked on its own preceding hurt instead of replacing it")
    clean(mix)
    for index in range(3): mix._on_audio_event(&"squirrel_hit", Vector3(index * 10, 1, -5))
    mix._on_audio_event(&"squirrel_chatter", Vector3(40, 1, -5))
    check(mix.event_log.size() == 3, "quiet search chatter interrupted active combat voices")
    clean(mix)
    for index in range(Audio.POOL_SIZE): mix._on_audio_event(&"enemy_shoot", Vector3(index, 1, -5))
    mix._on_audio_event(&"guardian_rally", Vector3(40, 1, -5))
    check(vocal_count(mix) == 0 and mix.event_log.size() == Audio.POOL_SIZE, "vocal stole a higher-priority weapon cue")
    mix._on_audio_event(&"encounter_gallery", Vector3(40, 1, -5))
    check(not mix._pending_phase_event.is_empty(), "phase call was dropped instead of briefly waiting for protected weapons")
    for voice in mix.pool: voice.stop()
    mix._process(.01)
    check(mix._pending_phase_event.is_empty() and mix.event_log[-1].requested == "encounter_gallery", "queued phase call did not recover after protected weapon pool freed")
    var encounter_map := {&"encounter_entry": &"squirrel_rally", &"encounter_pump": &"squirrel_warn", &"encounter_gallery": &"guardian_rally", &"encounter_escape": &"guardian_warn"}
    for requested in encounter_map:
        clean(mix)
        root.get_node("SignalBus").emit_audio_event(requested, Vector3(3, 1, -2))
        check(mix.event_log.size() == 1, "mission cue did not emit exactly one call")
        if not mix.event_log.is_empty():
            check(mix.event_log[-1].kind == String(encounter_map[requested]) and mix.event_log[-1].requested == String(requested), "encounter mapping or original request metadata lost")
            check(mix.event_log[-1].projected, "phase leader call lost projected spatial mix")
            for voice in mix.pool:
                if voice.playing and voice.get_meta("vocal", false):
                    check(voice.max_distance >= 60.0 and voice.unit_size > 8.0, "distant phase leader is inaudible from authored route")
    clean(mix)
    mix._on_audio_event(&"squirrel_warn", Vector3(3, 1, -2))
    for voice in mix.pool:
        if voice.playing and voice.get_meta("vocal", false):
            check(is_equal_approx(voice.max_distance, float(Bank.settings(&"squirrel_warn").max_distance)) and is_equal_approx(voice.unit_size, float(Bank.settings(&"squirrel_warn").unit_size)), "projected encounter mix leaked into regular pooled voice")
    clean(mix)
    state.sfx_muted = true
    mix._on_audio_event(&"guardian_warn", Vector3.ZERO)
    check(mix.event_log.is_empty(), "vocal bypassed global mute")
    state.sfx_muted = false
    paused = true
    mix._on_audio_event(&"guardian_warn", Vector3.ZERO)
    check(mix.event_log.is_empty(), "vocal bypassed pause")
    paused = false
    var report := {"result": "PASS" if failures.is_empty() else "FAIL", "failures": failures, "vocal_sets": sequences, "vocal_concurrency_limit": Audio.VOCAL_VOICE_LIMIT, "vocal_window_limit": Audio.VOCAL_WINDOW_LIMIT, "vocal_reserved_phase_starts": Audio.VOCAL_RESERVED_PHASE_STARTS, "vocal_window_seconds": Audio.VOCAL_WINDOW_SECONDS, "scope": "Imported PCM/class-aware selection, shared anti-repeat bag, burst/cell cooldown recovery, reserved phase start, short bounded phase queue, lethal replacement, weapon priority, mission aliases, pause/mute. Staged events, not a subjective listening claim."}
    state.sfx_muted = original_mute
    scene.queue_free()
    current_scene = null
    for frame in range(6): await process_frame
    if not output.is_empty():
        var destination := output if output.ends_with(".json") else output.path_join("voices149-report.json")
        DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
        var file := FileAccess.open(destination, FileAccess.WRITE)
        if file == null:
            push_error("WOODLAND VOICES149: could not write report " + destination)
            quit(1)
            return
        file.store_string(JSON.stringify(report, "  ") + "\n")
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    if failures.is_empty(): print("WOODLAND VOICES149: PASS")
    quit(0 if failures.is_empty() else 1)
