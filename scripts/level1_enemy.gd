extends CharacterBody3D
class_name Level1Enemy

const LevelData = preload("res://scripts/level_data.gd")
const SquirrelTypes = preload("res://scripts/squirrel_types.gd")
const SquirrelAI = preload("res://scripts/squirrel_ai.gd")
const SquirrelQueries = preload("res://scripts/squirrel_queries.gd")
const WorldCollision = preload("res://scripts/world_collision.gd")
const SquirrelAnimator = preload("res://scripts/squirrel_animator.gd")
const Squirrel3DVisual = preload("res://scripts/squirrel_3d_visual.gd")
const ThrownCone = preload("res://scripts/level1_thrown_cone.gd")

const BILLBOARD_GROUND_CLEARANCE: float = 0.0
const HealthComponent = preload("res://scripts/components/health_component.gd")
const Hitbox3DComponent = preload("res://scripts/components/hitbox_3d_component.gd")

const NORMAL_TEXTURES := {
    SquirrelTypes.Kind.SCOUT: preload("res://squirrel_scout_1.png"),
    SquirrelTypes.Kind.THROWER: preload("res://squirrel_thrower_1.png"),
    SquirrelTypes.Kind.TANK: preload("res://squirrel_tank_1.png"),
    SquirrelTypes.Kind.THIEF: preload("res://squirrel_thief_1.png"),
    SquirrelTypes.Kind.RUNNER: preload("res://squirrel_runner_1.png"),
}

@export var squirrel_kind: int = SquirrelTypes.Kind.SCOUT

@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var hitbox: Hitbox3DComponent = $Hitbox
@onready var health: HealthComponent = $Health
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: MeshInstance3D = $Visual
@onready var squirrel_3d_visual: Squirrel3DVisual = $Squirrel3DVisual

var ai: SquirrelAI
var desired_dir := Vector3.ZERO
var think_timer := 0.0
var animation_clock := 0.0
var defeated := false
var player_visible := false
var ground_y: float = 0.0
var _signal_bus: Node = null
var attack_windup := 0.0
var attack_target := Vector3.ZERO
var warning_ring: MeshInstance3D
var carried_acorn: Node3D
var carry_time := 0.0
var runner_started := false

func _ready() -> void:
    ground_y = global_position.y
    _signal_bus = get_node_or_null("/root/SignalBus")
    add_to_group("level1_enemy")

    health.reset(SquirrelTypes.hp_of(squirrel_kind))
    health.died.connect(_on_health_died)

    # The hitbox is queried directly by the player's hitscan weapon, so it must
    # always remain a live, monitorable collision object even though it does not
    # need overlap monitoring.
    if hitbox != null:
        hitbox.monitorable = true
        hitbox.monitoring = false
        var hit_collider := hitbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if hit_collider != null:
            hit_collider.disabled = false

    ai = SquirrelAI.new()
    ai.setup(
        name,
        squirrel_kind,
        global_position,
        [global_position]
    )
    ai.hp = health.current_health
    var routes := {
        0: [Vector2i(12,27),Vector2i(14,25),Vector2i(10,26)],
        2: [Vector2i(19,24),Vector2i(20,25),Vector2i(20,23)],
        1: [Vector2i(15,8),Vector2i(16,7),Vector2i(16,5)],
        3: [Vector2i(35,10),Vector2i(37,12),Vector2i(44,12)],
        4: [Vector2i(34,24),Vector2i(40,24),Vector2i(42,26),Vector2i(40,29),Vector2i(35,29),Vector2i(34,26)],
    }
    ai.patrol_points.clear()
    for cell in routes.get(squirrel_kind,[]):
        ai.patrol_points.append(LevelData.cell_center_world(cell)+Vector3.UP*ground_y)
    ai.nest = LevelData.cell_center_world(Vector2i(44,12))+Vector3.UP*ground_y
    collision_mask = LevelData.WORLD_LAYER
    body_collision.disabled = false
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.75
    body_collision.shape = capsule

    navigation_agent.radius = 0.30
    navigation_agent.height = 1.0
    # The mesh lies on the ground; the CharacterBody origin is at its waist.
    # Waypoint reach checks must use that same height or the first waypoint
    # remains below the actor forever.
    navigation_agent.path_height_offset = -ground_y
    navigation_agent.path_desired_distance = 0.25
    navigation_agent.target_desired_distance = 0.35
    navigation_agent.max_speed = 3.8
    navigation_agent.avoidance_enabled = false

    _setup_visual()
    _setup_warning()

    if _signal_bus != null and not _signal_bus.is_connected(&"entity_stunned", Callable(self, "_on_entity_stunned")):
        _signal_bus.connect(&"entity_stunned", Callable(self, "_on_entity_stunned"))

func _exit_tree() -> void:
    if _signal_bus != null:
        var stun_callback := Callable(self, "_on_entity_stunned")
        if _signal_bus.is_connected(&"entity_stunned", stun_callback):
            _signal_bus.disconnect(&"entity_stunned", stun_callback)

func _setup_visual() -> void:
    visual.visible = false
    squirrel_3d_visual.position.y = -position.y
    squirrel_3d_visual.setup()
    squirrel_3d_visual.apply_active()
    var scales := [0.88,0.88,1.12,0.83,0.80]
    squirrel_3d_visual.scale = Vector3.ONE*scales[squirrel_kind]
    # Shared rig, readable silhouettes: tank's armour, thief's satchel, runner's
    # blue scarf. These parts live under the turning visual wrapper.
    var accessory := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.55,0.45,0.20)
    accessory.mesh = box
    var material := StandardMaterial3D.new()
    material.albedo_color = [Color(0.28,0.48,0.26),Color(0.61,0.26,0.12),Color(0.30,0.39,0.46),Color(0.34,0.18,0.12),Color(0.16,0.48,0.73)][squirrel_kind]
    material.roughness = 0.9
    accessory.material_override = material
    accessory.position = Vector3(0,1.02,-0.38)
    if squirrel_kind == SquirrelTypes.Kind.TANK: accessory.scale = Vector3(1.7,1.5,1.4)
    if squirrel_kind == SquirrelTypes.Kind.RUNNER: accessory.scale = Vector3(1.4,0.25,1.2)
    squirrel_3d_visual.add_child(accessory)

func _setup_warning() -> void:
    warning_ring = MeshInstance3D.new()
    var ring := TorusMesh.new()
    ring.inner_radius = 0.68
    ring.outer_radius = 0.76
    ring.rings = 24
    ring.ring_segments = 6
    warning_ring.mesh = ring
    warning_ring.position.y = -ground_y+0.045
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(1.0,0.30,0.07)
    material.emission_enabled = true
    material.emission = Color(1.0,0.3,0.07)
    material.emission_energy_multiplier = 1.2
    warning_ring.material_override = material
    warning_ring.visible = false
    add_child(warning_ring)

func _physics_process(delta: float) -> void:
    animation_clock += delta
    var player := get_tree().get_first_node_in_group("level1_player") as Level1Player
    if player == null or ai == null: return
    var dist := global_position.distance_to(player.global_position)
    squirrel_3d_visual.visible = dist < 65.0
    if defeated or player.get_hp() <= 0:
        _animate_visual(delta,Vector3.ZERO,0.0)
        return
    _update_carried(delta,player)
    ai.position = global_position
    think_timer += delta
    if think_timer >= 0.10:
        var dt := think_timer
        think_timer = 0.0
        var awareness := 12.0 if squirrel_kind == SquirrelTypes.Kind.THROWER else 8.0
        player_visible = dist < awareness and SquirrelQueries.visible_from(
            global_position+Vector3.UP*0.4, player.global_position+Vector3.UP*0.4,
            get_world_3d(),LevelData.WORLD_LAYER)
        var acorns: Array = []
        if squirrel_kind == SquirrelTypes.Kind.THIEF and not is_instance_valid(carried_acorn):
            for node in get_tree().get_nodes_in_group("level1_acorn"):
                if not node.collected and not node.has_meta("carried") and global_position.distance_to(node.global_position)<12.0:
                    acorns.append(node.global_position)
        desired_dir = ai.desired_direction(player.global_position,player_visible,_nearby_squirrels(4.0),acorns,dt)
        if desired_dir.length_squared()>0.01:
            navigation_agent.target_position = Vector3(ai.goal.x,0,ai.goal.z)
    var direction := Vector3.ZERO
    if desired_dir.length_squared()>0.01 and attack_windup<=0.0:
        var map := navigation_agent.get_navigation_map()
        if NavigationServer3D.map_get_iteration_id(map)>0 and not navigation_agent.is_navigation_finished():
            var next := navigation_agent.get_next_path_position()
            direction = Vector3(next.x-global_position.x,0,next.z-global_position.z).normalized()
    var min_distance := 0.0 if ai.is_thief_or_runner() else 1.1
    if dist<min_distance: direction = Vector3.ZERO
    velocity = direction*ai.speed
    move_and_slide()
    var locked := global_position
    locked.y = ground_y
    global_position = locked
    ai.position = global_position
    _animate_visual(delta,direction,velocity.length())
    if attack_windup>0.0:
        attack_windup -= delta
        warning_ring.scale = Vector3.ONE*(1.0+sin(animation_clock*18.0)*0.10)
        if attack_windup<=0.0:
            warning_ring.visible = false
            if squirrel_kind == SquirrelTypes.Kind.THROWER:
                var cone := ThrownCone.new()
                get_parent().add_child(cone)
                cone.launch(global_position+Vector3.UP*0.4,attack_target,self)
                SignalBus.emit_audio_event(&"cone_throw",global_position)
            elif player_visible and global_position.distance_to(player.global_position)<2.0:
                if player.take_damage(SquirrelTypes.damage_of(squirrel_kind),self):
                    SignalBus.emit_audio_event(&"damage",global_position)
    elif player_visible and ai.can_attack(dist):
        attack_windup = 0.80 if squirrel_kind == SquirrelTypes.Kind.THROWER else 0.55
        attack_target = player.global_position+Vector3.UP*0.35
        ai.mark_attacked(2.4 if squirrel_kind == SquirrelTypes.Kind.THROWER else 1.7)
        warning_ring.visible = true
        SignalBus.emit_audio_event(&"squirrel_warn",global_position)

func _update_carried(delta: float, player: Level1Player) -> void:
    if is_instance_valid(carried_acorn):
        carry_time += delta
        if carry_time > (16.0 if squirrel_kind == SquirrelTypes.Kind.RUNNER else 9.0):
            _drop_acorn()
        return
    var take := squirrel_kind == SquirrelTypes.Kind.THIEF
    if squirrel_kind == SquirrelTypes.Kind.RUNNER and not runner_started and global_position.distance_to(player.global_position)<8.0:
        runner_started = true
        var final_acorn := get_parent().get_node_or_null("Acorn06") as Node3D
        if final_acorn and not final_acorn.collected:
            _carry_acorn(final_acorn)
            SignalBus.show_message.emit("Гонец схватил последний жёлудь! Перехвати его у дуба.",3.2)
        return
    if not take: return
    for node in get_tree().get_nodes_in_group("level1_acorn"):
        if not node.collected and not node.has_meta("carried") and global_position.distance_to(node.global_position)<1.2:
            _carry_acorn(node)
            SignalBus.show_message.emit("Вор уносит жёлудь. Оглуши его — добыча выпадет.",2.6)
            return

func _carry_acorn(node: Node3D) -> void:
    carried_acorn = node
    carry_time = 0.0
    ai.carried = true
    node.set_meta("carried",true)
    node.set_deferred("monitoring",false)
    node.reparent(self)
    node.position = Vector3(0.55,0.40,0)

func _drop_acorn() -> void:
    if not is_instance_valid(carried_acorn):
        ai.carried = false
        return
    var node := carried_acorn
    node.reparent(get_parent())
    node.global_position = Vector3(global_position.x,0.6,global_position.z)
    node.remove_meta("carried")
    node.set_deferred("monitoring",true)
    carried_acorn = null
    ai.carried = false
    SignalBus.emit_audio_event(&"pickup",global_position)

func _nearby_squirrels(radius: float) -> Array:
    var out: Array = []

    for node in get_tree().get_nodes_in_group("level1_enemy"):
        var other := node as Level1Enemy
        if other == null or other == self or other.defeated or other.ai == null:
            continue

        if global_position.distance_to(other.global_position) <= radius:
            other.ai.position = other.global_position
            out.append(other.ai)

    return out

func take_damage(amount: int, source: Node = null) -> bool:
    if defeated or health == null:
        return false

    var applied := health.apply_damage(amount, source)
    if not applied:
        return false

    ai.hp = health.current_health
    attack_windup = 0.0
    warning_ring.visible = false

    if health.current_health > 0:
        if squirrel_3d_visual.presentation_ready:
            squirrel_3d_visual.apply_hit()
        else:
            SquirrelAnimator.apply(
                visual,
                animation_clock,
                0,
                ai.speed,
                Vector3.ZERO,
                0.0
            )

        if _signal_bus != null:
            _signal_bus.call(
                "emit_audio_event",
                &"squirrel_hit",
                Vector3(global_position.x, global_position.y, global_position.z)
            )
            _signal_bus.emit_signal(
                &"show_message",
                LevelData.HIT_LINES.pick_random()
                    + "\nДо оглушения: %d." % health.current_health,
                1.4
            )

    return true

func _on_health_died() -> void:
    if defeated:
        return

    _drop_acorn()
    attack_windup = 0.0
    warning_ring.visible = false
    defeated = true
    ai.hp = 0
    ai.stun(3.0)

    # Remove the defeated enemy from hitscan/physics immediately. Deferred
    # updates are kept as a safety net for the physics server.
    hitbox.monitoring = false
    hitbox.monitorable = false
    hitbox.collision_layer = 0
    var hit_collider := hitbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if hit_collider != null:
        hit_collider.set_deferred("disabled", true)
    hitbox.set_deferred("monitorable", false)
    body_collision.set_deferred("disabled", true)

    if squirrel_3d_visual.presentation_ready:
        squirrel_3d_visual.apply_stunned()
    else:
        SquirrelAnimator.apply(
            visual,
            animation_clock,
            SquirrelAI.State.STUNNED,
            0.0,
            Vector3.ZERO,
            0.0
        )

    if _signal_bus != null:
        _signal_bus.emit_signal(&"entity_stunned", self, 3.0)
        _signal_bus.emit_signal(&"enemy_defeated", self)
        _signal_bus.call(
            "emit_audio_event",
            &"squirrel_hit",
            Vector3(global_position.x, global_position.y, global_position.z)
        )
        _signal_bus.emit_signal(
            &"show_message",
            LevelData.STUN_LINES.pick_random(),
            2.0
        )

func _on_entity_stunned(entity: Node, duration: float) -> void:
    if entity == self or defeated or ai == null:
        return

    var source := entity as Level1Enemy
    if source == null or source.ai == null:
        return

    var radius := SquirrelTypes.panic_radius_of(source.squirrel_kind)
    if radius <= 0.0:
        return

    if global_position.distance_to(source.global_position) <= radius:
        ai.panic(duration)

func _animate_visual(delta: float, direction: Vector3, speed: float) -> void:
    if squirrel_3d_visual.presentation_ready:
        squirrel_3d_visual.animate_squirrel(
            fmod(animation_clock, TAU),
            SquirrelAI.State.STUNNED if defeated else ai.state,
            0.0 if defeated else speed,
            Vector3.ZERO if defeated else direction,
            delta
        )
    elif visual.visible:
        SquirrelAnimator.apply(
            visual,
            fmod(animation_clock, TAU),
            SquirrelAI.State.STUNNED if defeated else ai.state,
            0.0 if defeated else speed,
            direction,
            delta
        )
