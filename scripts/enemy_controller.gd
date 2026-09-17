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

const ARCHETYPE_BY_ID := {
    "Squirrel01": SquirrelTypes.Kind.SCOUT,
    "Squirrel02": SquirrelTypes.Kind.SCOUT,
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
        root.add_child(node)

func _sync_ai_registry() -> void:
    _spawn_missing_squirrels()
    for id in game_state.squirrels:
        if squirrel_ais.has(id):
            continue
        var node = SceneLookup.mesh_node(root, id)
        if node == null:
            continue
        var kind: int = int(ARCHETYPE_BY_ID.get(id, SquirrelTypes.Kind.SCOUT))
        var home: Vector2 = game_state.squirrel_home.get(id, Vector2(node.position.x, node.position.z))
        var ai = SquirrelAI.new()
        ai.setup(id, kind, Vector3(node.position.x, node.position.y, node.position.z), [Vector3(home.x, node.position.y, home.y)])
        ai.hp = int(game_state.squirrel_hp.get(id, SquirrelTypes.hp_of(kind)))
        squirrel_ais[id] = ai
        node.set_meta("squirrel_id", id)

func update(delta: float) -> void:
    _sync_ai_registry()
    var player_pos := player.global_position
    for id in game_state.squirrels:
        if game_state.stunned.has(id):
            continue
        var node = SceneLookup.mesh_node(root, id)
        var ai = squirrel_ais.get(id)
        if node == null or ai == null:
            continue
        ai.position = node.global_position
        var visible := SquirrelQueries.visible_from(
            node.global_position + Vector3.UP * 0.2,
            player_pos + Vector3.UP * 0.2,
            root.get_world_3d(),
            LevelData.WORLD_LAYER)
        var nearby := SquirrelQueries.nearby_squirrels(squirrel_ais, node.global_position, 4.0, id)
        var acorns_near := SquirrelQueries.nearby_acorns(game_state.acorns, node.global_position, 3.0)
        var dir := ai.desired_direction(player_pos, visible, nearby, acorns_near, delta)
        if dir.length() > 0.01:
            var proposed := node.global_position + dir * ai.speed * delta
            if not WorldCollision.is_wall(proposed.x, proposed.z):
                node.global_position = proposed
                ai.position = proposed
                game_state.squirrel_home[id] = Vector2(proposed.x, proposed.z)
        world_sprite_view.animate_squirrel(node, float(game_state.squirrel_phase.get(id, 0.0)))
        var dist := node.global_position.distance_to(player_pos)
        if ai.can_attack(dist):
            ai.mark_attacked(0.8)
            game_state.damage_cooldown = 0.8
            game_state.hp = HealthMath.apply_damage(game_state.hp, SquirrelTypes.damage_of(ai.kind))
            audio_controller.play_damage()
            set_message(LevelData.DAMAGE_LINES.pick_random(), 1.2)
            if DeathQuery.is_dead(game_state.hp):
                fail()
                return

func is_disabled(name: String) -> bool:
    return game_state.stunned.has(name)

func hit_squirrel(name: String) -> void:
    if name == "" or game_state.stunned.has(name):
        return
    _sync_ai_registry()
    var ai = squirrel_ais.get(name)
    if ai == null:
        return
    var stunned := ai.take_hit(1)
    game_state.squirrel_hp[name] = ai.hp
    var target = SceneLookup.mesh_node(root, name)
    audio_controller.play_squirrel_hit()
    _panic_neighbours(ai)
    if stunned:
        game_state.stunned[name] = true
        if target != null:
            world_sprite_view.apply_squirrel_stunned(target)
        set_message(LevelData.STUN_LINES.pick_random(), 2.0)
    else:
        set_message(LevelData.HIT_LINES.pick_random() + "\nЕщё один раз — и белка отдыхает.", 1.4)

func _panic_neighbours(source) -> void:
    var radius := SquirrelTypes.panic_radius_of(source.kind)
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
