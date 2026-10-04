extends CharacterBody3D
class_name Level1Enemy

const LevelData = preload("res://scripts/level_data.gd")
const SquirrelTypes = preload("res://scripts/squirrel_types.gd")
const SquirrelAI = preload("res://scripts/squirrel_ai.gd")
const SquirrelQueries = preload("res://scripts/squirrel_queries.gd")
const WorldCollision = preload("res://scripts/world_collision.gd")
const SquirrelAnimator = preload("res://scripts/squirrel_animator.gd")
const Squirrel3DVisual = preload("res://scripts/squirrel_3d_visual.gd")

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
var ground_y: float = 0.0

func _ready() -> void:
    ground_y = global_position.y
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

    navigation_agent.radius = 0.30
    navigation_agent.height = 1.0
    navigation_agent.path_desired_distance = 0.25
    navigation_agent.target_desired_distance = 0.35
    navigation_agent.max_speed = 3.8
    navigation_agent.avoidance_enabled = false

    _setup_visual()

    if not SignalBus.entity_stunned.is_connected(_on_entity_stunned):
        SignalBus.entity_stunned.connect(_on_entity_stunned)

func _exit_tree() -> void:
    if SignalBus.entity_stunned.is_connected(_on_entity_stunned):
        SignalBus.entity_stunned.disconnect(_on_entity_stunned)

func _setup_visual() -> void:
    if squirrel_kind == SquirrelTypes.Kind.SCOUT:
        visual.visible = false
        squirrel_3d_visual.position.y = -position.y + Squirrel3DVisual.GROUND_CLEARANCE
        squirrel_3d_visual.setup()
        squirrel_3d_visual.apply_active()
        return

    visual.position.y = BILLBOARD_GROUND_CLEARANCE

    var material := visual.mesh.surface_get_material(0) as StandardMaterial3D if visual.mesh != null else null
    if material == null:
        return

    var unique := material.duplicate() as StandardMaterial3D
    unique.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    unique.cull_mode = BaseMaterial3D.CULL_DISABLED
    unique.albedo_texture = NORMAL_TEXTURES.get(
        squirrel_kind,
        NORMAL_TEXTURES[SquirrelTypes.Kind.SCOUT]
    )
    unique.emission_enabled = true
    unique.emission_texture = unique.albedo_texture
    unique.emission = Color(0.72, 0.78, 0.92, 1.0)
    unique.emission_energy_multiplier = 0.35
    visual.set_surface_override_material(0, unique)

func _physics_process(delta: float) -> void:
    animation_clock += delta

    var player := get_tree().get_first_node_in_group("level1_player") as Level1Player
    if ai == null or defeated:
        _animate_visual(delta, Vector3.ZERO, 0.0)
        return

    if player == null or player.get_hp() <= 0:
        _animate_visual(delta, Vector3.ZERO, 0.0)
        return

    ai.position = global_position
    think_timer += delta

    if think_timer >= 0.10:
        var think_delta := think_timer
        think_timer = 0.0

        var player_pos := player.global_position
        var visible_to_player := SquirrelQueries.visible_from(
            global_position + Vector3.UP * 0.2,
            player_pos + Vector3.UP * 0.2,
            get_world_3d(),
            LevelData.WORLD_LAYER
        )
        var nearby := _nearby_squirrels(4.0)

        desired_dir = ai.desired_direction(
            player_pos,
            visible_to_player,
            nearby,
            [],
            think_delta
        )

        if desired_dir.length_squared() > 0.01:
            navigation_agent.target_position = global_position + desired_dir.normalized() * 4.5
            if not navigation_agent.is_navigation_finished():
                var next_path_position := navigation_agent.get_next_path_position()
                var nav_dir := global_position.direction_to(next_path_position)
                nav_dir.y = 0.0
                if nav_dir.length_squared() > 0.01:
                    desired_dir = nav_dir

    desired_dir.y = 0.0

    if desired_dir.length_squared() > 0.01:
        var proposed := global_position + desired_dir.normalized() * ai.speed * delta
        var proposed_flat := Vector2(proposed.x, proposed.z)
        var player_flat := Vector2(player.global_position.x, player.global_position.z)
        var min_distance := 0.0 if ai.is_thief_or_runner() else 1.35

        if (
            proposed_flat.distance_to(player_flat) >= min_distance
            and not WorldCollision.is_wall(
                proposed.x,
                proposed.z
            )
        ):
            proposed.y = ground_y
            global_position = proposed
            ai.position = global_position

    # Navigation is generated on the world floor (Y=0), while the enemy actors
    # are intentionally elevated to the authored gameplay height. Keep that
    # presentation/gameplay invariant absolute even if another system writes Y.
    if not is_equal_approx(global_position.y, ground_y):
        global_position.y = ground_y
        ai.position = global_position

    var dist := global_position.distance_to(player.global_position)
    var in_view := dist <= 12.0
    visual.visible = in_view and squirrel_kind != SquirrelTypes.Kind.SCOUT
    squirrel_3d_visual.visible = in_view and squirrel_kind == SquirrelTypes.Kind.SCOUT

    if in_view:
        _animate_visual(
            delta,
            desired_dir,
            ai.speed
        )

    if ai.can_attack(dist):
        ai.mark_attacked(0.8)
        if player.take_damage(SquirrelTypes.damage_of(squirrel_kind), self):
            SignalBus.emit_audio_event(
                &"damage",
                Vector3(global_position.x, global_position.y, global_position.z)
            )
            SignalBus.show_message.emit(
                LevelData.DAMAGE_LINES.pick_random(),
                1.2
            )

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

    if health.current_health > 0:
        if squirrel_kind == SquirrelTypes.Kind.SCOUT:
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

        SignalBus.emit_audio_event(
            &"squirrel_hit",
            Vector3(global_position.x, global_position.y, global_position.z)
        )
        SignalBus.show_message.emit(
            LevelData.HIT_LINES.pick_random()
                + "\nЕщё один раз — и белка отдыхает.",
            1.4
        )

    return true

func _on_health_died() -> void:
    if defeated:
        return

    defeated = true
    ai.hp = 0
    ai.stun(3.0)

    hitbox.set_deferred("monitoring", false)
    hitbox.set_deferred("monitorable", false)
    body_collision.set_deferred("disabled", true)

    if squirrel_kind == SquirrelTypes.Kind.SCOUT:
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

    SignalBus.entity_stunned.emit(self, 3.0)
    SignalBus.enemy_defeated.emit(self)
    SignalBus.emit_audio_event(
        &"squirrel_hit",
        Vector3(global_position.x, global_position.y, global_position.z)
    )
    SignalBus.show_message.emit(
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
    if squirrel_kind == SquirrelTypes.Kind.SCOUT:
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
