extends SceneTree
## Foley lifecycle/selection/mix contracts. Staged inputs are not a playthrough.
var Audio
const Bank = preload("res://scripts/woodland_audio_bank.gd")
const Surfaces = preload("res://scripts/woodland_audio_surfaces.gd")
class Fixture extends Node3D:
    var world: Node3D
var failures: Array[String] = []
var output := ""

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool, why: String) -> void:
    if not ok:
        failures.append(why)
        push_error("WOODLAND AUDIO: " + why)

func settle(frames: int = 3) -> void:
    for frame in range(frames): await process_frame

func stop_voices(mix) -> void:
    for voice in mix.local_pool: voice.stop()
    for voice in mix.pool: voice.stop()

func run() -> void:
    Audio = load("res://scripts/woodland_audio.gd")
    var old_mute: bool = root.get_node("GameState").sfx_muted
    var old_volume: float = root.get_node("GameState").sfx_volume_db
    root.get_node("GameState").sfx_muted = false
    root.get_node("GameState").sfx_volume_db = 0
    root.get_node("PauseManager").set_paused(false)
    var initial_buses := AudioServer.bus_count
    var scene := Fixture.new()
    root.add_child(scene)
    current_scene = scene
    scene.world = Node3D.new()
    scene.add_child(scene.world)
    scene.world.set_meta("audio_paths", [{"points": [Vector2(0, 0), Vector2(0, 20)], "half_width": 2.5, "surface": &"stone"}])
    scene.world.set_meta("audio_surface_zones", [{"center": Vector2(10, 10), "radius": 2.0, "surface": &"soil"}])
    var mix = Audio.new()
    scene.add_child(mix)
    await settle()
    mix.set_variation_seed(147)
    check(AudioServer.bus_count == initial_buses + 1, "scene did not create one isolated sound bus")
    var bus := AudioServer.get_bus_index(mix._bus_name)
    check(bus >= 0 and AudioServer.get_bus_effect_count(bus) == 1 and AudioServer.get_bus_effect(bus, 0) is AudioEffectLimiter, "scene-local overload limiter missing")
    check(mix.streams.size() == 33, "prepared one-shot inventory incomplete")
    for stream in mix.streams.values():
        check(stream is AudioStreamWAV and stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == 44100 and not stream.stereo, "cached one-shot was imported with lossy compression, resampling or an incorrect channel layout")
    check(mix.wind.stream is AudioStreamWAV and mix.wind.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "breeze is not a prepared loop")
    check(mix.water.stream is AudioStreamWAV and not mix.water.stream.stereo, "spatial water is not mono")
    check(absf(float(mix.water.stream.loop_end) / mix.water.stream.mix_rate - 3.84) < .001, "water loop cuts the prepared recording to a compressed byte count")
    check(mix.pool.size() == Audio.POOL_SIZE and mix.local_pool.size() == Audio.LOCAL_POOL_SIZE, "voice pools are not bounded")
    check(Surfaces.step_kind(Vector3(2.4, 0, 10), scene.world) == &"step_stone", "authored paving half-width ignored")
    check(Surfaces.step_kind(Vector3(2.6, 0, 10), scene.world) == &"step_grass", "paving leaks beyond its geometry")
    check(Surfaces.step_kind(Vector3(10, 0, 10), scene.world) == &"step_soil", "explicit soil zone ignored")
    for material in [&"stone", &"wood", &"metal", &"soil"]:
        var collider := Node3D.new()
        scene.add_child(collider)
        collider.set_meta("audio_surface", material)
        check(Surfaces.impact_kind({"collider": collider}, scene.world) == StringName("impact_" + String(material)), "real collider material not selected: " + String(material))
        collider.queue_free()
    var terrain := Node3D.new()
    scene.add_child(terrain)
    terrain.set_meta("audio_surface", &"grass")
    check(Surfaces.impact_kind({"collider":terrain,"position":Vector3(0,0,10),"normal":Vector3.UP},scene.world) == &"impact_stone", "a real terrain collider under visible paving selects a soil impact")
    check(Surfaces.impact_kind({"collider":terrain,"position":Vector3(6,0,10),"normal":Vector3.UP},scene.world) == &"impact_soil", "grass beside the path incorrectly selects paving impact")
    check(Surfaces.impact_kind({"collider":terrain,"position":Vector3(0,0,10),"normal":Vector3.RIGHT},scene.world) == &"impact_soil", "an upright terrain face inherited the horizontal path's material")
    var sequences := {}
    for kind in [&"step_stone", &"step_grass", &"step_soil", &"shoot", &"enemy_shoot", &"squirrel_hit"]:
        var sequence: Array[String] = []
        for n in range(Bank.SETS[kind].size() * 3):
            stop_voices(mix)
            mix._on_audio_event(kind, Vector3(-8, 1, -6))
            sequence.append(mix.event_log[-1].take)
        for n in range(1, sequence.size()): check(sequence[n] != sequence[n - 1], "immediate repeated take for " + String(kind))
        var first_bag := {}
        for n in range(Bank.SETS[kind].size()): first_bag[sequence[n]] = true
        check(first_bag.size() == Bank.SETS[kind].size(), "variation bag omits a real take for " + String(kind))
        sequences[String(kind)] = sequence
    stop_voices(mix)
    root.get_node("SignalBus").emit_audio_event(&"footstep", Vector3(0, 0, 10))
    check(mix.event_log[-1].kind == "step_stone" and mix.event_log[-1].local, "existing footstep fact did not choose the local paving foley")
    var before: int = mix.event_log.size()
    root.get_node("SignalBus").emit_audio_event(&"shoot", Vector3.ZERO)
    check(mix.event_log.size() == before + 1, "one player shot was handled more than once")
    var global_manager := root.get_node("AudioManager")
    for voice in global_manager._sfx_pool: check(not voice.playing, "global legacy pool doubled the new Level1 sound")
    stop_voices(mix)
    mix._on_audio_event(&"enemy_shoot", Vector3(9, 1.2, -3))
    var positioned := false
    for voice in mix.pool:
        if voice.playing and voice.get_meta("sound_kind", &"") == &"enemy_shoot":
            positioned = voice.global_position.distance_to(Vector3(9, 1.2, -3)) < .001
    check(positioned and not mix.event_log[-1].local, "enemy cone release lost its physical position")
    check(String(mix.event_log[-1].take).begins_with("attack_"), "hand-thrown scout cone incorrectly sounds like a firearm")
    stop_voices(mix)
    mix._on_audio_event(&"enemy_footstep", Vector3(0,0,10))
    check(mix.event_log[-1].kind == "enemy_step_stone" and not mix.event_log[-1].local and mix.event_log[-1].gain_db < -9 and mix.event_log[-1].pitch > 1.07, "nearby squirrel footfall is not a quieter spatial surface cue")
    root.get_node("GameState").sfx_volume_db = -12
    mix._apply_mix()
    check(is_equal_approx(AudioServer.get_bus_volume_db(bus), -12), "volume changes do not affect already-playing voices")
    var player := Node3D.new()
    scene.add_child(player)
    player.add_to_group("level1_player")
    before = mix.event_log.size()
    root.get_node("SignalBus").entity_damaged.emit(player, 8, null)
    root.get_node("SignalBus").emit_audio_event(&"body_hit", player.global_position)
    check(mix.event_log.size() == before + 1, "health and projectile facts doubled a single player hit")
    root.get_node("PauseManager").set_paused(true)
    check(mix.wind.stream_paused and mix.water.stream_paused, "pause did not pause ambient streams")
    for voice in mix.local_pool:
        if voice.playing: check(voice.stream_paused, "pause left a player voice audible")
    before = mix.event_log.size()
    mix._on_audio_event(&"shoot", Vector3.ZERO)
    await settle()
    check(mix.event_log.size() == before and mix.dropped_paused > 0, "paused gameplay queued a later shot")
    root.get_node("PauseManager").set_paused(false)
    root.get_node("GameState").sfx_muted = true
    mix._apply_mix()
    check(mix.active_voices() == 0 and not mix.wind.playing and not mix.water.playing, "mute left sounds playing")
    before = mix.event_log.size()
    mix._on_audio_event(&"shoot", Vector3.ZERO)
    check(mix.event_log.size() == before and mix.dropped_muted > 0, "muted sound was queued")
    root.get_node("GameState").sfx_muted = false
    mix._apply_mix()
    for n in range(Audio.LOCAL_POOL_SIZE): mix._on_audio_event(&"shoot", Vector3.ZERO)
    for n in range(60): mix._on_audio_event(&"enemy_shoot", Vector3(n * .1, 1, -5))
    check(mix.active_voices() <= Audio.POOL_SIZE + Audio.LOCAL_POOL_SIZE, "rapid fire grows the voice pool")
    check(mix.peak_active_voices == Audio.POOL_SIZE + Audio.LOCAL_POOL_SIZE, "full simultaneous local/spatial stress was not exercised")
    before = mix.event_log.size()
    mix._on_audio_event(&"step_stone", Vector3.ZERO)
    check(mix.event_log.size() == before, "a quiet footstep stole a full-priority weapon slot")
    check(mix._cooldowns.size() <= 2, "ordinary moving footsteps/shots grow a permanent position cache")
    await settle(70)
    check(mix._cooldowns.is_empty(), "expired hit/tell cooldowns leak after their window")
    var peak_voices: int = mix.peak_active_voices
    var final_events: Array = mix.event_log.duplicate(true)
    scene.queue_free()
    current_scene = null
    await settle(6)
    check(AudioServer.bus_count == initial_buses, "scene exit leaked an audio bus")
    root.get_node("GameState").sfx_muted = old_mute
    root.get_node("GameState").sfx_volume_db = old_volume
    if not output.is_empty():
        DirAccess.make_dir_recursive_absolute(output)
        FileAccess.open(output.path_join("audio-report.json"), FileAccess.WRITE).store_string(JSON.stringify({"failures": failures, "variation_sequences": sequences, "peak_active_voices": peak_voices, "events": final_events, "scope": "Staged lifecycle/selection/spatial-routing checks, not subjective listening or a full gameplay recording."}, "  "))
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    if failures.is_empty(): print("WOODLAND AUDIO: PASS — authored surfaces, non-repeating foley, positional enemies, live volume, pause/mute/dedup, bounded voices and cleanup")
    quit(0 if failures.is_empty() else 1)
