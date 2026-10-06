extends Node
# Autoload singleton. Global SFX pool + music control.
# Global owner of SignalBus.audio_event SFX. Levels only register scene-local music.

const SFX_POOL_SIZE := 12

const SFX_PATHS: Dictionary = {
    &"footstep1": "res://assets/footstep1.wav",
    &"footstep2": "res://assets/footstep2.wav",
    &"shoot": "res://assets/shoot.wav",
    &"squirrel_hit": "res://assets/squirrel_hit.wav",
    &"pickup": "res://assets/pickup.wav",
    &"damage": "res://assets/damage.wav",
}

var _sfx_streams: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _music_player: AudioStreamPlayer = null
var _signal_bus: Node = null

func _ready() -> void:
    _load_sfx_streams()
    for i in SFX_POOL_SIZE:
        var p := AudioStreamPlayer.new()
        p.name = "SFX_%02d" % i
        p.bus = "Master"
        add_child(p)
        _sfx_pool.append(p)
    _signal_bus = get_node_or_null("/root/SignalBus")
    if _signal_bus != null and not _signal_bus.is_connected(&"audio_event", Callable(self, "_on_audio_event")):
        _signal_bus.connect(&"audio_event", Callable(self, "_on_audio_event"))
    _apply_volumes()

func _exit_tree() -> void:
    if _signal_bus != null:
        var callback := Callable(self, "_on_audio_event")
        if _signal_bus.is_connected(&"audio_event", callback):
            _signal_bus.disconnect(&"audio_event", callback)

    # Stop active playback before autoload teardown so headless shutdown does
    # not retain AudioStreamPlayback/AudioStream resources past their owners.
    for p in _sfx_pool:
        if is_instance_valid(p):
            p.stop()
            p.stream = null
            remove_child(p)
            p.free()
    _sfx_pool.clear()
    _sfx_streams.clear()

    if is_instance_valid(_music_player):
        _music_player.stop()
    _music_player = null

func _on_audio_event(kind: StringName, _position: Vector3) -> void:
    match kind:
        &"footstep":
            play_sfx(&"footstep1" if int(Time.get_ticks_msec() / 300) % 2 == 0 else &"footstep2")
        &"shoot":
            play_sfx(&"shoot")
        &"damage":
            play_sfx(&"damage")
        &"squirrel_hit":
            play_sfx(&"squirrel_hit")
        &"pickup":
            play_sfx(&"pickup")

func _load_sfx_streams() -> void:
    _sfx_streams.clear()
    for kind in SFX_PATHS:
        var path: String = SFX_PATHS[kind] as String
        var stream: AudioStream = load(path) as AudioStream
        if stream != null:
            _sfx_streams[kind] = stream

func play_sfx(kind: StringName) -> void:
    if GameState.sfx_muted:
        return
    var stream: AudioStream = _sfx_streams.get(kind, null) as AudioStream
    if stream == null:
        return
    var player := _next_free_player()
    player.volume_db = GameState.sfx_volume_db
    player.stream = stream
    player.play()

func _next_free_player() -> AudioStreamPlayer:
    for offset in _sfx_pool.size():
        var idx := posmod(_sfx_cursor + offset, _sfx_pool.size())
        if not _sfx_pool[idx].playing:
            _sfx_cursor = posmod(idx + 1, _sfx_pool.size())
            return _sfx_pool[idx]
    var p := _sfx_pool[_sfx_cursor]
    _sfx_cursor = posmod(_sfx_cursor + 1, _sfx_pool.size())
    return p

func register_music(player: AudioStreamPlayer) -> void:
    if is_instance_valid(_music_player) and _music_player != player:
        # The previous scene owns its music node; stop it before replacing the
        # reference so playback cannot outlive the scene transition.
        _music_player.stop()
        if _music_player.tree_exiting.is_connected(_on_music_exiting):
            _music_player.tree_exiting.disconnect(_on_music_exiting)
    _music_player = player
    if player == null:
        return
    if not player.tree_exiting.is_connected(_on_music_exiting):
        player.tree_exiting.connect(_on_music_exiting, CONNECT_ONE_SHOT)
    _apply_volumes()
    if GameState.music_muted:
        player.stop()
    elif not player.playing:
        player.play()

func _on_music_exiting() -> void:
    _music_player = null

func toggle_music() -> bool:
    if not is_instance_valid(_music_player):
        _music_player = null
    GameState.set_music_muted(not GameState.music_muted)
    if is_instance_valid(_music_player):
        if GameState.music_muted:
            _music_player.stop()
        elif not _music_player.playing:
            _music_player.play()
    return GameState.music_muted

func toggle_sfx() -> bool:
    GameState.set_sfx_muted(not GameState.sfx_muted)
    if GameState.sfx_muted:
        for p in _sfx_pool:
            p.stop()
    return GameState.sfx_muted

func _apply_volumes() -> void:
    for p in _sfx_pool:
        p.volume_db = GameState.sfx_volume_db
    if is_instance_valid(_music_player):
        _music_player.volume_db = GameState.music_volume_db
