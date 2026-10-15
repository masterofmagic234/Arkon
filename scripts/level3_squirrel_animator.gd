extends RefCounted
# Presentation clock only. Combat owns windup, damage, collision and signals.
# Pausing the actor pauses every clip, including fall and attack recovery.
const Skins=preload("res://scripts/level3_squirrel_skins.gd")
var _sprite: AnimatedSprite2D
var _stride := 30.0
var _phase := 0.0
var _clock := 0.0
var _fall_time := 0.0
var _recovery := 0.0
var _recovery_duration := .18

func configure(sprite: AnimatedSprite2D, kind: StringName, phase_offset: float) -> void:
    _sprite=sprite
    _sprite.sprite_frames=Skins.frames(kind)
    _sprite.scale=Vector2.ONE*.78
    _sprite.position=Vector2.ZERO
    _sprite.rotation=0
    _sprite.pause()
    _stride=42.0 if kind==&"butcher" else (28.0 if kind==&"melee" else 30.0)
    _recovery_duration=.18 if kind==&"gunman" else (.30 if kind==&"butcher" else .26)
    _clock=phase_offset
    _phase=fposmod(phase_offset,1.0)
    _show(&"idle",floori(_clock*4)%8)

func update(delta: float, velocity: Vector2, facing: float, windup: float, windup_duration: float, stunned: bool, dead: bool) -> void:
    _clock+=delta
    if dead:
        _fall_time=minf(.36,_fall_time+delta)
        _show(&"fall",mini(5,floori(_fall_time/.06)))
    elif stunned:
        _show(&"stun",floori(_clock*6)%4)
    elif windup>0:
        # Scrub the pose against the actual attack timer: no second damage event
        # or animation signal can drift away from the existing combat window.
        _show_progress(&"windup",1.0-windup/windup_duration)
    elif _recovery>0:
        var progress := 1.0-_recovery/_recovery_duration
        _show_progress(&"attack",progress)
        _recovery=maxf(0,_recovery-delta)
    elif velocity.length_squared()>16:
        # Signed travel, rather than elapsed time, drives the new paw cycle.
        # Retreat plays the planted steps backwards; slow patrols cannot slide
        # through the same fixed-rate human walking loop as full-speed pursuit.
        var sign_ := -1.0 if velocity.dot(Vector2.from_angle(facing))<-.1 else 1.0
        _phase=fposmod(_phase+velocity.length()*delta/_stride*sign_,1.0)
        _show(&"walk",mini(11,floori(_phase*12)))
    else:
        _show(&"idle",floori(_clock*4)%8)

func attack() -> void: _recovery=_recovery_duration
func interrupt() -> void:
    _recovery=0
    _clock=0
func fall() -> void:
    interrupt()
    _fall_time=0
func _show_progress(clip: StringName, progress: float) -> void:
    var count:=_sprite.sprite_frames.get_frame_count(clip)
    _show(clip,clampi(floori(progress*count),0,count-1))
func _show(clip: StringName, frame: int) -> void:
    if _sprite.animation!=clip: _sprite.animation=clip
    _sprite.frame=frame
    _sprite.frame_progress=0
