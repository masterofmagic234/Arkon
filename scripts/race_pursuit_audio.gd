extends Node
# Three tiny pre-generated PCM clips. Fixed simulation events own every cue.
var world
var rotor: AudioStreamPlayer
var radio: AudioStreamPlayer
var hit: AudioStreamPlayer
var _warning := 0
var _impact := 0
func _ready() -> void:
    rotor=_sound("rotor",true);radio=_sound("radio",false);hit=_sound("impact",false)
func bind(level) -> void: world=level
func _sound(name_: String,looping: bool) -> AudioStreamPlayer:
    var p:=AudioStreamPlayer.new()
    var stream:=load("res://assets/level2/pursuit/"+name_+".wav").duplicate() as AudioStreamWAV
    stream.loop_mode=AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
    stream.loop_begin=0;stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
    p.stream=stream;p.volume_db=-80;add_child(p);return p
func _process(_delta: float) -> void:
    if world==null: return
    var pursuit=world.controller.pursuit
    var active: bool=world.state.race_started and not world.state.race_finished and not GameState.sfx_muted
    var flying: bool=active and pursuit.phase!=&"idle" and preload("res://scripts/race_level_data.gd").sector_at(world.controller.player.world_z)!=4
    if flying:
        if not rotor.playing: rotor.play()
        var distance: float=absf(pursuit.helicopter_z-world.controller.player.world_z)
        rotor.volume_db=lerpf(-12,-27,clampf(distance/320,0,1))+GameState.sfx_volume_db
        rotor.pitch_scale=1.0+sin(pursuit.clock*.7)*.025
    else: rotor.stop()
    if pursuit.warning_serial!=_warning:
        _warning=pursuit.warning_serial
        if active: radio.volume_db=-11+GameState.sfx_volume_db;radio.play()
    if pursuit.impact_serial!=_impact:
        _impact=pursuit.impact_serial
        if active: hit.volume_db=-8+GameState.sfx_volume_db;hit.play()
    if not active: radio.stop();hit.stop()
func _exit_tree() -> void:
    for node in get_children():
        if node is AudioStreamPlayer: node.stop();node.stream=null
    world=null
