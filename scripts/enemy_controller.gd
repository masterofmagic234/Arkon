extends RefCounted

# Enemy-side controller. Owns squirrel AI, damage, stun state and defeat checks.
# Archetype behavior lives in squirrel_ai.gd; this controller owns integration.
const LevelData = preload("res://scripts/level_data.gd")
const WorldCollision = preload("res://scripts/world_collision.gd")
const HealthMath = preload("res://scripts/health_math.gd")
const DeathQuery = preload("res://scripts/death_query.gd")
const SceneLookup = preload("res://scripts/scene_lookup.gd")
const SquirrelAI = preload("res://scripts/squirrel_ai.gd")
const SquirrelTypes = preload("res://scripts/squirrel_types.gd")
const SquirrelQueries = preload("res://scripts/squirrel_queries.gd")
const SquirrelSpawner = preload("res://scripts/squirrel_spawner.gd")

var root
var player
var game_state
var world_sprite_view
var audio_controller
var message_view
var on_mission_fail: Callable
var squirrel_ais: Dictionary = {}
var desired_dirs: Dictionary = {}
var ai_tick := 0.0
var navigation_agents: Dictionary = {}

# Combat squirrels stop before entering the player collision volume.
# THIEF and RUNNER intentionally retain close approach behavior.
const MIN_APPROACH_DISTANCE: float = 1.35

const ARCHETYPE_BY_ID := {
    "Squirrel01": SquirrelTypes.Kind.SCOUT,
    "Squirrel02": SquirrelTypes.Kind.TANK,
    "Squirrel03": SquirrelTypes.Kind.THROWER,
    "Squirrel04": SquirrelTypes.Kind.THIEF,
    "Squirrel05": SquirrelTypes.Kind.RUNNER,
}

func setup(root_node, player_node, state, world_sprites, audio, messages, mission_fail_callback: Callable) -> void:
    root = root_node
    player = player_node
    game_state = state
    world_sprite_view = world_sprites
    audio_controller = audio
    message_view = messages
    on_mission_fail = mission_fail_callback
    squirrel_ais.clear()
    desired_dirs.clear()
    navigation_agents.clear()
    ai_tick = 0.0
    # Squirrel spawning and AI registration are static for Level 1; do them once at setup.
    _sync_ai_registry()

func _spawn_missing_squirrels() -> void:
    var template := SceneLookup.mesh_node(root, "Squirrel01") as MeshInstance3D
    if template == null or template.mesh == null:
        return
    for entry in SquirrelSpawner.build_spawn_list():
        var id: String = str(entry["id"])
        if SceneLookup.mesh_node(root, id) != null:
            continue
        var node := template.duplicate() as MeshInstance3D
        if node == null:
            continue
        node.name = id
        node.position = entry["position"]
        node.visible = true
        template.get_parent().add_child(node)

func _sync_ai_registry() -> void:
    _spawn_missing_squirrels()
    for id in game_state.squirrels:
        if squirrel_ais.has(id):
            continue
        var node: MeshInstance3D = SceneLookup.mesh_node(root, id) as MeshInstance3D
        if node == null:
            continue
        var kind: int = int(ARCHETYPE_BY_ID.get(id, SquirrelTypes.Kind.SCOUT))
        var home: Vector2 = game_state.squirrel_home.get(id, Vector2(node.position.x, node.position.z))
        var ai: SquirrelAI = SquirrelAI.new()
        ai.setup(id, kind, Vector3(node.position.x, node.position.y, node.position.z), [Vector3(home.x, node.position.y, home.y)])
        ai.hp = int(game_state.squirrel_hp.get(id, SquirrelTypes.hp_of(kind)))
        squirrel_ais[id] = ai
        node.set_meta("squirrel_id", id)
        world_sprite_view.apply_squirrel_type(node, kind)
        _ensure_navigation_agent(node, id)

func _nearby_acorns_for_ai(origin: Vector3) -> Array:
    var out: Array = []
    if game_state == null or root == null:
        return out
    for id in game_state.acorns:
        var node: Node3D = SceneLookup.mesh_node(root, str(id)) as Node3D
        if node == null or not node.visible:
            continue
        var position: Vector3 = node.global_position
        if origin.distance_to(position) <= 3.0:
            out.append({"id": str(id), "position": position})
    return out

func update(delta: float) -> void:
    if player == null:
        return
    var player_pos: Vector3 = player.global_position
    ai_tick += delta
    var think := ai_tick >= 0.10
    if think:
        ai_tick = 0.0

    for id in game_state.squirrels:
        var node: MeshInstance3D = SceneLookup.mesh_node(root, id) as MeshInstance3D
        var ai: SquirrelAI = squirrel_ais.get(id) as SquirrelAI
        if node == null or ai == null:
            continue

        var is_stunned: bool = game_state.stunned.has(id)
        if is_stunned:
            var stunned_dist: float = node.global_position.distance_to(player_pos)
            node.visible = stunned_dist <= 12.0
            if node.visible:
                world_sprite_view.animate_squirrel(
                    node,
                    float(game_state.squirrel_phase.get(id, 0.0)),
                    ai.state,
                    0.0,
                    Vector3.ZERO,
                    delta)
            continue

        ai.position = node.global_position
        if think:
            # Visibility rays and neighborhood searches are the expensive part
            # of Level 1 AI. 10 Hz is more than enough for five billboard enemies.
            var visible: bool = SquirrelQueries.visible_from(
                node.global_position + Vector3.UP * 0.2,
                player_pos + Vector3.UP * 0.2,
                root.get_world_3d(),
                LevelData.WORLD_LAYER)
            var nearby: Array = SquirrelQueries.nearby_squirrels(squirrel_ais, node.global_position, 4.0, id)
            var acorns_near: Array = _nearby_acorns_for_ai(node.global_position)
            var dir: Vector3 = ai.desired_direction(player_pos, visible, nearby, acorns_near, 0.10)
            desired_dirs[id] = dir

        var dir: Vector3 = desired_dirs.get(id, Vector3.ZERO)
        var navigation_agent := navigation_agents.get(id) as NavigationAgent3D
        if think and navigation_agent != null and dir.length_squared() > 0.01:
            navigation_agent.target_position = node.global_position + dir.normalized() * 4.5
            if not navigation_agent.is_navigation_finished():
                var next_path_position := navigation_agent.get_next_path_position()
                var nav_dir := node.global_position.direction_to(next_path_position)
                if nav_dir.length_squared() > 0.01:
                    dir = nav_dir
                    desired_dirs[id] = dir

        if dir.length() > 0.01:
            var proposed: Vector3 = node.global_position + dir * ai.speed * delta
            var proposed_flat := Vector2(proposed.x, proposed.z)
            var player_flat := Vector2(player_pos.x, player_pos.z)
            var dist_after: float = proposed_flat.distance_to(player_flat)
            var min_dist: float = 0.0 if ai.is_thief_or_runner() else MIN_APPROACH_DISTANCE
            if dist_after >= min_dist and not WorldCollision.is_wall(proposed.x, proposed.z):
                node.global_position = proposed
                ai.position = proposed

        var dist: float = node.global_position.distance_to(player_pos)
        # The camera/fog cutoff is 12m, so never animate distant transparent sprites.
        node.visible = dist <= 12.0
        if node.visible:
            world_sprite_view.animate_squirrel(
                node,
                float(game_state.squirrel_phase.get(id, 0.0)),
                ai.state,
                ai.speed,
                dir,
                delta)

        if game_state.damage_cooldown <= 0.0 and ai.can_attack(dist):
            ai.mark_attacked(0.8)
            game_state.damage_cooldown = 0.8
            game_state.hp = HealthMath.apply_damage(game_state.hp, SquirrelTypes.damage_of(ai.kind))
            audio_controller.play_damage()
            set_message(LevelData.DAMAGE_LINES.pick_random(), 1.2)
            if DeathQuery.is_dead(game_state.hp):
                fail()
                return

func _ensure_navigation_agent(node: Node3D, id: String) -> NavigationAgent3D:
    var existing := navigation_agents.get(id) as NavigationAgent3D
    if existing != null and is_instance_valid(existing):
        return existing
    var agent := NavigationAgent3D.new()
    agent.name = "NavigationAgent3D"
    agent.radius = 0.30
    agent.height = 1.0
    agent.path_desired_distance = 0.25
    agent.target_desired_distance = 0.35
    agent.max_speed = 3.8
    agent.avoidance_enabled = false
    node.add_child(agent)
    navigation_agents[id] = agent
    return agent

func is_disabled(name: String) -> bool:
    return game_state.stunned.has(name)

func hit_squirrel(name: String) -> void:
    if name == "" or game_state.stunned.has(name):
        return
    var ai: SquirrelAI = squirrel_ais.get(name) as SquirrelAI
    if ai == null:
        return
    var stunned: bool = ai.take_hit(1)
    game_state.squirrel_hp[name] = ai.hp
    audio_controller.play_squirrel_hit()
    var target_node := SceneLookup.mesh_node(root, name) as MeshInstance3D
    if target_node != null:
        world_sprite_view.apply_squirrel_hit(target_node, ai.kind)
    _panic_neighbours(ai)
    if stunned:
        game_state.stunned[name] = true
        var target = SceneLookup.mesh_node(root, name)
        if target != null:
            world_sprite_view.apply_squirrel_stunned(target, ai.kind)
        set_message(LevelData.STUN_LINES.pick_random(), 2.0)
    else:
        set_message(LevelData.HIT_LINES.pick_random() + "\nЕщё один раз — и белка отдыхает.", 1.4)

func _panic_neighbours(source) -> void:
    var radius: float = SquirrelTypes.panic_radius_of(source.kind)
    if radius <= 0.0:
        return
    for id in squirrel_ais.keys():
        var other = squirrel_ais[id]
        if other == null or other == source or other.is_stunned():
            continue
        if source.position.distance_to(other.position) <= radius:
            other.panic(1.5)

func fail() -> void:
    game_state.mission_failed = true
    if on_mission_fail.is_valid():
        on_mission_fail.call()

func set_message(text: String, duration: float) -> void:
    message_view.set_text(text)
    game_state.message_time = duration
