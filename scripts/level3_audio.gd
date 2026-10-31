extends Node2D
class_name Level3Audio
const PATH := "res://assets/level3/audio/"
const SOUNDTRACKS := {
    &"daisuke":"res://assets/audio158/daisuke.ogg",
    &"rain":"res://assets/audio158/rain.ogg",
    &"radio":"res://assets/level3/audio/diner_radio.ogg",
}
const RECORD_SCRATCH := "res://assets/audio158/record_scratch.ogg"
const KINDS := [&"pistol",&"shotgun",&"enemy_shot",&"door",&"glass",&"step",&"bat",&"pickup"]
const CONE_FOLEY := {
    &"pistol":[preload("res://assets/level1/audio/polished147/compact_01.wav"),preload("res://assets/level1/audio/polished147/compact_02.wav")],
    &"shotgun":[preload("res://assets/level1/audio/polished147/scatter_01.wav"),preload("res://assets/level1/audio/polished147/scatter_02.wav")],
}
var _streams: Dictionary = {}
var _shot_variants: Dictionary = {}
var _pool: Array[AudioStreamPlayer2D] = []
var _cursor := 0
var _ambience: Array[AudioStreamPlayer2D] = []
var radio: AudioStreamPlayer
var music_state: StringName = &"daisuke"
var _pending_music: StringName = &""
var _music_streams: Dictionary = {}
var _record_scratch: AudioStreamOggVorbis
var _volume_tick := 0.0
var _step_index := 0
var _occlusion: Dictionary = {}
func _ready() -> void:
    add_to_group("level3_audio")
    for kind in KINDS:
        _streams[kind]=CONE_FOLEY[kind][0] if CONE_FOLEY.has(kind) else load(PATH+String(kind)+".ogg")
    for i in range(12):
        var p := AudioStreamPlayer2D.new()
        p.max_distance=760
        p.attenuation=1.25
        p.panning_strength=0.8
        add_child(p)
        _pool.append(p)
    _ambience.append(_loop("rain",Vector2(166,821),1100,-26))
    _ambience.append(_loop("fridge",Vector2(1035,150),330,-28))
    for key in SOUNDTRACKS:
        var stream := load(SOUNDTRACKS[key]) as AudioStreamOggVorbis
        if stream!=null:
            stream=stream.duplicate() as AudioStreamOggVorbis
            stream.loop=true
            _music_streams[key]=stream
    _record_scratch=load(RECORD_SCRATCH) as AudioStreamOggVorbis
    if _record_scratch!=null:
        _record_scratch=_record_scratch.duplicate() as AudioStreamOggVorbis
        _record_scratch.loop=false
    radio=AudioStreamPlayer.new()
    radio.name="DinerSoundtrack"
    radio.stream=_music_streams.get(music_state)
    add_child(radio)
    radio.finished.connect(_finish_music_transition)
    # One scene-owned player prevents old radio, score and scratches overlapping.
    get_node("/root/AudioManager").register_music(radio)
    _apply_volumes()

func set_story_phase(phase: StringName) -> void:
    if phase in [&"arrival",&"deployment",&"breach",&"return",&"assault"]:
        _change_music(&"rain")
    elif phase in [&"cleared",&"aftermath",&"pizza",&"exit",&"boarding"]:
        _change_music(&"radio")

func _change_music(next_state: StringName) -> void:
    if music_state==next_state: return
    music_state=next_state
    _pending_music=next_state
    radio.stop()
    if GameState.music_muted or _record_scratch==null:
        _finish_music_transition()
        return
    radio.stream=_record_scratch
    radio.volume_db=GameState.music_volume_db
    radio.play()

func _finish_music_transition() -> void:
    if _pending_music==&"" or not is_instance_valid(radio): return
    radio.stop()
    radio.stream=_music_streams.get(_pending_music)
    _pending_music=&""
    radio.volume_db=GameState.music_volume_db+(-14.0 if music_state==&"radio" else 0.0)
    if not GameState.music_muted and radio.stream!=null: radio.play()
func _loop(file: String, at: Vector2, distance_: float, volume: float) -> AudioStreamPlayer2D:
    var player := AudioStreamPlayer2D.new()
    var stream := load(PATH+file+".ogg") as AudioStreamOggVorbis
    stream.loop=true
    player.stream=stream
    player.position=at
    player.max_distance=distance_
    player.attenuation=1.15
    player.volume_db=volume
    player.set_meta("base_volume",volume)
    add_child(player)
    player.play()
    return player
func play_at(kind: StringName, at: Vector2) -> void:
    if GameState.sfx_muted or not _streams.has(kind): return
    var player := _pool[_cursor]
    _cursor=(_cursor+1)%_pool.size()
    for voice in _pool:
        if not voice.playing:
            player=voice
            break
    player.stop()
    player.global_position=at
    if CONE_FOLEY.has(kind):
        var variant: int=int(_shot_variants.get(kind,0))%CONE_FOLEY[kind].size()
        player.stream=CONE_FOLEY[kind][variant]
        _shot_variants[kind]=variant+1
    else:player.stream=_streams[kind]
    _step_index+=1
    player.pitch_scale=1.0+float(_step_index%5-2)*.025 if kind==&"step" else 1.0
    player.volume_db=GameState.sfx_volume_db+(-21.0 if kind==&"step" else (-11.0 if kind==&"door" else -8.0))
    player.play()
func _process(delta: float) -> void:
    _volume_tick-=delta
    if _volume_tick<=0:
        _volume_tick=.25
        _apply_volumes()
func _apply_volumes() -> void:
    for player in _ambience:
        player.volume_db=float(player.get_meta("base_volume"))+GameState.sfx_volume_db+_muffling(player)
        if GameState.sfx_muted: player.stop()
        elif not player.playing: player.play()
    if is_instance_valid(radio):
        radio.volume_db=GameState.music_volume_db+(-14.0 if music_state==&"radio" and _pending_music==&"" else 0.0)
        if GameState.music_muted:
            radio.stop()
            # Unmuting resumes the selected score, never an obsolete scratch.
            if _pending_music!=&"": _finish_music_transition()
        elif not radio.playing and radio.stream!=null: radio.play()
    if GameState.sfx_muted:
        for player in _pool: player.stop()
func _exit_tree() -> void:
    for player in _pool+_ambience:
        player.stop()
        player.stream=null
    if is_instance_valid(radio):
        radio.stop()
        radio.stream=null
    _occlusion.clear()
    _streams.clear()
    _shot_variants.clear()
    _music_streams.clear()
    _record_scratch=null
    _pool.clear()
    _ambience.clear()
    radio=null

func _muffling(source: AudioStreamPlayer2D) -> float:
    var store := get_parent()
    if not is_instance_valid(store.player) or not store.navigation.ready: return 0.0
    var blocked: bool=not store.has_line_of_sight(source.global_position,store.player.global_position)
    var previous: float=_occlusion.get(source.get_instance_id(),0.0)
    var value := lerpf(previous,-8.0 if blocked else 0.0,.38)
    _occlusion[source.get_instance_id()]=value
    return value
