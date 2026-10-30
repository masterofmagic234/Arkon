extends Node2D
class_name Level3HeroVisual
## Connected overhead body AND head from the original diner art. The authored
## head silhouette gets restrained dark/red hair, not a pasted portrait crown.
const BASE := "res://assets/level3/carolina147/"
const SOURCE_BASE := "res://assets/level3/characters/player/"
const UNARMED_STRIP := SOURCE_BASE + "sprPWalkUnarmed2_strip8.png"
const ARMED_STRIP := SOURCE_BASE + "sprPWalkM16_strip8.png"
const FALL_STRIP := SOURCE_BASE + "sprPBackBlunt_strip5.png"
const PALETTE := preload("res://shaders/level3/taya152.gdshader")
const STRIDE := 48.0
const WALK_FRAMES := 8
const FALL_FRAMES := 5
const HEAD_BOB := [0,-1,-1,-1,0,1,1,1]
const HAND_TRAVEL := [0,-1,-2,-1,0,1,2,1]
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
var body_sprite: Sprite2D
var pose_root: Node2D
var source_frame := 0
var weapon_drawn := true
var _configured := false
var _palette: ShaderMaterial

static func texture(part: String) -> Texture2D:
    if not _textures.has(part): _textures[part] = load(BASE+part+".png") as Texture2D
    return _textures[part]

func _ready() -> void: configure()

func configure() -> void:
    if _configured: return
    _configured = true
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    pose_root = Node2D.new()
    pose_root.name = "AuthoredOverheadPose"
    add_child(pose_root)
    body_sprite = _part("body",0)
    body_sprite.hframes = WALK_FRAMES
    _palette = ShaderMaterial.new()
    _palette.shader = PALETTE
    _palette.set_shader_parameter("original_overhead_head",true)
    body_sprite.material = _palette
    # Original painted fingers stay over the grip, not under the replacement.
    weapon_sprite = _part("weapon",-1)
    weapon_sprite.name = "HeldConeWeapon"
    muzzle_socket = Marker2D.new()
    muzzle_socket.name = "MuzzleSocket"
    muzzle_socket.position = Vector2(18,0)
    add_child(muzzle_socket)
    set_weapon(&"pistol")

func _part(key: String,layer: int) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = key.to_pascal_case()
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.z_index = layer
    pose_root.add_child(sprite)
    parts[key] = sprite
    return sprite

func set_weapon(value: StringName) -> void:
    if not _configured: configure()
    weapon_id = value
    var part := "baton" if value==&"bat" else ("cone_shotgun" if value==&"shotgun" else "cone_pistol")
    weapon_sprite.texture = texture(part)
    attack_remaining = 0
    _pose()

func attack() -> void:
    if death_clock>=0 or not weapon_drawn: return
    attack_duration = .27 if weapon_id==&"bat" else (.23 if weapon_id==&"shotgun" else .18)
    attack_remaining = attack_duration
    state = &"swing" if weapon_id==&"bat" else &"recoil"
    _pose()

func update_motion(delta: float,local_velocity: Vector2) -> void:
    if delta<=0: return
    if death_clock>=0:
        death_clock += delta
        state = &"fall"
        _pose()
        return
    attack_remaining = maxf(0,attack_remaining-delta)
    var moving := local_velocity.length_squared()>16
    if moving:
        var dominant := local_velocity.x if absf(local_velocity.x)>=absf(local_velocity.y) else local_velocity.y
        var direction := -1.0 if dominant<-.1 else 1.0
        gait_distance = wrapf(gait_distance+local_velocity.length()*delta*direction,0,STRIDE)
    gait_weight = move_toward(gait_weight,1.0 if moving else 0.0,delta*12)
    state = (&"swing" if weapon_id==&"bat" else &"recoil") if attack_remaining>0 else (&"walk" if moving else &"idle")
    _pose()

func clear_motion() -> void:
    gait_weight = 0
    attack_remaining = 0
    state = &"idle"
    _pose()

func set_weapon_drawn(enabled: bool) -> void:
    weapon_drawn = enabled
    attack_remaining = 0
    if death_clock<0: state = &"idle"
    if _configured: _pose()

func die() -> void:
    death_clock = 0
    attack_remaining = 0
    state = &"fall"
    _pose()

func _set_body(armed: bool,falling: bool) -> void:
    var path := FALL_STRIP if falling else (ARMED_STRIP if armed else UNARMED_STRIP)
    if body_sprite.texture==null or body_sprite.texture.resource_path!=path:
        body_sprite.texture = load(path)
        body_sprite.hframes = FALL_FRAMES if falling else WALK_FRAMES
    _palette.set_shader_parameter("horizontal_frames",float(body_sprite.hframes))
    _palette.set_shader_parameter("hide_conventional_rifle",armed and not falling)

func _pose() -> void:
    if not _configured: return
    var falling := death_clock>=0
    _set_body(weapon_drawn,falling)
    pose_root.position = Vector2.ZERO
    pose_root.rotation = 0
    weapon_sprite.rotation = 0
    if falling:
        source_frame = mini(FALL_FRAMES-1,floori(death_clock/.065))
        body_sprite.frame = source_frame
        body_sprite.position = Vector2.ZERO
        # Original floor poses expose the fallen silhouette; no standing
        # trousers or separately rotated limbs project out of a living torso.
        _palette.set_shader_parameter("authored_head_center",Vector2(53.5,[33,30,29,28,29][source_frame]))
        weapon_sprite.visible = false
        return
    source_frame = floori(gait_distance/STRIDE*WALK_FRAMES)%WALK_FRAMES if gait_weight>.01 else 0
    body_sprite.frame = source_frame
    # The two source atlases have different cell widths but their painted crown
    # is at the same player-space point after this authored origin adjustment.
    body_sprite.position = Vector2(2,0)
    _palette.set_shader_parameter("authored_head_center",Vector2(21.5,16+HEAD_BOB[source_frame]) if weapon_drawn else Vector2(15.5,16-HEAD_BOB[source_frame]))
    weapon_sprite.visible = weapon_drawn
    if not weapon_drawn: return
    var progress := 1.0-attack_remaining/maxf(attack_duration,.001)
    var recoil := sin(progress*PI)*(1.75 if weapon_id==&"shotgun" else 1.0) if attack_remaining>0 else 0.0
    pose_root.position.x = -roundf(recoil)
    var hand_travel: int = HAND_TRAVEL[source_frame]
    weapon_sprite.position = Vector2((10 if weapon_id==&"shotgun" else 12)+hand_travel,0)
    if weapon_id==&"bat":
        weapon_sprite.position = Vector2(10+hand_travel,0)
        if attack_remaining>0:
            # Turn the connected shoulder/hand drawing with the baton instead
            # of tearing independent forearms away from their painted sleeves.
            pose_root.rotation = lerpf(-.65,.65,smoothstep(0,1,progress))

func part_count() -> int: return parts.size()
