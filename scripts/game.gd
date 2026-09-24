extends Node3D

# ACORN HUNTER — LEVEL 1
# Rebuilt from the last proven CLEAN/V6 control foundation.
# World sprites are deliberately MeshInstance3D + QuadMesh, not Sprite3D.
# UI owns touch input: joystick.gui_input + Fire.pressed.

const LevelData = preload("res://scripts/level_data.gd")
const HudView = preload("res://scripts/hud_view.gd")
const AudioController = preload("res://scripts/audio_controller.gd")
const MissionView = preload("res://scripts/mission_view.gd")
const CombatFeedbackView = preload("res://scripts/combat_feedback_view.gd")
const MessageView = preload("res://scripts/message_view.gd")
const MinimapView = preload("res://scripts/minimap_view.gd")
const NavigationController = preload("res://scripts/navigation_controller.gd")
const WorldSpriteView = preload("res://scripts/world_sprite_view.gd")
const RuntimeTimers = preload("res://scripts/runtime_timers.gd")
const PresentationSync = preload("res://scripts/presentation_sync.gd")
const PlayerView = preload("res://scripts/player_view.gd")
const MissionStateQuery = preload("res://scripts/mission_state_query.gd")
const GameState = preload("res://scripts/game_state.gd")
const GameplayController = preload("res://scripts/gameplay_controller.gd")
const PlayerController = preload("res://scripts/player_controller.gd")
const EnemyController = preload("res://scripts/enemy_controller.gd")
const PickupController = preload("res://scripts/pickup_controller.gd")
const SceneLookup = preload("res://scripts/scene_lookup.gd")

const WALL_TEXTURE_PATHS := [
    "res://wall_zone1.png",
    "res://wall_zone2.png",
    "res://wall_zone3.png",
    "res://wall_zone4.png",
]
const FLOOR_TEXTURE_PATH := "res://assets/grass.png"
const HERO_GRASS_PATH := "res://assets/floor_grass_hero.png"
const HERO_GRASS_SHADER := "res://scripts/hero_grass_fade.gdshader"

# Scattered hero spots: [x, z] in world units.
const HERO_GRASS_SPOTS := [
    Vector3(-43.2, 0.02, -7.2),
    Vector3(-34.2, 0.02, -2.7),
    Vector3(-24.3, 0.02, 5.4),
    Vector3(-10.8, 0.02, -8.1),
    Vector3(-1.8, 0.02, 7.2),
    Vector3(9.0, 0.02, 2.7),
    Vector3(21.6, 0.02, -5.4),
    Vector3(32.4, 0.02, 7.2),
    Vector3(43.2, 0.02, -7.2),
    Vector3(50.4, 0.02, 5.4),
]
const LEVEL_2_SCENE_PATH := "res://scenes/level2_pseudo3d.tscn"

@onready var level1_layout: Node3D = $Level1Layout

var game_state = null
var gameplay_controller
var player_controller
var enemy_controller
var pickup_controller
var audio_controller: AudioController
var hud_view: HudView
var mission_view: MissionView
var combat_feedback: CombatFeedbackView
var message_view: MessageView
var minimap_view: MinimapView
var navigation_controller: NavigationController
var world_sprite_view: WorldSpriteView
var runtime_timers: RuntimeTimers
var presentation_sync: PresentationSync
var player_view: PlayerView
var presentation_timer := 0.0
var keys_held := 0
var keys_collected: Dictionary = {}
var door_hint_cooldown := 0.0

# Level 1 scene-node cache. Resolve named keys/doors once in _ready(), never
# through recursive find_child() from the per-frame progression loop.
var key_nodes: Dictionary = {}
var door_nodes: Dictionary = {}

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/Camera3D
@onready var joystick: Panel = $HUD/Joystick
@onready var knob: Panel = $HUD/Joystick/Knob
@onready var fire_button: Button = $HUD/Fire
@onready var mute_button: Button = $HUD/Mute
@onready var count_label: Label = $HUD/Count
@onready var hp_ammo_label: Label = $HUD/HPAmmo
@onready var message_label: Label = $HUD/Message
@onready var mission_panel: Panel = $HUD/Mission
@onready var mission_title: Label = $HUD/Mission/Title
@onready var mission_body: Label = $HUD/Mission/Body
@onready var weapon: TextureRect = $HUD/Weapon
@onready var muzzle: ColorRect = $HUD/MuzzleFlash
@onready var hit_marker: Label = $HUD/HitMarker
@onready var carolina: TextureRect = $HUD/Carolina
@onready var music: AudioStreamPlayer = $Music
@onready var fx: AudioStreamPlayer = $FX

func _ready() -> void:
    game_state = GameState.new()
    game_state.setup(LevelData)
    _prepare_environment_materials()
    _build_hero_grass_spots()
    _build_mobile_wall_visuals()
    _setup_atmosphere()
    _setup_mobile_visibility()

    player_view = PlayerView.new()
    player_view.setup(camera, carolina)
    player_view.apply()
    mission_panel.visible = false
    if not OS.has_feature("mobile"):
        joystick.visible = false
        knob.visible = false
        fire_button.visible = false
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    muzzle.visible = false
    hit_marker.visible = false
    knob.position = joystick.size * 0.5 - knob.size * 0.5

    fire_button.pressed.connect(_on_fire_pressed)
    mute_button.pressed.connect(_toggle_music)

    hud_view = HudView.new()
    hud_view.setup(count_label, hp_ammo_label)

    mission_view = MissionView.new()
    mission_view.setup(mission_panel, mission_title, mission_body, weapon)

    combat_feedback = CombatFeedbackView.new()
    combat_feedback.setup(weapon, muzzle, hit_marker)

    message_view = MessageView.new()
    message_view.setup(message_label)

    minimap_view = $HUD/Minimap as MinimapView
    _cache_level1_nodes()

    world_sprite_view = WorldSpriteView.new()
    runtime_timers = RuntimeTimers.new()
    presentation_sync = PresentationSync.new()

    navigation_controller = NavigationController.new()
    navigation_controller.setup($HUD/Mission/Menu, get_tree())

    audio_controller = AudioController.new()
    audio_controller.setup(music, fx)
    audio_controller.start_music()

    player_controller = PlayerController.new()
    player_controller.setup(player, joystick, knob, audio_controller)

    enemy_controller = EnemyController.new()
    enemy_controller.setup(self, player, game_state, world_sprite_view, audio_controller, message_view, Callable(self, "_on_enemy_fail"))

    pickup_controller = PickupController.new()
    pickup_controller.setup(self, player, game_state, world_sprite_view, audio_controller, message_view, mission_view, Callable(self, "_on_pickup_complete"), Callable(self, "_on_pickup_fail"))

    gameplay_controller = GameplayController.new()
    gameplay_controller.setup(self, player, camera, game_state, world_sprite_view, combat_feedback, audio_controller, message_view, mission_view, enemy_controller, pickup_controller, Callable(self, "_on_mission_end"))

    presentation_timer = 0.0
    _update_hud()
    _set_message("Операция «ЖЁЛУДЬ»: найди ключи, открой ворота и собери 6 жёлудей.", 4.0)
    _refresh_minimap()

func _cache_level1_nodes() -> void:
    key_nodes.clear()
    door_nodes.clear()

    # These are one-time recursive lookups during scene initialization.
    for key_name in LevelData.KEY_NAMES:
        var key_node := level1_layout.find_child(key_name, true, false) as MeshInstance3D
        if key_node != null:
            key_nodes[key_name] = key_node

    for door_name in LevelData.DOOR_NAMES:
        var door_node := level1_layout.find_child(door_name, true, false)
        if door_node != null:
            door_nodes[door_name] = door_node

    print("[Perf] Level 1 progression node cache: %d keys, %d doors" % [
        key_nodes.size(),
        door_nodes.size()
    ])

func _prepare_environment_materials() -> void:
    # Make the new floor texture visibly read as grass instead of the nearly-black
    # fallback tint from the original scene material.
    var ground := level1_layout.get_node_or_null("Floor/Ground") as MeshInstance3D
    if ground and ground.mesh:
        var ground_mesh := ground.mesh.duplicate() as PlaneMesh
        if ground_mesh:
            var ground_material := ground_mesh.material
            if ground_material is StandardMaterial3D:
                ground_material = ground_material.duplicate() as StandardMaterial3D
                # Match the wall visual language on the ground:
                # world-space triplanar mapping, repeated detail, mipmapped filtering,
                # but keep normal lighting so the floor still reads as a real surface.
                ground_material.albedo_color = Color(0.72, 0.82, 0.70, 1.0)
                var floor_texture := load(FLOOR_TEXTURE_PATH) as Texture2D
                if floor_texture:
                    ground_material.albedo_texture = floor_texture

                # World-space triplanar mapping keeps the floor texture continuous.
                ground_material.uv1_triplanar = true
                ground_material.uv1_world_triplanar = true

                # Larger grass detail: fewer visible repetitions across the map.
                ground_material.uv1_scale = Vector3(0.35, 0.35, 0.35)

                # Repeat the texture and preserve detail at grazing angles/distance.
                ground_material.texture_repeat = true
                ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
                ground_material.uv1_offset = Vector3.ZERO

                # Keep the established unshaded night-scene floor treatment.
                ground_material.roughness = 1.0
                ground_material.metallic = 0.0
                ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

                ground_mesh.material = ground_material
            ground.mesh = ground_mesh

    # Reuse one material per wall-zone texture instead of duplicating a
    # StandardMaterial3D for every wall segment. This keeps material/resource
    # count low and lets Android's renderer batch matching wall surfaces.
    var wall_materials: Dictionary = {}
    var wall_index := 0
    var walls_root := level1_layout.get_node_or_null("Walls") as Node3D
    if walls_root == null:
        return
    for child in walls_root.get_children():
        if not (child is StaticBody3D) or not child.name.begins_with("MapWall_"):
            continue
        var mesh_instance := child.get_node_or_null("Mesh") as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue

        var texture_path: String = WALL_TEXTURE_PATHS[wall_index % WALL_TEXTURE_PATHS.size()]
        var wall_material: StandardMaterial3D = wall_materials.get(texture_path) as StandardMaterial3D
        if wall_material == null:
            wall_material = StandardMaterial3D.new()
            var wall_texture := load(texture_path) as Texture2D
            if wall_texture:
                wall_material.albedo_texture = wall_texture
            wall_material.albedo_color = Color.WHITE
            wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
            wall_material.roughness = 1.0
            # Wall textures contain the moon accents. A low-energy emission
            # texture makes those bright crescents feed the scene glow without
            # changing the wall texture itself.
            wall_material.emission_enabled = true
            wall_material.emission_texture = wall_texture
            wall_material.emission = Color(0.72, 0.80, 1.0, 1.0)
            wall_material.emission_energy_multiplier = 0.28
            wall_material.uv1_triplanar = true
            wall_material.uv1_world_triplanar = true
            wall_material.uv1_scale = Vector3(0.4, 0.4, 0.4)
            wall_material.uv1_offset = Vector3.ZERO
            wall_materials[texture_path] = wall_material

        # Keep each wall's geometry resource intact; only override its material.
        mesh_instance.material_override = wall_material
        mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        wall_index += 1

func _setup_mobile_visibility() -> void:
    # Aggressive mobile culling: let the fog hide the cutoff so the renderer
    # does not spend time drawing distant walls, trees and squirrels.
    camera.near = 0.05
    camera.far = 22.0

func _build_mobile_wall_visuals() -> void:
    # Keep the ~280 wall bodies for collision, but render them as four
    # MultiMeshes. Compatibility does not auto-instance identical MeshInstance3D
    # nodes, so this collapses the maze to four visual draw calls.
    if get_node_or_null("MobileWallVisuals") != null:
        return

    var first_mesh: MeshInstance3D = null
    var grouped: Array[Array] = [[], [], [], []]
    var wall_index := 0
    var walls_root := level1_layout.get_node_or_null("Walls") as Node3D
    if walls_root == null:
        return
    for child in walls_root.get_children():
        if not (child is StaticBody3D) or not child.name.begins_with("MapWall_"):
            continue
        var mesh_instance := child.get_node_or_null("Mesh") as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue
        if first_mesh == null:
            first_mesh = mesh_instance
        grouped[wall_index % 4].append(child)
        mesh_instance.visible = false
        wall_index += 1

    if first_mesh == null or wall_index == 0:
        return

    var container := Node3D.new()
    container.name = "MobileWallVisuals"
    add_child(container)

    for group_index in range(4):
        var entries: Array = grouped[group_index]
        if entries.is_empty():
            continue

        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = first_mesh.mesh
        mm.instance_count = entries.size()
        mm.custom_aabb = AABB(
            Vector3(LevelData.MAP_WORLD_ORIGIN.x - 1.0, -0.1, LevelData.MAP_WORLD_ORIGIN.y - 1.0),
            Vector3(LevelData.MAP_WIDTH * LevelData.CELL_SIZE + 2.0, 3.1, LevelData.MAP_HEIGHT * LevelData.CELL_SIZE + 2.0)
        )
        for i in range(entries.size()):
            var body := entries[i] as Node3D
            mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, body.position))

        var instance := MultiMeshInstance3D.new()
        instance.name = "Walls_%d" % group_index
        instance.multimesh = mm
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

        var mat := StandardMaterial3D.new()
        var texture := load(WALL_TEXTURE_PATHS[group_index]) as Texture2D
        if texture:
            mat.albedo_texture = texture
        mat.albedo_color = Color.WHITE
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.cull_mode = BaseMaterial3D.CULL_BACK
        mat.roughness = 1.0
        # Keep the same moon emission on the batched wall visuals.
        mat.emission_enabled = true
        mat.emission_texture = texture
        mat.emission = Color(0.72, 0.80, 1.0, 1.0)
        mat.emission_energy_multiplier = 0.28
        mat.uv1_triplanar = true
        mat.uv1_world_triplanar = true
        mat.uv1_scale = Vector3(0.4, 0.4, 0.4)
        instance.material_override = mat
        container.add_child(instance)

    print("[Perf] Level 1 wall visuals batched: %d walls -> %d MultiMeshes" % [wall_index, container.get_child_count()])

func _setup_atmosphere() -> void:
    var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
    if we == null or we.environment == null:
        push_warning("[Atmosphere] WorldEnvironment not found")
        return
    var env := we.environment
    var renderer := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))

    # The project intentionally uses GL Compatibility for Android.
    # Volumetric fog is Forward+ only, so use a lightweight depth/height fog
    # fallback here instead of enabling an effect the target renderer cannot draw.
    if renderer != "gl_compatibility":
        env.volumetric_fog_enabled = true
        env.volumetric_fog_density = 0.015
        env.volumetric_fog_emission = Color(0.4, 0.5, 0.7)
        env.volumetric_fog_emission_energy = 0.6
        env.volumetric_fog_albedo = Color(0.9, 0.95, 1.0)
        env.volumetric_fog_length = 60.0
    else:
        env.volumetric_fog_enabled = false
        env.fog_enabled = true
        # Depth fog gives this tiny map a predictable mobile cutoff.
        env.fog_mode = Environment.FOG_MODE_DEPTH
        env.fog_density = 1.0
        env.fog_depth_begin = 5.0
        env.fog_depth_end = 12.0
        env.fog_depth_curve = 1.0
        env.fog_height = 0.0
        env.fog_height_density = 0.0
        env.fog_light_color = Color(0.40, 0.48, 0.66)
        env.fog_light_energy = 0.55
        env.fog_sky_affect = 0.0
        env.fog_sun_scatter = 0.0
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(0.32, 0.39, 0.56)
        env.ambient_light_sky_contribution = 0.0
        env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED

    # Controlled bloom/glow for the night scene. Keep it subtle so the
    # mobile renderer gets atmosphere without washing out the grass and walls.
    env.glow_enabled = true
    env.glow_intensity = 1.2
    env.glow_bloom = 0.3
    env.glow_strength = 1.1
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN

    # AgX tonemapping — supported by the Android Compatibility renderer.
    env.tonemap_mode = Environment.TONE_MAPPER_AGX
    env.tonemap_exposure = 1.0
    env.tonemap_white = 2.5

    # Slightly deepen ambient for more night contrast.
    env.ambient_light_energy = 0.65

    print("[Atmosphere] Night atmosphere enabled. Renderer: %s" % renderer)

func _spawn_leaves() -> void:
    if get_node_or_null("FallingLeaves") != null:
        return

    var leaves := GPUParticles3D.new()
    leaves.name = "FallingLeaves"
    # Keep the drifting-leaf effect, but make it cheap enough for mobile.
    leaves.amount = 8
    leaves.lifetime = 8.0
    leaves.preprocess = 1.5
    leaves.explosiveness = 0.0
    leaves.randomness = 0.8

    var mat := ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(50, 1, 14)
    mat.direction = Vector3(0, -1, 0)
    mat.spread = 15.0
    mat.initial_velocity_min = 0.6
    mat.initial_velocity_max = 1.4
    mat.gravity = Vector3(0.2, -0.3, 0.1)
    mat.scale_min = 0.4
    mat.scale_max = 0.9
    mat.angular_velocity_min = -30.0
    mat.angular_velocity_max = 30.0

    var draw_pass := QuadMesh.new()
    draw_pass.size = Vector2(0.15, 0.15)
    var leaf_mat := StandardMaterial3D.new()
    leaf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    leaf_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    leaf_mat.albedo_color = Color(0.55, 0.35, 0.15, 0.85)
    draw_pass.material = leaf_mat

    leaves.draw_pass_1 = draw_pass
    leaves.process_material = mat
    leaves.position = Vector3(0, 10, 0)
    leaves.local_coords = false
    add_child(leaves)
    print("[Atmosphere] Falling leaves spawned.")

func _build_hero_grass_spots() -> void:
    # Clean previous spots (in case scene reloads).
    for child in get_children():
        if child.name.begins_with("HeroGrass_"):
            child.queue_free()

    if not ResourceLoader.exists(HERO_GRASS_PATH):
        print("[HeroGrass] hero tile not found, skipping.")
        return

    var hero_tex := load(HERO_GRASS_PATH) as Texture2D
    if hero_tex == null:
        print("[HeroGrass] failed to load hero tile.")
        return

    var shader_res: Shader = null
    if ResourceLoader.exists(HERO_GRASS_SHADER):
        shader_res = load(HERO_GRASS_SHADER) as Shader
    if shader_res == null:
        print("[HeroGrass] shader not found, using plain material.")
        return

    var mat := ShaderMaterial.new()
    mat.shader = shader_res
    mat.set_shader_parameter("albedo_tex", hero_tex)
    mat.set_shader_parameter("fade_inner", 0.35)
    mat.set_shader_parameter("fade_outer", 0.80)

    var quad := QuadMesh.new()
    quad.size = Vector2(7.0, 7.0)
    quad.material = mat

    for i in HERO_GRASS_SPOTS.size():
        var spot: Vector3 = HERO_GRASS_SPOTS[i]
        var node := MeshInstance3D.new()
        node.name = "HeroGrass_%02d" % i
        node.mesh = quad
        node.rotation_degrees = Vector3(-90.0, randf() * 360.0, 0.0)
        node.position = Vector3(spot.x, spot.y, spot.z)
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(node)

    print("[HeroGrass] spawned ", HERO_GRASS_SPOTS.size(), " hero spots.")

func _physics_process(delta: float) -> void:
    if MissionStateQuery.is_finished(game_state.mission_complete, game_state.mission_failed):
        player_controller.stop()
        return

    door_hint_cooldown = maxf(0.0, door_hint_cooldown - delta)
    game_state.foot_timer = player_controller.update(delta, game_state.foot_timer)

    var timers := runtime_timers.tick(delta, {
        "fire_cooldown": game_state.fire_cooldown,
        "damage_cooldown": game_state.damage_cooldown,
        "recoil_time": game_state.recoil_time,
        "message_time": game_state.message_time
    })
    game_state.fire_cooldown = timers["fire_cooldown"]
    game_state.damage_cooldown = timers["damage_cooldown"]
    game_state.recoil_time = timers["recoil_time"]
    game_state.message_time = timers["message_time"]

    if game_state.message_time <= 0.0:
        message_view.clear()
    if game_state.recoil_time <= 0.0:
        combat_feedback.set_idle_weapon()
    combat_feedback.update_muzzle(delta)

    _update_level1_progression()
    gameplay_controller.update(delta)
    presentation_timer -= delta
    if presentation_timer <= 0.0:
        presentation_timer = 0.10
        _update_hud()
        _refresh_minimap()

func _unhandled_input(event: InputEvent) -> void:
    if OS.has_feature("mobile"):
        return

    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.set_mouse_mode(
            Input.MOUSE_MODE_VISIBLE
            if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
            else Input.MOUSE_MODE_CAPTURED
        )
        return

    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        player_controller.handle_mouse_motion(event.relative)
        return

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            return
        if gameplay_controller != null:
            gameplay_controller.handle_fire()

func _on_fire_pressed() -> void:
    gameplay_controller.handle_fire()

func _on_mission_end() -> void:
    player_controller.stop()

func _on_enemy_fail() -> void:
    gameplay_controller.fail()

func _on_pickup_complete() -> void:
    player_controller.stop()
    get_tree().call_deferred("change_scene_to_file", LEVEL_2_SCENE_PATH)

func _on_pickup_fail() -> void:
    gameplay_controller.fail()

func _update_hud() -> void:
    presentation_sync.sync_hud(hud_view, game_state.collected, LevelData.ACORN_COUNT, game_state.hp, game_state.ammo)
    count_label.text = "ЖЁЛУДИ %d / %d    КЛЮЧИ %d" % [game_state.collected, LevelData.ACORN_COUNT, keys_held]

func _set_message(text: String, duration: float) -> void:
    message_view.set_text(text)
    game_state.message_time = duration

func _toggle_music() -> void:
    var is_muted := audio_controller.toggle_music()
    mute_button.text = "×" if is_muted else "♪"
    _set_message("Музыка выключена." if is_muted else "Музыка возвращена. Белки снова слышат угрозу.", 1.6)

func _update_level1_progression() -> void:
    if player == null or level1_layout == null:
        return

    for key_name in LevelData.KEY_NAMES:
        var key_node := key_nodes.get(key_name) as MeshInstance3D
        if not is_instance_valid(key_node) or not key_node.visible:
            continue
        if player.global_position.distance_to(key_node.global_position) <= LevelData.KEY_PICKUP_RADIUS:
            key_node.visible = false
            var key_number := int(key_name.right(2))
            keys_collected[key_number] = true
            keys_held += 1
            audio_controller.play_pickup()
            _set_message("КЛЮЧ №%d ПОЛУЧЕН — найдена ещё одна часть маршрута." % key_number, 1.8)

    for door_name in LevelData.DOOR_NAMES:
        var door := door_nodes.get(door_name) as Node
        if not is_instance_valid(door) or not door.has_method("open"):
            continue
        if bool(door.get("is_open")):
            continue
        if player.global_position.distance_to(door.global_position) > 2.6:
            continue

        var required_key := int(door.get("required_key"))
        if bool(keys_collected.get(required_key, false)):
            door.open()
            audio_controller.play_pickup()
            _set_message("ДВЕРЬ %d ОТКРЫТА. Ключ №%d подходит." % [required_key, required_key], 1.6)
        elif door_hint_cooldown <= 0.0:
            _set_message("ДВЕРЬ ЗАПЕРТА. НУЖЕН КЛЮЧ №%d." % required_key, 1.4)
            door_hint_cooldown = 1.5

func _face_world_sprites() -> void:
    pass

func _refresh_minimap() -> void:
    presentation_sync.sync_minimap(minimap_view, player, game_state.acorns, game_state.squirrels, game_state.stunned)
