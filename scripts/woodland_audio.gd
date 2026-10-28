extends Node3D
## Scene-local foley bus, head-locked player cues and positional opponents.
## The global AudioManager defers while this owner is in level1_audio.
const Bank = preload("res://scripts/woodland_audio_bank.gd")
const Surfaces = preload("res://scripts/woodland_audio_surfaces.gd")
const POOL_SIZE := 12
const LOCAL_POOL_SIZE := 6
const POND := Vector3(-27, .7, -18)

var pool: Array[AudioStreamPlayer3D] = []
var local_pool: Array[AudioStreamPlayer] = []
var wind: AudioStreamPlayer
var water: AudioStreamPlayer3D
var cursor := 0
var step := 0
var event_log: Array[Dictionary] = []
var dropped_muted := 0
var dropped_paused := 0
var peak_active_voices := 0
var streams: Dictionary = {}
var _bags: Dictionary = {}
var _last: Dictionary = {}
var _cooldowns: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _cooldown_sweep := 0.0
var _bus_name := ""
var _last_volume := INF

func _ready() -> void:
    add_to_group("level1_audio")
    process_mode = Node.PROCESS_MODE_ALWAYS
    _rng.randomize()
    _make_bus()
    for kind in Bank.SETS:
        for id in Bank.SETS[kind]:
            if streams.has(id): continue
            var stream := load(Bank.path_for(id)) as AudioStream
            if stream == null:
                push_error("WOODLAND AUDIO: missing prepared take " + id)
                continue
            streams[id] = stream
    for i in range(POOL_SIZE):
        var voice := AudioStreamPlayer3D.new()
        voice.name = "WoodlandVoice%02d" % i
        voice.bus = _bus_name
        voice.process_mode = Node.PROCESS_MODE_PAUSABLE
        voice.max_distance = 34.0
        voice.unit_size = 3.6
        voice.panning_strength = .85
        voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
        add_child(voice)
        pool.append(voice)
    for i in range(LOCAL_POOL_SIZE):
        var voice := AudioStreamPlayer.new()
        voice.name = "PlayerFoley%02d" % i
        voice.bus = _bus_name
        voice.process_mode = Node.PROCESS_MODE_PAUSABLE
        add_child(voice)
        local_pool.append(voice)
    wind = AudioStreamPlayer.new()
    wind.name = "WoodlandWind"
    wind.bus = _bus_name
    wind.process_mode = Node.PROCESS_MODE_PAUSABLE
    wind.stream = _loop_stream(Bank.ROOT + "ambience_wind.wav")
    wind.volume_db = -14.0
    add_child(wind)
    water = AudioStreamPlayer3D.new()
    water.name = "WoodlandPond"
    water.bus = _bus_name
    water.process_mode = Node.PROCESS_MODE_PAUSABLE
    water.stream = _loop_stream(Bank.ROOT + "ambience_water.wav")
    water.volume_db = -9.0
    water.max_distance = 24.0
    water.unit_size = 5.0
    water.position = POND
    add_child(water)
    SignalBus.audio_event.connect(_on_audio_event)
    SignalBus.entity_damaged.connect(_on_entity_damaged)
    PauseManager.pause_state_changed.connect(_on_pause_changed)
    _apply_mix()

func _make_bus() -> void:
    _bus_name = "WoodlandSFX_" + str(get_instance_id())
    AudioServer.add_bus()
    var index := AudioServer.bus_count - 1
    AudioServer.set_bus_name(index, _bus_name)
    AudioServer.set_bus_send(index, "Master")
    # Bound overlapping effects without changing music or cinematic audio.
    var limiter := AudioEffectLimiter.new()
    limiter.threshold_db = -1.5
    limiter.ceiling_db = -1.0
    limiter.soft_clip_db = 0.0
    AudioServer.add_bus_effect(index, limiter)

func _loop_stream(path: String) -> AudioStreamWAV:
    var stream := load(path).duplicate() as AudioStreamWAV
    var frame_count := roundi(stream.get_length() * float(stream.mix_rate))
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = frame_count
    return stream

func set_variation_seed(value: int) -> void:
    _rng.seed = value
    _bags.clear()
    _last.clear()

func _next_take(kind: StringName) -> String:
    var names: Array = Bank.SETS[kind]
    var bag: Array = _bags.get(kind, [])
    if bag.is_empty():
        bag = range(names.size())
        for i in range(bag.size() - 1, 0, -1):
            var other := _rng.randi_range(0, i)
            var old = bag[i]
            bag[i] = bag[other]
            bag[other] = old
        if bag.size() > 1 and _last.get(kind, "") == names[bag[-1]]:
            var old = bag[0]
            bag[0] = bag[-1]
            bag[-1] = old
    var id: String = names[bag.pop_back()]
    _bags[kind] = bag
    _last[kind] = id
    return id

func _garden_world() -> Node:
    var scene := get_tree().current_scene
    return scene.get("world") if is_instance_valid(scene) and scene.get("world") is Node else null

func _on_audio_event(requested_kind: StringName, position_: Vector3) -> void:
    if GameState.sfx_muted:
        dropped_muted += 1
        return
    if get_tree().paused or PauseManager.is_paused:
        dropped_paused += 1
        return
    var kind := Bank.canonical(requested_kind)
    if kind in [&"footstep", &"enemy_footstep"]:
        step += 1
        var material_step := Surfaces.step_kind(position_, _garden_world())
        kind = StringName("enemy_" + String(material_step)) if kind == &"enemy_footstep" else material_step
    if not Bank.SETS.has(kind): return
    var settings := Bank.settings(kind)
    # Health facts and projectile feedback can describe the same accepted hit.
    if float(settings.cooldown) > 0.0:
        var key := String(kind) + (":self" if kind == &"damage" else ":" + str(position_.snapped(Vector3.ONE)))
        if float(_cooldowns.get(key, -100.0)) > _clock: return
        _cooldowns[key] = _clock + float(settings.cooldown)
    var voice = _voice_for(bool(settings.local), int(settings.priority))
    if voice == null: return
    var id := _next_take(kind)
    if not streams.has(id): return
    voice.stop()
    voice.stream = streams[id]
    voice.set_meta("priority", int(settings.priority))
    voice.set_meta("started_at", _clock)
    voice.set_meta("sound_kind", kind)
    voice.set_meta("take_id", id)
    var pitch_span := float(settings.pitch_span)
    voice.pitch_scale = float(settings.pitch_base) + _rng.randf_range(-pitch_span, pitch_span)
    voice.volume_db = float(settings.gain_db) + _rng.randf_range(-.4, .4)
    voice.stream_paused = false
    if voice is AudioStreamPlayer3D:
        voice.global_position = position_
        voice.max_distance = float(settings.max_distance)
        voice.unit_size = float(settings.unit_size)
    voice.play()
    event_log.append({"kind": String(kind), "requested": String(requested_kind), "take": id, "position": [position_.x, position_.y, position_.z], "local": bool(settings.local), "pitch": voice.pitch_scale, "gain_db": voice.volume_db, "time": _clock})
    if event_log.size() > 256: event_log.pop_front()
    peak_active_voices = maxi(peak_active_voices, active_voices())

func _voice_for(local: bool, priority: int):
    var voices: Array = local_pool if local else pool
    for voice in voices:
        if not voice.playing: return voice
    var chosen = voices[0]
    for voice in voices:
        var low: int = voice.get_meta("priority", 1)
        var best: int = chosen.get_meta("priority", 1)
        if low < best or (low == best and float(voice.get_meta("started_at", 0.0)) < float(chosen.get_meta("started_at", 0.0))): chosen = voice
    # A quiet footfall cannot cut off a fresh weapon or player-hit cue.
    return null if int(chosen.get_meta("priority", 1)) > priority else chosen

func _on_entity_damaged(entity: Node, _amount: int, _source: Node) -> void:
    if is_instance_valid(entity) and entity.is_in_group("level1_player") and entity is Node3D:
        _on_audio_event(&"damage", entity.global_position)

func active_voices() -> int:
    var total := 0
    for voice in pool:
        if voice.playing: total += 1
    for voice in local_pool:
        if voice.playing: total += 1
    return total

func _on_pause_changed(value: bool) -> void:
    for voice in pool: voice.stream_paused = value
    for voice in local_pool: voice.stream_paused = value
    if is_instance_valid(wind): wind.stream_paused = value
    if is_instance_valid(water): water.stream_paused = value

func _process(delta: float) -> void:
    if not get_tree().paused:
        _clock += delta
        _cooldown_sweep += delta
        if _cooldown_sweep >= 1.0:
            _cooldown_sweep = 0.0
            for key in _cooldowns.keys():
                if float(_cooldowns[key]) <= _clock: _cooldowns.erase(key)
    _apply_mix()

func _apply_mix() -> void:
    if not is_instance_valid(wind) or not is_instance_valid(water): return
    var bus := AudioServer.get_bus_index(_bus_name)
    if bus >= 0 and not is_equal_approx(_last_volume, GameState.sfx_volume_db):
        AudioServer.set_bus_volume_db(bus, GameState.sfx_volume_db)
        _last_volume = GameState.sfx_volume_db
    if GameState.sfx_muted:
        wind.stop()
        water.stop()
        for voice in pool: voice.stop()
        for voice in local_pool: voice.stop()
        return
    if get_tree().paused or PauseManager.is_paused: return
    if not wind.playing: wind.play()
    if not water.playing: water.play()

func _exit_tree() -> void:
    if is_instance_valid(SignalBus):
        if SignalBus.audio_event.is_connected(_on_audio_event): SignalBus.audio_event.disconnect(_on_audio_event)
        if SignalBus.entity_damaged.is_connected(_on_entity_damaged): SignalBus.entity_damaged.disconnect(_on_entity_damaged)
    if is_instance_valid(PauseManager) and PauseManager.pause_state_changed.is_connected(_on_pause_changed): PauseManager.pause_state_changed.disconnect(_on_pause_changed)
    for voice in pool:
        voice.stop()
        voice.stream = null
    for voice in local_pool:
        voice.stop()
        voice.stream = null
    pool.clear()
    local_pool.clear()
    streams.clear()
    if is_instance_valid(wind):
        wind.stop()
        wind.stream = null
    if is_instance_valid(water):
        water.stop()
        water.stream = null
    wind = null
    water = null
    var bus := AudioServer.get_bus_index(_bus_name)
    if bus >= 0: AudioServer.remove_bus(bus)
