extends Node3D
class_name Level1ParkAudio

const SOUNDS := {
    &"squirrel_warn":preload("res://assets/level1/audio/squirrel_warn.ogg"),
    &"gate_open":preload("res://assets/level1/audio/gate_open.ogg"),
    &"cone_throw":preload("res://assets/level1/audio/cone_throw.ogg"),
    &"step_grass":preload("res://assets/level1/audio/step_grass.ogg"),
    &"step_gravel":preload("res://assets/level1/audio/step_gravel.ogg"),
    &"shoot":preload("res://assets/shoot.wav"),
    &"squirrel_hit":preload("res://assets/squirrel_hit.wav"),
    &"pickup":preload("res://assets/pickup.wav"),
    &"damage":preload("res://assets/damage.wav"),
}
var pool: Array[AudioStreamPlayer3D] = []
var wind: AudioStreamPlayer
var water: AudioStreamPlayer3D
var cursor := 0
var step := 0

func _exit_tree() -> void:
    if SignalBus.audio_event.is_connected(_on_audio_event):
        SignalBus.audio_event.disconnect(_on_audio_event)
    for p in pool:
        p.stop()
        p.stream = null
    if wind:
        wind.stop()
        wind.stream = null
    if water:
        water.stop()
        water.stream = null

func _ready() -> void:
    add_to_group("level1_audio")
    for i in range(12):
        var p := AudioStreamPlayer3D.new()
        p.max_distance = 28.0
        p.unit_size = 4.0
        p.panning_strength = 0.8
        add_child(p)
        pool.append(p)
    wind = AudioStreamPlayer.new()
    wind.stream = preload("res://assets/level1/audio/park_wind.ogg")
    wind.stream.loop = true
    add_child(wind)
    water = AudioStreamPlayer3D.new()
    water.stream = preload("res://assets/level1/audio/garden_water.ogg")
    water.stream.loop = true
    water.max_distance = 23.0
    water.unit_size = 5.0
    add_child(water)
    water.position = LevelData.cell_center_world(Vector2i(10,9))+Vector3.UP
    SignalBus.audio_event.connect(_on_audio_event)

func _on_audio_event(kind: StringName, position_: Vector3) -> void:
    if GameState.sfx_muted: return
    if kind == &"footstep":
        step += 1
        kind = &"step_gravel" if LevelData.on_gravel(position_) else &"step_grass"
    if not SOUNDS.has(kind): return
    var p := pool[cursor]
    cursor = (cursor+1)%pool.size()
    for candidate in pool:
        if not candidate.playing:
            p = candidate
            break
    p.stream = SOUNDS[kind]
    p.global_position = position_
    p.volume_db = GameState.sfx_volume_db-3.0
    p.pitch_scale = 0.95+float(step%3)*0.05 if kind in [&"step_grass",&"step_gravel"] else 1.0
    p.play()

func _process(_delta: float) -> void:
    var muted := GameState.sfx_muted
    wind.volume_db = -80.0 if muted else GameState.sfx_volume_db-13.0
    water.volume_db = -80.0 if muted else GameState.sfx_volume_db-8.0
    if muted:
        wind.stop()
        water.stop()
        for p in pool: p.stop()
    else:
        if not wind.playing: wind.play()
        if not water.playing: water.play()
    var music := get_parent().get_node_or_null("Music") as AudioStreamPlayer
    if music: music.volume_db = GameState.music_volume_db-7.0
