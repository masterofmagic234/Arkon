extends RefCounted

const SquirrelTypes = preload("res://scripts/squirrel_types.gd")

enum State { PATROL, CHASE, SEARCH, FLEE, STUNNED, CARRY }
var id := ""
var kind: int = SquirrelTypes.Kind.SCOUT
var hp := 2
var position := Vector3.ZERO
var home := Vector3.ZERO
var patrol_points: Array = []
var patrol_index := 0
var state: int = State.PATROL
var state_timer := 0.0
var last_known_player := Vector3.ZERO
var has_player_memory := false
var speed := 3.4
var attack_cooldown := 0.0
var stun_timer := 0.0
var panic_timer := 0.0
var debug_reason := ""

func setup(squirrel_id: String, kind_: int, pos: Vector3, patrol: Array = []) -> void:
    id = squirrel_id
    kind = kind_
    hp = SquirrelTypes.hp_of(kind_)
    speed = SquirrelTypes.speed_of(kind_)
    position = pos
    home = pos
    patrol_points = patrol.duplicate()
    state = State.PATROL
    debug_reason = "spawn"

func is_stunned() -> bool: return state == State.STUNNED
func stun(duration: float = 3.0) -> void:
    state = State.STUNNED
    stun_timer = duration
    debug_reason = "stunned"
func panic(duration: float = 1.5) -> void:
    if state != State.STUNNED: panic_timer = maxf(panic_timer, duration)

func desired_direction(player_pos: Vector3, player_visible: bool, nearby_squirrels: Array, _nearby_acorns: Array, dt: float) -> Vector3:
    state_timer = maxf(state_timer - dt, 0.0)
    attack_cooldown = maxf(attack_cooldown - dt, 0.0)
    panic_timer = maxf(panic_timer - dt, 0.0)
    if state == State.STUNNED:
        stun_timer -= dt
        if stun_timer <= 0.0: state = State.PATROL
        return Vector3.ZERO
    if panic_timer > 0.0: return _away(player_pos)
    match kind:
        SquirrelTypes.Kind.RUNNER: return _runner(player_pos, player_visible, nearby_squirrels)
        SquirrelTypes.Kind.THROWER: return _thrower(player_pos, player_visible)
        _: return _default(player_pos, player_visible)

func can_attack(dist: float) -> bool:
    if state == State.STUNNED or attack_cooldown > 0.0: return false
    if kind == SquirrelTypes.Kind.THIEF or kind == SquirrelTypes.Kind.RUNNER: return false
    return dist <= SquirrelTypes.attack_distance_of(kind)
func mark_attacked(cooldown := 0.8) -> void: attack_cooldown = cooldown
func take_hit(damage := 1) -> bool:
    hp = maxi(hp - damage, 0)
    if hp <= 0: stun()
    return hp <= 0

func _away(p: Vector3) -> Vector3:
    var d := position - p; d.y = 0.0
    if d.length() < 0.05: d = Vector3.RIGHT
    return d.normalized()
func _default(p: Vector3, visible: bool) -> Vector3:
    if visible:
        state = State.CHASE; debug_reason = "chase"
        last_known_player = p; has_player_memory = true; state_timer = 3.0
        var d := p - position; d.y = 0.0; return d.normalized()
    if has_player_memory and state_timer > 0.0:
        state = State.SEARCH; debug_reason = "search"
        var d := last_known_player - position; d.y = 0.0
        if d.length() < 0.35: has_player_memory = false
        return d.normalized()
    state = State.PATROL; debug_reason = "patrol"
    return Vector3.ZERO
func _runner(p: Vector3, visible: bool, _all: Array) -> Vector3:
    if visible and position.distance_to(p) < 6.0:
        state = State.FLEE; debug_reason = "flee"; return _away(p)
    return _default(p, false)
func _thrower(p: Vector3, visible: bool) -> Vector3:
    var d := p - position; d.y = 0.0
    if visible and d.length() > SquirrelTypes.attack_distance_of(kind):
        state = State.CHASE; debug_reason = "throw-approach"; return d.normalized()
    if visible: state = State.CHASE; debug_reason = "throw-stand"
    return Vector3.ZERO if visible else _default(p, false)
