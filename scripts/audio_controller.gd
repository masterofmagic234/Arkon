extends RefCounted
class_name AudioController

var music: AudioStreamPlayer
var fx: AudioStreamPlayer
var muted := false

var foot1_stream = preload("res://assets/footstep1.wav")
var foot2_stream = preload("res://assets/footstep2.wav")
var shoot_stream = preload("res://assets/shoot.wav")
var squirrel_hit_stream = preload("res://assets/squirrel_hit.wav")
var pickup_stream = preload("res://assets/pickup.wav")
var damage_stream = preload("res://assets/damage.wav")

func setup(music_player: AudioStreamPlayer, fx_player: AudioStreamPlayer) -> void:
    music = music_player
    fx = fx_player

func start_music() -> void:
    music.volume_db = -9.0
    music.play()

func footstep() -> void:
    if muted:
        return
    fx.stream = foot1_stream if int(Time.get_ticks_msec() / 300) % 2 == 0 else foot2_stream
    fx.play()

func play_fx(stream: AudioStream) -> void:
    if muted or stream == null:
        return
    fx.stream = stream
    fx.play()

func play_shoot() -> void:
    play_fx(shoot_stream)

func play_damage() -> void:
    play_fx(damage_stream)

func play_squirrel_hit() -> void:
    play_fx(squirrel_hit_stream)

func play_pickup() -> void:
    play_fx(pickup_stream)

func toggle_music() -> bool:
    muted = not muted
    if muted:
        music.stop()
    elif not music.playing:
        music.play()
    return muted
