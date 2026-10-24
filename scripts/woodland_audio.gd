extends Node3D

# This scene owns its spatial mix. The global pool defers while level1_audio
# exists, so a sling shot or pickup is never played twice.
const SOUNDS := {
    &"squirrel_warn": preload("res://assets/level1/audio/squirrel_warn.ogg"),
    &"gate_open": preload("res://assets/level1/audio/gate_open.ogg"),
    &"cone_throw": preload("res://assets/level1/audio/cone_throw.ogg"),
    &"step_grass": preload("res://assets/level1/audio/step_grass.ogg"),
    &"step_gravel": preload("res://assets/level1/audio/step_gravel.ogg"),
    &"shoot": preload("res://assets/shoot.wav"),
    &"squirrel_hit": preload("res://assets/squirrel_hit.wav"),
    &"pickup": preload("res://assets/pickup.wav"),
    &"damage": preload("res://assets/damage.wav"),
    &"woodland_bell": preload("res://assets/level1/audio/heist_bell.ogg"),
    &"woodland_activate": preload("res://assets/level1/audio/heist_solved.ogg"),
}
const POND := Vector3(-27, 0.7, -18)
const POOL_SIZE := 12

var pool: Array[AudioStreamPlayer3D] = []
var wind: AudioStreamPlayer
var water: AudioStreamPlayer3D
var cursor := 0
var step := 0

func _ready() -> void:
    add_to_group("level1_audio")
    for i in range(POOL_SIZE):
        var voice := AudioStreamPlayer3D.new()
        voice.name = "WoodlandVoice%02d" % i
        voice.max_distance = 32.0
        voice.unit_size = 3.5
        voice.panning_strength = 0.8
        voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
        add_child(voice)
        pool.append(voice)
    wind = AudioStreamPlayer.new()
    wind.name = "WoodlandWind"
    # Loop flags belong to this scene's copies, not globally shared imports.
    wind.stream = preload("res://assets/level1/audio/park_wind.ogg").duplicate()
    wind.stream.loop = true
    add_child(wind)
    water = AudioStreamPlayer3D.new()
    water.name = "WoodlandPond"
    water.stream = preload("res://assets/level1/audio/garden_water.ogg").duplicate()
    water.stream.loop = true
    water.max_distance = 24.0
    water.unit_size = 5.0
    water.position = POND
    add_child(water)
    SignalBus.audio_event.connect(_on_audio_event)
    _apply_mix()

func _on_audio_event(kind: StringName, position_: Vector3) -> void:
    if GameState.sfx_muted or pool.is_empty():
        return
    var quiet := false
    if kind == &"footstep":
        step += 1
        kind = &"step_grass"
        var player := get_tree().get_first_node_in_group("level1_player")
        if is_instance_valid(player):
            quiet = player.quiet_mode
    if not SOUNDS.has(kind):
        return
    var voice := pool[cursor]
    for offset in range(pool.size()):
        var index := (cursor + offset) % pool.size()
        if not pool[index].playing:
            voice = pool[index]
            cursor = index
            break
    cursor = (cursor + 1) % pool.size()
    voice.stop()
    voice.stream = SOUNDS[kind]
    voice.global_position = position_
    voice.volume_db = GameState.sfx_volume_db - (15.0 if quiet else 3.0)
    voice.pitch_scale = 0.95 + float(step % 3) * 0.05 if kind in [&"step_grass", &"step_gravel"] else 1.0
    voice.play()

func _process(_delta: float) -> void:
    _apply_mix()

func _apply_mix() -> void:
    if not is_instance_valid(wind) or not is_instance_valid(water):
        return
    if GameState.sfx_muted:
        wind.stop()
        water.stop()
        for voice in pool:
            voice.stop()
        return
    wind.volume_db = GameState.sfx_volume_db - 16.0
    water.volume_db = GameState.sfx_volume_db - 10.0
    if not wind.playing:
        wind.play()
    if not water.playing:
        water.play()

func _exit_tree() -> void:
    if SignalBus.audio_event.is_connected(_on_audio_event):
        SignalBus.audio_event.disconnect(_on_audio_event)
    for voice in pool:
        voice.stop()
        voice.stream = null
    pool.clear()
    if is_instance_valid(wind):
        wind.stop()
        wind.stream = null
    if is_instance_valid(water):
        water.stop()
        water.stream = null
    wind = null
    water = null
