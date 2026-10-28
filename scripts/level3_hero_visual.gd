extends Node2D
class_name Level3HeroVisual
## Original overhead Carolina, animated as an anchored pixel rig. Every painted
## part is immutable; locomotion follows travelled distance and the arms solve
## their real weapon grips instead of swapping unrelated human sprite strips.
const BASE := "res://assets/level3/carolina147/"
const STRIDE := 48.0
const UPPER_LENGTH := 7.0
const FOREARM_LENGTH := 8.0
static var _textures: Dictionary = {}
var parts: Dictionary = {}
var weapon_id: StringName = &"pistol"
var state: StringName = &"idle"
var gait_distance := 0.0
var gait_weight := 0.0
var attack_remaining := 0.0
var attack_duration := .18
var death_clock := -1.0
var muzzle_socket: Marker2D
var weapon_sprite: Sprite2D
var left_grip := Vector2.ZERO
var right_grip := Vector2.ZERO
var left_wrist := Vector2.ZERO
var right_wrist := Vector2.ZERO
var _local_motion := Vector2.RIGHT
var _configured := false

static func texture(part: String) -> Texture2D:
    if not _textures.has(part): _textures[part] = load(BASE + part + ".png") as Texture2D
    return _textures[part]

func _ready() -> void: configure()

func configure() -> void:
    if _configured: return
    _configured = true
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _part("leg_left", 0)
    _part("leg_right", 0).flip_h = true
    _part("torso", 1)
    _part("upper_left", 2)
    _part("upper_right", 2)
    weapon_sprite = _part("cone_pistol", 3)
    weapon_sprite.name = "HeldConeWeapon"
    _part("forearm_left", 4)
    _part("forearm_right", 4)
    _part("head", 5)
    muzzle_socket = Marker2D.new()
    muzzle_socket.name = "MuzzleSocket"
    muzzle_socket.position = Vector2(18,0)
    add_child(muzzle_socket)
    set_weapon(&"pistol")
    _pose()

func _part(key: String, layer: int) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = key.to_pascal_case()
    sprite.texture = texture(key)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.z_index = layer
    add_child(sprite)
    parts[key] = sprite
    return sprite

func set_weapon(value: StringName) -> void:
    if not _configured: configure()
    weapon_id = value
    var part := "baton" if value == &"bat" else ("cone_shotgun" if value == &"shotgun" else "cone_pistol")
    weapon_sprite.texture = texture(part)
    attack_remaining = 0
    _pose()

func attack() -> void:
    if death_clock >= 0: return
    attack_duration = .27 if weapon_id == &"bat" else (.23 if weapon_id == &"shotgun" else .18)
    attack_remaining = attack_duration
    state = &"swing" if weapon_id == &"bat" else &"recoil"
    _pose()

func update_motion(delta: float, local_velocity: Vector2) -> void:
    if delta <= 0: return
    if death_clock >= 0:
        death_clock += delta
        state = &"fall"
        _pose()
        return
    attack_remaining = maxf(0,attack_remaining-delta)
    var moving := local_velocity.length_squared() > 16
    if moving:
        var dominant := local_velocity.x if absf(local_velocity.x)>=absf(local_velocity.y) else local_velocity.y
        var direction := -1.0 if dominant < -.1 else 1.0
        _local_motion = local_velocity.normalized()*direction
        gait_distance = wrapf(gait_distance + local_velocity.length()*delta*direction,0,STRIDE)
    gait_weight = move_toward(gait_weight,1.0 if moving else 0.0,delta*12)
    state = (&"swing" if weapon_id == &"bat" else &"recoil") if attack_remaining > 0 else (&"walk" if moving else &"idle")
    _pose()

func clear_motion() -> void:
    gait_weight = 0
    attack_remaining = 0
    state = &"idle"
    _pose()

func die() -> void:
    death_clock = 0
    attack_remaining = 0
    state = &"fall"
    _pose()

func _pose() -> void:
    if not _configured: return
    var phase := gait_distance / STRIDE * TAU
    var step := sin(phase) * gait_weight
    var torso: Sprite2D = parts.torso
    torso.position = Vector2(-3,0)
    torso.rotation = -PI*.5
    parts.head.position = Vector2(1,0)
    parts.head.rotation = 0
    # Hip seams remain under the body throughout the stride. Both feet move,
    # reverse with backpedalling, and settle when the player releases movement.
    for index in range(2):
        var side := -1.0 if index == 0 else 1.0
        var leg: Sprite2D = parts.leg_left if index == 0 else parts.leg_right
        leg.offset = Vector2(-4.5,0)
        leg.position = (Vector2(-5,side*4.5)+_local_motion*step*side*3.0).round()
        leg.rotation = snappedf(step*side*.12,PI/64.0)
    var progress := 1.0-attack_remaining/maxf(attack_duration,.001)
    var recoil := sin(progress*PI) * (2.0 if weapon_id == &"shotgun" else 1.25) if attack_remaining>0 else 0.0
    weapon_sprite.rotation = 0
    weapon_sprite.position = Vector2(12-recoil,0)
    if weapon_id == &"shotgun": weapon_sprite.position.x = 10-recoil
    elif weapon_id == &"bat":
        weapon_sprite.position = Vector2(10,0)
        if attack_remaining > 0: weapon_sprite.rotation = lerpf(-1.2,1.0,smoothstep(0,1,progress))
    if weapon_id == &"shotgun":
        right_grip = weapon_sprite.position + Vector2(-3,-2)
        left_grip = weapon_sprite.position + Vector2(4,2)
    elif weapon_id == &"bat":
        right_grip = weapon_sprite.position + Vector2(-5,-1).rotated(weapon_sprite.rotation)
        left_grip = weapon_sprite.position + Vector2(-2,1).rotated(weapon_sprite.rotation)
    else:
        right_grip = weapon_sprite.position + Vector2(-3,-2)
        left_grip = weapon_sprite.position + Vector2(-1,2)
    left_wrist = _arm("left",Vector2(1,6),left_grip,1)
    right_wrist = _arm("right",Vector2(1,-6),right_grip,-1)
    if death_clock >= 0:
        var settled := smoothstep(0,.28,death_clock)
        torso.rotation += settled*.30
        parts.head.position += Vector2(-2,2)*settled
        parts.head.rotation = settled*.24
        weapon_sprite.position += Vector2(4,5)*settled

func _arm(side: String, shoulder: Vector2, target: Vector2, bend: float) -> Vector2:
    var delta := target-shoulder
    var distance := clampf(delta.length(),.01,UPPER_LENGTH+FOREARM_LENGTH-.01)
    var angle := delta.angle() + bend*acos(clampf((UPPER_LENGTH*UPPER_LENGTH+distance*distance-FOREARM_LENGTH*FOREARM_LENGTH)/(2*UPPER_LENGTH*distance),-1,1))
    var elbow := shoulder + Vector2.from_angle(angle)*UPPER_LENGTH
    var upper: Sprite2D = parts["upper_"+side]
    var forearm: Sprite2D = parts["forearm_"+side]
    upper.offset = Vector2(3.5,0)
    upper.position = shoulder
    upper.rotation = angle
    forearm.offset = Vector2(5,0)
    forearm.position = elbow
    forearm.rotation = (target-elbow).angle()
    return elbow+Vector2.from_angle(forearm.rotation)*FOREARM_LENGTH

func part_count() -> int: return parts.size()
