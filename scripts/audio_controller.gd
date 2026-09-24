extends RefCounted
class_name AudioController

const FX_POOL_SIZE: int = 8

var music: AudioStreamPlayer
var fx: AudioStreamPlayer
var fx_pool: Array[AudioStreamPlayer] = []
var fx_cursor: int = 0
var music_muted: bool = false
var fx_muted: bool = false

var foot1_stream = preload("res://assets/footstep1.wav")
var foot2_stream = preload("res://assets/footstep2.wav")
var shoot_stream = preload("res://assets/shoot.wav")
var squirrel_hit_stream = preload("res://assets/squirrel_hit.wav")
var pickup_stream = preload("res://assets/pickup.wav")
var damage_stream = preload("res://assets/damage.wav")

func setup(music_player: AudioStreamPlayer, fx_player: AudioStreamPlayer) -> void:
    music = music_player
    fx = fx_player
    fx_pool.clear()
    fx_cursor = 0

    if fx != null:
        fx_pool.append(fx)
        var parent := fx.get_parent()
        if parent != null:
            for index in range(1, FX_POOL_SIZE):
                var player := AudioStreamPlayer.new()
                player.name = "FX_%02d" % index
                player.bus = fx.bus
                player.volume_db = fx.volume_db
                parent.add_child(player)
                fx_pool.append(player)

func start_music() -> void:
    if music == null or music_muted:
        return
    music.volume_db = -9.0
    music.play()

func footstep() -> void:
    play_fx(foot1_stream if int(Time.get_ticks_msec() / 300) % 2 == 0 else foot2_stream)

func play_fx(stream: AudioStream) -> void:
    if fx_muted or stream == null or fx_pool.is_empty():
        return

    var player: AudioStreamPlayer = null
    for offset in range(FX_POOL_SIZE):
        var index := posmod(fx_cursor + offset, fx_pool.size())
        var candidate := fx_pool[index]
        if candidate != null and not candidate.playing:
            player = candidate
            fx_cursor = posmod(index + 1, fx_pool.size())
            break

    if player == null:
        player = fx_pool[fx_cursor]
        fx_cursor = posmod(fx_cursor + 1, fx_pool.size())

    player.stream = stream
    player.play()

func play_shoot() -> void:
    play_fx(shoot_stream)

func play_damage() -> void:
    play_fx(damage_stream)

func play_squirrel_hit() -> void:
    play_fx(squirrel_hit_stream)

func play_pickup() -> void:
    play_fx(pickup_stream)

func toggle_music() -> bool:
    music_muted = not music_muted
    if music == null:
        return music_muted
    if music_muted:
        music.stop()
    elif not music.playing:
        music.play()
    return music_muted

func toggle_fx() -> bool:
    fx_muted = not fx_muted
    if fx_muted:
        for player in fx_pool:
            if player != null:
                player.stop()
    return fx_muted
