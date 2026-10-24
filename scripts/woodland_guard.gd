extends CharacterBody3D
# The woodland encounter owns its own patrol/charge state machine. The shared
# player still shoots the real Hitbox3DComponent, so visual changes never turn
# an enemy into a target that cannot be hit.
const Health = preload("res://scripts/components/health_component.gd")
const Hitbox = preload("res://scripts/components/hitbox_3d_component.gd")
const Visual = preload("res://scripts/squirrel_3d_visual.gd")
const Queries = preload("res://scripts/squirrel_queries.gd")

var director: Node
var is_tank := false
var final_boss := false
var _restoring := false
var stealth_patrol := false
var hearing_distance := 18.0
var _attack_count := 0
var _shock_hit := false
var patrol_points: Array[Vector3] = []
var spawn_position := Vector3.ZERO
var defeated := false
var state := "patrol"
var hp: int:
    get: return health.current_health if health != null else 0
var max_hp: int:
    get: return health.max_health if health != null else ((12 if final_boss else 8) if is_tank else 3)
var health: HealthComponent
var hitbox: Hitbox3DComponent
var visual: Squirrel3DVisual
var body_shape: CollisionShape3D
var warning_ring: MeshInstance3D
var charge_line: MeshInstance3D
var _warning_material: StandardMaterial3D
var _line_material: StandardMaterial3D
var _timer := 0.0
var _clock := 0.0
var _patrol_index := 0
var _last_seen := Vector3.ZERO
var _memory := 0.0
var _charge_direction := Vector3.FORWARD
var _charge_hit := false
var _blocked_message_timer := 0.0
var _defeat_clock := 0.0
var _stuck_clock := 0.0
var _avoid_sign := 1.0

func _ready() -> void:
    add_to_group("level1_enemy")
    add_to_group("woodland_guard")
    spawn_position = global_position
    # Actor bodies live on their own layer. The hitscan mask includes layer2;
    # only the larger hitbox uses it, never the opaque physics capsule.
    collision_layer = 8
    collision_mask = 1 | 8 | 4
    motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    body_shape = CollisionShape3D.new()
    body_shape.name = "CollisionShape3D"
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.58 if is_tank else 0.36
    capsule.height = 2.05 if is_tank else 1.45
    body_shape.shape = capsule
    body_shape.position.y = capsule.height * 0.5
    add_child(body_shape)
    health = Health.new()
    health.name = "Health"
    health.max_health = (12 if final_boss else 8) if is_tank else 3
    health.invulnerability_duration = 0.14
    add_child(health)
    health.died.connect(_on_defeated)
    hitbox = Hitbox.new()
    hitbox.name = "Hitbox"
    var hit_shape := CollisionShape3D.new()
    hit_shape.name = "CollisionShape3D"
    var box := BoxShape3D.new()
    box.size = Vector3(1.55, 2.45, 1.45) if is_tank else Vector3(1.1, 1.85, 1.0)
    hit_shape.shape = box
    hit_shape.position.y = box.size.y * 0.5
    hitbox.add_child(hit_shape)
    add_child(hitbox)
    visual = Visual.new()
    visual.name = "Squirrel3DVisual"
    if is_tank:
        visual.model_path = "res://assets/level1/characters/tank_squirrel.glb"
    visual.target_height = 2.4 if is_tank else 1.6
    add_child(visual)
    visual.setup()
    visual.apply_active()
    _make_telegraph()
    if patrol_points.is_empty():
        patrol_points.assign([spawn_position + Vector3(-2,0,0), spawn_position + Vector3(2,0,0)])
    _last_seen = spawn_position
    state = "dormant" if is_tank else "patrol"

func _make_telegraph() -> void:
    warning_ring = MeshInstance3D.new()
    warning_ring.name = "AttackTell"
    var ring := TorusMesh.new()
    ring.inner_radius = 1.15 if is_tank else 0.68
    ring.outer_radius = 1.25 if is_tank else 0.75
    ring.rings = 24
    ring.ring_segments = 5
    warning_ring.mesh = ring
    warning_ring.position.y = 0.035
    _warning_material = StandardMaterial3D.new()
    _warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _warning_material.albedo_color = Color("edb06c")
    warning_ring.material_override = _warning_material
    warning_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    warning_ring.visible = false
    add_child(warning_ring)
    charge_line = MeshInstance3D.new()
    charge_line.name = "ChargeDirection"
    var line := BoxMesh.new()
    line.size = Vector3(0.14, 0.022, 9.5)
    charge_line.mesh = line
    _line_material = StandardMaterial3D.new()
    _line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _line_material.albedo_color = Color("edb06c")
    charge_line.material_override = _line_material
    charge_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    charge_line.visible = false
    add_child(charge_line)

func _physics_process(delta: float) -> void:
    _clock += delta
    _timer = maxf(0.0, _timer - delta)
    _memory = maxf(0.0, _memory - delta)
    _blocked_message_timer = maxf(0.0, _blocked_message_timer - delta)
    if defeated:
        _defeat_clock += delta
        _animate(delta)
        # A resting defeated squirrel remains visible instead of vanishing.
        if visual != null:
            visual.rotation.z = lerpf(visual.rotation.z, -0.82, minf(delta * 3.0, 1.0))
        return
    var player := _player()
    if player == null or not player.input_enabled or player.get_hp() <= 0:
        velocity = Vector3.ZERO
        _animate(delta)
        return
    if is_tank:
        _update_tank(delta, player)
    else:
        _update_scout(delta, player)
    position.y = 0.0
    _animate(delta)

func _player() -> Level1Player:
    if not is_instance_valid(director): return null
    return director.player as Level1Player

func _flat_distance(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x-b.x, a.z-b.z).length()

func _can_see(player: Level1Player, distance_limit: float) -> bool:
    if _flat_distance(global_position, player.global_position) > distance_limit: return false
    if stealth_patrol and state not in ["chase","melee"] and velocity.length_squared()>.1:
        var towards=player.global_position-global_position;towards.y=0
        if towards.length()>2 and velocity.normalized().dot(towards.normalized())<.2:return false
    return Queries.visible_from(global_position + Vector3.UP * 1.1, player.global_position + Vector3.UP * 0.3, get_world_3d(), 1)

func _update_scout(delta: float, player: Level1Player) -> void:
    if state == "melee":
        velocity = Vector3.ZERO
        if _timer <= 0.0:
            if _flat_distance(global_position, player.global_position) < 2.05 and _can_see(player, 2.1):
                player.take_damage(12, self)
            state = "recover"
            _timer = 0.8
            warning_ring.visible = false
        return
    if state == "recover":
        velocity = Vector3.ZERO
        if _timer <= 0.0: state = "patrol"
        return
    var sight := 7.0 if player.quiet_mode else 14.0
    if _can_see(player, sight):
        _last_seen = player.global_position
        _last_seen.y = 0.0
        _memory = 4.0
        state = "chase"
        if _flat_distance(global_position, player.global_position) < 1.65:
            velocity = Vector3.ZERO
            state = "melee"
            _timer = 0.65
            warning_ring.visible = true
            SignalBus.emit_audio_event(&"squirrel_warn", global_position)
            return
    var target: Vector3
    if _memory > 0.0:
        target = _last_seen
        if state != "chase": state = "investigate"
    else:
        state = "patrol"
        target = patrol_points[_patrol_index]
        if _flat_distance(global_position, target) < 0.7:
            _patrol_index = (_patrol_index + 1) % patrol_points.size()
            target = patrol_points[_patrol_index]
    _walk_towards(target, 2.55 if state == "chase" else 1.15, delta)

func _update_tank(delta: float, player: Level1Player) -> void:
    if state=="stomp_windup":
        velocity=Vector3.ZERO;warning_ring.scale=Vector3.ONE*6.5
        if _timer<=0:
            state="shockwave";_timer=.65;_shock_hit=false
        return
    if state=="shockwave":
        var radius=1.0+(1.0-_timer/.65)*7.0
        warning_ring.scale=Vector3.ONE*radius/1.25
        if not _shock_hit and absf(_flat_distance(global_position,player.global_position)-radius)<.9 and player.dash_time<=0:
            player.take_damage(20,self);_shock_hit=true
        if _timer<=0:_begin_recovery()
        return
    if state == "dormant":
        velocity = Vector3.ZERO
        if str(director.stage) == "cache":
            state = "stalk"
            _timer = 0.6
        return
    if state == "windup":
        velocity = Vector3.ZERO
        var pulse := 1.0 + sin(_clock * 19.0) * 0.08
        warning_ring.scale = Vector3(pulse,1,pulse)
        if _timer <= 0.0:
            state = "charge"
            _timer = 1.05
            _charge_hit = false
            charge_line.visible = false
            _warning_material.albedo_color = Color("e58163")
        return
    if state == "charge":
        velocity = _charge_direction * 10.0
        move_and_slide()
        if not _charge_hit and _flat_distance(global_position, player.global_position) < 1.8:
            player.take_damage(24, self)
            _charge_hit = true
        if _timer <= 0.0 or _hit_charge_obstacle() or global_position.distance_to(spawn_position) > 15.0:
            _begin_recovery()
        return
    if state == "recover":
        velocity = Vector3.ZERO
        if _timer <= 0.0:
            warning_ring.visible = false
            state = "stalk"
            _timer = 0.55
        return
    # The tank stays near the oak; it cannot chase the player all the way to
    # the car or trap them while they are learning the three lantern routes.
    if global_position.distance_to(spawn_position) > 11.5:
        _walk_towards(spawn_position, 2.0, delta)
        return
    var distance := _flat_distance(global_position, player.global_position)
    if _timer <= 0.0 and _can_see(player, 15.0):
        if distance < 11.0:
            if final_boss and hp<=6 and _attack_count%2==1:
                state="stomp_windup";_timer=1.35;warning_ring.visible=true;charge_line.visible=false;_attack_count+=1
                _warning_material.albedo_color=Color("dfb561")
                SignalBus.show_message.emit("Удар по земле! Отойди от круга или проскочи рывком.",2)
                SignalBus.emit_audio_event(&"squirrel_warn",global_position)
            else:_start_charge(player.global_position)
        else:
            _walk_towards(player.global_position, 1.65, delta)
    else:
        velocity = Vector3.ZERO

func _start_charge(target: Vector3) -> void:
    _charge_direction = (target - global_position)
    _charge_direction.y = 0.0
    if _charge_direction.length_squared() < 0.01: _charge_direction = Vector3.FORWARD
    _charge_direction = _charge_direction.normalized()
    state = "windup"
    _attack_count+=1
    _timer = 0.9
    warning_ring.visible = true
    warning_ring.scale = Vector3.ONE
    _warning_material.albedo_color = Color("edb06c")
    charge_line.position = _charge_direction * 4.75 + Vector3.UP * 0.055
    charge_line.rotation.y = atan2(_charge_direction.x, _charge_direction.z)
    charge_line.visible = true
    SignalBus.emit_audio_event(&"squirrel_warn", global_position)
    if visual != null:
        visual.animate_squirrel(0,0,0,_charge_direction,0)

func _hit_charge_obstacle() -> bool:
    # A capsule standing on the physical floor can report its floor contact
    # during recovery. Only a horizontal blocker ends a horizontal charge.
    for i in range(get_slide_collision_count()):
        var normal := get_slide_collision(i).get_normal()
        if absf(normal.y) < 0.65:
            return true
    return false

func _begin_recovery() -> void:
    velocity = Vector3.ZERO
    state = "recover"
    _timer = 1.8
    warning_ring.visible = true
    warning_ring.scale = Vector3.ONE
    _warning_material.albedo_color = Color("a4cda4")
    charge_line.visible = false
    SignalBus.show_message.emit("Танк выдохся. Сейчас можно стрелять!", 1.8)

func _walk_towards(target: Vector3, speed: float, delta: float) -> void:
    var direction := target-global_position
    direction.y = 0.0
    if direction.length_squared() < 0.25:
        velocity = Vector3.ZERO
        return
    direction = direction.normalized()
    # A short three-ray feeler handles the forest's rocks and lodge without
    # creating a second navigation mesh or navigating through physical walls.
    var forward := global_position + Vector3.UP * 0.65
    var query := PhysicsRayQueryParameters3D.create(forward, forward + direction * 1.25, 1)
    if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
        var left := direction.rotated(Vector3.UP, _avoid_sign * 0.95)
        query.to = forward + left * 1.4
        if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
            _avoid_sign *= -1.0
            left = direction.rotated(Vector3.UP, _avoid_sign * 1.3)
        direction = left
    var before := global_position
    velocity = direction * speed
    move_and_slide()
    if global_position.distance_to(before) < speed * delta * 0.15:
        _stuck_clock += delta
        if _stuck_clock > 0.5:
            _avoid_sign *= -1.0
            _stuck_clock = 0.0
    else: _stuck_clock = 0.0
    # All terrain is on y0, including paths. Never accumulate drift from wall
    # slide normals, and never teleport horizontally through obstacles.
    position.y = 0.0

func investigate(world_position: Vector3) -> void:
    if defeated or is_tank or state == "melee" or state == "recover": return
    if _flat_distance(global_position, world_position) > hearing_distance: return
    _last_seen = Vector3(world_position.x,0,world_position.z)
    _memory = 5.0
    state = "investigate"

func take_damage(amount: int, source: Node = null) -> bool:
    if defeated or health == null: return false
    if is_tank and state != "recover":
        if _blocked_message_timer <= 0.0:
            # The player reports a rejected hit after this call. Explain the
            # armour after that generic miss feedback so the useful instruction
            # remains on screen.
            call_deferred("_explain_armour")
            _blocked_message_timer = 2.0
        return false
    var applied := health.apply_damage(amount, source)
    if applied and not defeated:
        visual.apply_hit()
        if source is Node3D and not is_tank: investigate(source.global_position)
        SignalBus.emit_audio_event(&"squirrel_hit", global_position)
    return applied

func _explain_armour() -> void:
    if is_inside_tree() and not defeated:
        SignalBus.show_message.emit("Уклонитесь от рывка. Стреляйте, когда танк выдохнется.", 2.0)

func _on_defeated() -> void:
    if defeated: return
    defeated = true
    state = "defeated"
    velocity = Vector3.ZERO
    warning_ring.visible = false
    charge_line.visible = false
    hitbox.collision_layer = 0
    hitbox.set_deferred("monitorable", false)
    body_shape.set_deferred("disabled", true)
    hitbox.get_node("CollisionShape3D").set_deferred("disabled", true)
    visual.apply_stunned()
    if not _restoring:SignalBus.emit_audio_event(&"squirrel_hit", global_position)

func restore_defeated() -> void:
    _restoring=true;health.force_kill();_restoring=false

func _animate(delta: float) -> void:
    if visual == null: return
    var direction := velocity.normalized() if velocity.length_squared() > 0.01 else Vector3.ZERO
    if state == "windup": direction = _charge_direction
    visual.animate_squirrel(_clock,0,velocity.length(),direction,delta)
    if visual.model_instance != null and not defeated:
        visual.model_instance.rotation.x = visual.base_model_rotation.x
        if state == "windup": visual.model_instance.rotation.x += 0.12
        elif state == "recover": visual.model_instance.rotation.x += 0.06 * sin(_clock * 6.0)
